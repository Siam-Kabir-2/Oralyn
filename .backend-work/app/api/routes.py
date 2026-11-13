"""Stable public routes; inference and image parsing live elsewhere."""

import logging
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from app.api.upload import read_valid_image
from app.core.auth import AuthenticatedUser, authenticated_user


logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/")
def root():
    return {"status": "online", "service": "Oralyn AI", "model": "ResNet50"}


@router.get("/health")
def health(request: Request):
    if request.app.state.screening_service is None:
        raise HTTPException(status_code=503, detail="Screening models are unavailable.")
    return {"status": "healthy"}


@router.post("/predict")
async def predict(
    request: Request,
    image: UploadFile = File(...),
    identity: AuthenticatedUser = Depends(authenticated_user),
):
    screening_service = request.app.state.screening_service
    if screening_service is None:
        raise HTTPException(status_code=503, detail="Screening models are unavailable.")

    pil_image = await read_valid_image(image, request.app.state.settings)
    try:
        return await run_in_threadpool(screening_service.screen, pil_image)
    except Exception as error:
        logger.error("screening_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=503, detail="Screening service is temporarily unavailable."
        ) from None
    finally:
        pil_image.close()
