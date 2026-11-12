"""Patient review consent and assigned case discovery."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, authenticated_user
from app.persistence.supabase import PersistenceConflict, PersistenceUnavailable


router = APIRouter(tags=["case-management"])


class ReviewConsent(BaseModel):
    consent_to_share: bool


class DoctorReviewInput(BaseModel):
    expected_version: int = Field(ge=0)
    observations: str = Field(min_length=1, max_length=4000)
    recommendations: str = Field(min_length=1, max_length=4000)
    follow_up: str = Field(min_length=1, max_length=2000)
    submit: bool = False


def _repository(request: Request):
    factory = request.app.state.history_repository_factory
    if factory is None:
        raise HTTPException(503, "Case service is temporarily unavailable")
    try:
        return factory()
    except PersistenceUnavailable:
        raise HTTPException(503, "Case service is temporarily unavailable") from None


def _unavailable():
    return HTTPException(503, "Case service is temporarily unavailable")


@router.get("/me")
async def get_my_profile(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        return await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.post("/screenings/{screening_id}/review-request")
async def request_doctor_review(
    screening_id: UUID, consent: ReviewConsent, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    if not consent.consent_to_share:
        raise HTTPException(400, "Consent to share this screening is required")
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        if profile["application_role"] != "patient":
            raise HTTPException(403, "Patient account required")
        review = await repository.request_review(
            request.state.session_token, str(screening_id)
        )
        return review
    except PermissionError:
        raise HTTPException(404, "Eligible screening not found") from None
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/review-requests")
async def my_review_requests(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        if profile["application_role"] != "patient":
            raise HTTPException(403, "Patient account required")
        return {"items": await repository.list_review_requests(
            request.state.session_token
        )}
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/feedback")
async def my_feedback(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        if profile["application_role"] != "patient":
            raise HTTPException(403, "Patient account required")
        return {"items": await repository.my_doctor_feedback(
            request.state.session_token
        )}
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/doctor/cases")
async def assigned_cases(
    request: Request, identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        doctor = profile.get("doctor_profiles")
        if (profile["application_role"] != "doctor" or not doctor
                or doctor["verification_state"] != "verified"):
            raise HTTPException(403, "Verified Doctor account required")
        return {"items": await repository.list_assigned_cases(
            request.state.session_token
        )}
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.get("/doctor/cases/{assignment_id}")
async def assigned_case_detail(
    assignment_id: UUID, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        doctor = profile.get("doctor_profiles")
        if (profile["application_role"] != "doctor" or not doctor
                or doctor["verification_state"] != "verified"):
            raise HTTPException(403, "Verified Doctor account required")
        assignments = await repository.list_assigned_cases(request.state.session_token)
        assignment = next((item for item in assignments
                           if item["id"] == str(assignment_id)), None)
        if assignment is None:
            raise HTTPException(404, "Case not found")
        screening_id = assignment["review_requests"]["screening_id"]
        screening = await repository.get_screening(
            request.state.session_token, screening_id
        )
        if screening is None:
            raise HTTPException(404, "Case not found")
        from app.services.history import public_screening
        review = await repository.get_doctor_review(
            request.state.session_token, str(assignment_id)
        )
        await repository.record_case_access(
            request.state.session_token, str(assignment_id)
        )
        return {"assignment": assignment, "screening": public_screening(screening),
                "review": review}
    except PermissionError:
        raise HTTPException(404, "Case not found") from None
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()


@router.put("/doctor/cases/{assignment_id}/review")
async def save_review(
    assignment_id: UUID, payload: DoctorReviewInput, request: Request,
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    repository = _repository(request)
    try:
        profile = await repository.identity_profile(
            request.state.session_token, identity.user_id
        )
        doctor = profile.get("doctor_profiles")
        if (profile["application_role"] != "doctor" or not doctor
                or doctor["verification_state"] != "verified"):
            raise HTTPException(403, "Verified Doctor account required")
        return await repository.save_doctor_review(
            request.state.session_token, str(assignment_id), payload.model_dump()
        )
    except PermissionError:
        raise HTTPException(404, "Case not found") from None
    except PersistenceConflict:
        raise HTTPException(409, "Review changed. Reload this case before saving.") from None
    except PersistenceUnavailable:
        raise _unavailable() from None
    finally:
        await repository.close()
