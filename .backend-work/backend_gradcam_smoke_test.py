"""Real-checkpoint API smoke test using a generated image, never patient data."""

import asyncio
import io
import os
import time
from pathlib import Path

import httpx
from PIL import Image

from app.core.config import Settings
from app.main import create_app


class _FailGradCam:
    def render(self, *_args):
        raise RuntimeError("intentional smoke-test failure")


def _synthetic_png():
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), color=(180, 120, 115)).save(buffer, "PNG")
    return buffer.getvalue()


async def run():
    default_root = Path(os.getenv("ORALYN_BACKEND_ROOT", Path(__file__).parent))
    model_dir = Path(os.getenv("ORALYN_MODEL_DIR", default_root / "models"))
    application = create_app(Settings(api_key="smoke-test-only", model_dir=model_dir))

    async with application.router.lifespan_context(application):
        service = application.state.screening_service
        assert service is not None
        assert len(service.inference.primary_classes) == 4
        assert len(service.inference.verification_classes) == 2

        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=application),
            base_url="http://testserver",
        ) as client:
            assert (await client.get("/health")).json() == {"status": "healthy"}
            headers = {"x-api-key": "smoke-test-only"}
            invalid = await client.post(
                "/predict",
                headers=headers,
                files={"image": ("synthetic.png", b"not an image", "image/png")},
            )
            assert invalid.status_code == 400

            image = _synthetic_png()
            started = time.perf_counter()
            response = await client.post(
                "/predict",
                headers=headers,
                files={"image": ("synthetic.png", image, "image/png")},
            )
            elapsed_ms = round((time.perf_counter() - started) * 1000)
            assert response.status_code == 200, response.status_code
            payload = response.json()
            assert payload["primary_prediction"] in service.inference.primary_classes
            assert payload["gradcam"]["available"] is True
            assert payload["gradcam"]["image_base64"].startswith(
                "data:image/jpeg;base64,"
            )
            should_verify = payload["primary_prediction"] in {"OPMD", "Oral_Cancer"}
            assert payload["cancer_verification"]["performed"] is should_verify

            original_gradcam = service.gradcam
            service.gradcam = _FailGradCam()
            try:
                fallback = await client.post(
                    "/predict",
                    headers=headers,
                    files={"image": ("synthetic.png", image, "image/png")},
                )
            finally:
                service.gradcam = original_gradcam
            assert fallback.status_code == 200
            assert fallback.json()["gradcam"] == {"available": False}
            assert fallback.json()["primary_prediction"] in service.inference.primary_classes

    print("invalid_image_status=400")
    print("real_gradcam_available=true")
    print("gradcam_failure_prediction_status=200")
    print("conditional_verification_matches_primary=true")
    print(f"synthetic_screening_duration_ms={elapsed_ms}")


if __name__ == "__main__":
    asyncio.run(run())
