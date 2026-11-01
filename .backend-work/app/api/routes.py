"""Stable public routes; inference and image parsing live elsewhere."""

import logging
import secrets

from fastapi import APIRouter, File, Header, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from app.api.upload import read_valid_image


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
    x_api_key: str | None = Header(default=None),
):
    configured_key = request.app.state.settings.api_key
    if not x_api_key:
        raise HTTPException(status_code=401, detail="API key required")
    if not configured_key or not secrets.compare_digest(x_api_key, configured_key):
        raise HTTPException(status_code=401, detail="Invalid API key")

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
