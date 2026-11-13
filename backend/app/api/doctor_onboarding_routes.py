"""Authenticated Doctor application and self-profile operations."""

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator

from app.core.auth import AuthenticatedUser, authenticated_user
from app.persistence.supabase import PersistenceConflict, PersistenceUnavailable


router = APIRouter(tags=["doctor-onboarding"])


class DoctorProfileInput(BaseModel):
    display_name: str = Field(min_length=2, max_length=160)
    specialization: str = Field(min_length=2, max_length=160)
    qualification: str = Field(min_length=2, max_length=160)
    registration_reference: str = Field(min_length=3, max_length=160)
    workplace: str = Field(min_length=2, max_length=160)

    @field_validator("display_name", "specialization", "qualification",
                     "registration_reference", "workplace")
    @classmethod
    def nonblank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("A professional profile field is blank")
        return value


def _repository(request: Request):
    factory = request.app.state.history_repository_factory
    if factory is None:
        raise HTTPException(503, "Doctor service is temporarily unavailable")
    try:
        return factory()
    except PersistenceUnavailable:
        raise HTTPException(503, "Doctor service is temporarily unavailable") from None


@router.post("/doctor/applications", status_code=201)
async def apply_as_doctor(
    details: DoctorProfileInput, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id)
        if profile["application_role"] != "patient":
            raise HTTPException(409, "Account already has an application role")
        await repository.apply_doctor_candidate(identity.user_id,
                                                 details.model_dump())
        return {"verification_state": "pending"}
    except PersistenceConflict:
        raise HTTPException(409, "Doctor application already exists") from None
    except PersistenceUnavailable:
        raise HTTPException(503, "Doctor service is temporarily unavailable") from None
    finally:
        await repository.close()


@router.get("/doctor/profile")
async def get_doctor_profile(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id)
        if profile["application_role"] != "doctor":
            raise HTTPException(403, "Doctor account required")
        return await repository.doctor_profile(request.state.session_token,
                                               identity.user_id)
    except PermissionError:
        raise HTTPException(404, "Doctor profile is unavailable") from None
    except PersistenceUnavailable:
        raise HTTPException(503, "Doctor service is temporarily unavailable") from None
    finally:
        await repository.close()


@router.put("/doctor/profile")
async def update_doctor_profile(
    details: DoctorProfileInput, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id)
        doctor = profile.get("doctor_profiles") or {}
        if profile["application_role"] != "doctor":
            raise HTTPException(403, "Doctor account required")
        if doctor.get("verification_state") not in ("pending", "verified"):
            raise HTTPException(403, "Doctor profile cannot be edited")
        await repository.update_doctor_profile(identity.user_id,
                                               details.model_dump())
        return await repository.doctor_profile(request.state.session_token,
                                               identity.user_id)
    except PersistenceConflict:
        raise HTTPException(409, "Doctor profile changed; refresh and retry") from None
    except PersistenceUnavailable:
        raise HTTPException(503, "Doctor service is temporarily unavailable") from None
    finally:
        await repository.close()
