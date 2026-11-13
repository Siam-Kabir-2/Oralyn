"""ASGI application factory with one-time model startup."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.ai.gradcam import GradCamRenderer
from app.ai.models import ModelInference
from app.api.routes import router
from app.api.history_routes import router as history_router
from app.api.case_routes import router as case_router
from app.api.doctor_onboarding_routes import router as doctor_onboarding_router
from app.api.upload import RequestSizeLimitMiddleware
from app.core.config import Settings
from app.core.auth import ClerkTokenVerifier
from app.services.screening import ScreeningService
from app.persistence.supabase import SupabaseRepository


logger = logging.getLogger(__name__)


def create_app(
    settings: Settings | None = None, screening_service=None, token_verifier=None,
    history_repository_factory=None,
) -> FastAPI:
    settings = settings or Settings.from_environment()

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        if application.state.token_verifier is None:
            if not settings.clerk_issuer:
                raise RuntimeError("CLERK_ISSUER is not configured")
            application.state.token_verifier = ClerkTokenVerifier(
                settings.clerk_issuer, settings.clerk_authorized_parties,
                settings.clerk_audience,
            )
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
    application.state.token_verifier = token_verifier
    application.state.history_repository_factory = (
        history_repository_factory
        if history_repository_factory is not None
        else (
            (lambda: SupabaseRepository(settings))
            if settings.persistence_configured
            else None
        )
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=["http://127.0.0.1:8081"],
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Content-Type", "Authorization"],
    )
    application.add_middleware(
        RequestSizeLimitMiddleware, max_request_bytes=settings.max_request_bytes
    )
    application.include_router(router)
    application.include_router(history_router)
    application.include_router(case_router)
    application.include_router(doctor_onboarding_router)
    return application


app = create_app()
