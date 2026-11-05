"""Public API checks with generated images and no model checkpoints."""

import io
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx
from PIL import Image
from fastapi import HTTPException

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app
from app.services.screening import ScreeningService


def png(size=(32, 32)):
    stream = io.BytesIO()
    Image.new("RGB", size, (120, 80, 60)).save(stream, format="PNG")
    return stream.getvalue()


class FakeInference:
    primary_class_to_idx = {
        "Normal": 0,
        "Variation_from_Normal": 1,
        "OPMD": 2,
        "Oral_Cancer": 3,
    }

    def __init__(self, primary="Normal", verification="Cancer"):
        self.primary = primary
        self.verification = verification
        self.primary_calls = 0
        self.verification_calls = 0

    def preprocess(self, image):
        return image.size

    def predict_primary(self, tensor):
        self.primary_calls += 1
        return [{"class": self.primary, "score": 0.8}]

    def predict_verification(self, tensor):
        self.verification_calls += 1
        return [{"class": self.verification, "score": 0.7}]


class FakeGradCam:
    def __init__(self, fail=False):
        self.fail = fail
        self.calls = 0

    def render(self, image, tensor, target_class):
        self.calls += 1
        if self.fail:
            raise RuntimeError("private image name must not reach logs")
        return "data:image/jpeg;base64,ZmFrZQ=="


class FakeTokenVerifier:
    def verify(self, token):
        if token != "test-session":
            raise HTTPException(status_code=401, detail="Invalid or expired session")
        return AuthenticatedUser("user_synthetic", "sess_synthetic")


class ApiContractTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.inference = FakeInference()
        self.gradcam = FakeGradCam()
        self.settings = Settings(api_key="test-key", model_dir=Path("unused"))
        self.app = create_app(
            settings=self.settings,
            screening_service=ScreeningService(self.inference, self.gradcam),
            token_verifier=FakeTokenVerifier(),
        )

    async def request(self, path="/predict", *, data=None, key="test-session", mime="image/png"):
        headers = {} if key is None else {"authorization": f"Bearer {key}"}
        files = None if data is None else {"image": ("synthetic.png", data, mime)}
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app),
            base_url="http://testserver",
        ) as client:
            return await client.post(path, headers=headers, files=files)

    async def test_low_concern_response_contract_and_no_verification(self):
        response = await self.request(data=png())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "primary_prediction": "Normal",
                "primary_score": 0.8,
                "primary_predictions": [{"class": "Normal", "score": 0.8}],
                "cancer_verification": {"performed": False},
                "gradcam": {
                    "available": True,
                    "label": "Area highlighted for review",
                    "image_base64": "data:image/jpeg;base64,ZmFrZQ==",
                },
                "screening_status": "Low Concern",
                "model": {
                    "primary": "ResNet50 SMART-OM 4-class",
                    "verification": "ResNet50 BMIOCD binary",
                },
                "disclaimer": (
                    "AI-assisted research screening only. "
                    "This result is not a clinical diagnosis."
                ),
            },
        )
        self.assertEqual(self.inference.verification_calls, 0)

    async def test_both_higher_concern_classes_invoke_verification(self):
        for primary in ("OPMD", "Oral_Cancer"):
            with self.subTest(primary=primary):
                self.inference.primary = primary
                response = await self.request(data=png())
                self.assertEqual(response.status_code, 200)
                body = response.json()
                self.assertEqual(body["cancer_verification"], {
                    "performed": True,
                    "prediction": "Cancer",
                    "score": 0.7,
                    "predictions": [{"class": "Cancer", "score": 0.7}],
                })
                self.assertEqual(body["screening_status"], "Prompt Specialist Review")
        self.assertEqual(self.inference.verification_calls, 2)

    async def test_variation_and_non_cancer_guidance_remains_unchanged(self):
        self.inference.primary = "Variation_from_Normal"
        variation = await self.request(data=png())
        self.assertEqual(variation.json()["screening_status"], "Review Recommended")
        self.assertEqual(self.inference.verification_calls, 0)

        self.inference.primary = "OPMD"
        self.inference.verification = "Non_Cancer"
        non_cancer = await self.request(data=png())
        self.assertEqual(
            non_cancer.json()["screening_status"], "Professional Review Recommended"
        )
        self.assertEqual(self.inference.verification_calls, 1)

    async def test_gradcam_failure_keeps_prediction_without_leaking_error(self):
        self.gradcam.fail = True
        with self.assertLogs("app.services.screening", level="WARNING") as logs:
            response = await self.request(data=png())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["gradcam"], {"available": False})
        self.assertNotIn("private image name", " ".join(logs.output))

    async def test_session_validation_precedes_image_processing(self):
        for key in (None, "wrong"):
            with self.subTest(key=key):
                response = await self.request(data=png(), key=key)
                self.assertEqual(response.status_code, 401)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_invalid_image_and_mime(self):
        for data, mime in (
            (b"not an image", "image/png"),
            (png()[:40], "image/png"),
            (png(), "text/plain"),
        ):
            with self.subTest(mime=mime):
                response = await self.request(data=data, mime=mime)
                self.assertEqual(response.status_code, 400)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_oversized_upload_is_rejected(self):
        response = await self.request(data=b"x" * (10 * 1024 * 1024 + 1))
        self.assertEqual(response.status_code, 413)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_exact_10_mb_file_remains_allowed(self):
        valid = png()
        padded = valid + b"x" * (self.settings.max_image_bytes - len(valid))
        response = await self.request(data=padded)
        self.assertEqual(response.status_code, 200)

    async def test_streamed_request_body_has_a_total_size_limit(self):
        async def oversized_stream():
            yield (
                b'--test\r\nContent-Disposition: form-data; name="image"; '
                b'filename="synthetic.png"\r\nContent-Type: image/png\r\n\r\n'
            )
            yield b"x" * (self.settings.max_request_bytes // 2)
            yield b"x" * (self.settings.max_request_bytes // 2 + 1)
            yield b"\r\n--test--\r\n"

        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app),
            base_url="http://testserver",
        ) as client:
            response = await client.post(
                "/predict",
                content=oversized_stream(),
                headers={"content-type": "multipart/form-data; boundary=test"},
            )
        self.assertEqual(response.status_code, 413)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_decoded_pixel_limit_is_enforced(self):
        self.app.state.settings = Settings(
            api_key="test-key", model_dir=Path("unused"), max_image_pixels=1000
        )
        response = await self.request(data=png((40, 40)))
        self.assertEqual(response.status_code, 413)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_default_pixel_limit_rejects_small_compressed_large_image(self):
        response = await self.request(data=png((2001, 2000)))
        self.assertEqual(response.status_code, 413)
        self.assertEqual(self.inference.primary_calls, 0)

    async def test_model_failure_is_a_generic_service_error(self):
        with patch.object(
            self.inference,
            "predict_primary",
            side_effect=RuntimeError("private patient detail"),
        ):
            with self.assertLogs("app.api.routes", level="ERROR") as logs:
                response = await self.request(data=png())
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private patient detail", response.text)
        self.assertNotIn("private patient detail", " ".join(logs.output))

    async def test_health_reflects_readiness(self):
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app),
            base_url="http://testserver",
        ) as client:
            self.assertEqual((await client.get("/health")).json(), {"status": "healthy"})
            self.app.state.screening_service = None
            response = await client.get("/health")
        self.assertEqual(response.status_code, 503)

    async def test_missing_checkpoint_fails_startup(self):
        unavailable = create_app(
            settings=Settings(
                api_key="", model_dir=Path("missing-checkpoints"),
                clerk_issuer="https://unit-test.clerk.accounts.dev",
            )
        )
        with self.assertRaisesRegex(RuntimeError, "could not be initialized"):
            async with unavailable.router.lifespan_context(unavailable):
                pass

    async def test_missing_clerk_issuer_fails_startup(self):
        unavailable = create_app(
            settings=Settings(api_key="", model_dir=Path("unused")),
            screening_service=ScreeningService(self.inference, self.gradcam),
        )
        with self.assertRaisesRegex(RuntimeError, "not configured"):
            async with unavailable.router.lifespan_context(unavailable):
                pass


if __name__ == "__main__":
    unittest.main()
