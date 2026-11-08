"""Authenticated screening-history endpoints."""

import logging
import re
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, Response, UploadFile

from app.api.upload import read_valid_image_payload
from app.core.auth import AuthenticatedUser, authenticated_user
from app.persistence.supabase import PersistenceConflict, PersistenceUnavailable
from app.services.history import ScreeningHistoryService, public_screening


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/screenings", tags=["screening-history"])
IDEMPOTENCY_PATTERN = re.compile(r"^[A-Za-z0-9_-]{16,128}$")


def _unavailable() -> HTTPException:
    return HTTPException(
        status_code=503,
        detail="Screening history is temporarily unavailable.",
    )


def _repository(request: Request):
    factory = request.app.state.history_repository_factory
    if factory is None:
        raise _unavailable()
    try:
        return factory()
    except PersistenceUnavailable:
        raise _unavailable() from None


@router.post("")
async def save_screening(
    request: Request,
    image: UploadFile = File(...),
    idempotency_key: str = Form(...),
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    if not IDEMPOTENCY_PATTERN.fullmatch(idempotency_key):
        raise HTTPException(status_code=400, detail="Invalid idempotency key")
    screening_service = request.app.state.screening_service
    if screening_service is None:
        raise HTTPException(status_code=503, detail="Screening models are unavailable.")
    validated = await read_valid_image_payload(image, request.app.state.settings)
    repository = _repository(request)
    try:
        history = ScreeningHistoryService(repository, screening_service)
        return await history.save(
            owner_id=identity.user_id,
            token=request.state.session_token,
            idempotency_key=idempotency_key,
            validated_image=validated,
        )
    except PersistenceConflict:
        raise HTTPException(status_code=409, detail="Save request conflicted. Retry safely.") from None
    except PersistenceUnavailable:
        raise _unavailable() from None
    except Exception as error:
        logger.error("screening_save_failed error_type=%s", type(error).__name__)
        raise _unavailable() from None
    finally:
        validated.image.close()
        await repository.close()


@router.get("")
async def list_screenings(
    request: Request,
    _: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        records = await repository.list_screenings(request.state.session_token)
        return {"items": [public_screening(record) for record in records]}
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/{screening_id}")
async def get_screening(
    screening_id: UUID,
    request: Request,
    _: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        record = await repository.get_screening(
            request.state.session_token, str(screening_id)
        )
        if record is None:
            raise HTTPException(status_code=404, detail="Screening not found")
        return public_screening(record)
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/{screening_id}/assets/{asset_kind}")
async def get_asset(
    screening_id: UUID,
    asset_kind: str,
    request: Request,
    _: AuthenticatedUser = Depends(authenticated_user),
):
    if asset_kind not in {"original", "gradcam"}:
        raise HTTPException(status_code=404, detail="Image not found")
    repository = _repository(request)
    try:
        record = await repository.get_screening(
            request.state.session_token, str(screening_id)
        )
        if record is None:
            raise HTTPException(status_code=404, detail="Image not found")
        asset = next(
            (item for item in record.get("image_assets", [])
             if item.get("asset_kind") == asset_kind),
            None,
        )
        if asset is None:
            raise HTTPException(status_code=404, detail="Image not found")
        downloaded = await repository.download_asset(
            request.state.session_token, asset["object_path"]
        )
        if downloaded.status_code == 404:
            raise HTTPException(status_code=404, detail="Image not found")
        return Response(
            content=downloaded.content,
            media_type=asset["content_type"],
            headers={
                "Cache-Control": "private, no-store",
                "X-Content-Type-Options": "nosniff",
            },
        )
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.delete("/{screening_id}", status_code=204)
async def delete_screening(
    screening_id: UUID,
    request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        deleted = await ScreeningHistoryService(
            repository, request.app.state.screening_service
        ).delete(str(screening_id), identity.user_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Screening not found")
        return Response(status_code=204)
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()
