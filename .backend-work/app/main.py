"""ASGI application factory with one-time model startup."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.ai.gradcam import GradCamRenderer
from app.ai.models import ModelInference
from app.api.routes import router
from app.api.upload import RequestSizeLimitMiddleware
from app.core.config import Settings
from app.services.screening import ScreeningService


logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None, screening_service=None) -> FastAPI:
    settings = settings or Settings.from_environment()

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        if not settings.api_key:
            raise RuntimeError("ORALYN_API_KEY is not configured")
        if application.state.screening_service is None:
            try:
                inference = ModelInference.load(settings.model_dir)
                renderer = GradCamRenderer(inference)
                application.state.screening_service = ScreeningService(inference, renderer)
            except Exception as error:
                logger.error("model_startup_failed error_type=%s", type(error).__name__)
                raise RuntimeError("Screening models could not be initialized") from None
        yield

    application = FastAPI(title="Oralyn AI API", version="1.0", lifespan=lifespan)
    application.state.settings = settings
    application.state.screening_service = screening_service
    application.add_middleware(
        CORSMiddleware,
        allow_origins=["http://127.0.0.1:8081"],
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "x-api-key"],
    )
    application.add_middleware(
        RequestSizeLimitMiddleware, max_request_bytes=settings.max_request_bytes
    )
    application.include_router(router)
    return application


app = create_app()
