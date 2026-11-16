"""Authenticated, case-scoped Patient and Doctor messaging."""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, authenticated_user
from app.persistence.supabase import PersistenceConflict, PersistenceUnavailable


router = APIRouter(tags=["case-messaging"])


class MessageInput(BaseModel):
    client_message_id: UUID
    body: str = Field(min_length=1, max_length=2000)


def _repository(request: Request):
    factory = request.app.state.history_repository_factory
    if factory is None:
        raise HTTPException(503, "Messaging is temporarily unavailable")
    try:
        return factory()
    except PersistenceUnavailable:
        raise HTTPException(503, "Messaging is temporarily unavailable") from None


@router.get("/conversations")
async def conversations(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        return {"items": await repository.list_conversations(request.state.session_token)}
    except PersistenceUnavailable:
        raise HTTPException(503, "Messaging is temporarily unavailable") from None
    finally:
        await repository.close()


@router.get("/cases/{assignment_id}/messages")
async def messages(
    assignment_id: UUID, request: Request,
    before_at: datetime | None = None, before_id: UUID | None = None,
    limit: int = Query(50, ge=1, le=100),
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    if (before_at is None) != (before_id is None):
        raise HTTPException(422, "Both message cursor fields are required")
    repository = _repository(request)
    try:
        rows = await repository.list_case_messages(
            request.state.session_token, str(assignment_id),
            before_at.isoformat() if before_at else None,
            str(before_id) if before_id else None, limit,
        )
        return {"items": rows}
    except PermissionError:
        raise HTTPException(404, "Conversation not found") from None
    except PersistenceUnavailable:
        raise HTTPException(503, "Messaging is temporarily unavailable") from None
    finally:
        await repository.close()


@router.post("/cases/{assignment_id}/messages")
async def send_message(
    assignment_id: UUID, payload: MessageInput, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    body = payload.body.strip()
    if not body:
        raise HTTPException(422, "Message must not be blank")
    repository = _repository(request)
    try:
        return await repository.send_case_message(
            request.state.session_token, str(assignment_id),
            str(payload.client_message_id), body,
        )
    except PermissionError:
        raise HTTPException(404, "Conversation not found") from None
    except PersistenceConflict:
        raise HTTPException(409, "Message retry conflicts with existing content") from None
    except PersistenceUnavailable:
        raise HTTPException(503, "Messaging is temporarily unavailable") from None
    finally:
        await repository.close()
