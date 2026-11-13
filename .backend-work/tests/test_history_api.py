"""History API contracts with synthetic images and an in-memory adapter."""

import io
import unittest
from pathlib import Path

import httpx
from fastapi import HTTPException
from PIL import Image

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app
from app.persistence.supabase import PersistenceUnavailable


def png() -> bytes:
    stream = io.BytesIO()
    Image.new("RGB", (24, 24), (110, 75, 55)).save(stream, "PNG")
    return stream.getvalue()


class TokenVerifier:
    def verify(self, token):
        if token not in {"token-a", "token-b"}:
            raise HTTPException(status_code=401, detail="Invalid or expired session")
        suffix = token[-1]
        return AuthenticatedUser(f"user_{suffix}", f"sess_{suffix}")


class SyntheticScreening:
    calls = 0

    def screen(self, image):
        self.calls += 1
        return {
            "primary_prediction": "Normal",
            "primary_score": 0.91,
            "primary_predictions": [{"class": "Normal", "score": 0.91}],
            "cancer_verification": {"performed": False},
            "gradcam": {
                "available": True,
                "label": "Area highlighted for review",
                "image_base64": "data:image/jpeg;base64,ZmFrZQ==",
            },
            "screening_status": "Low Concern",
            "model": {"primary": "primary", "verification": "verification"},
            "disclaimer": "Synthetic test only.",
        }


class MemoryRepository:
    bucket = "screening-images"

    def __init__(self):
        self.records = []
        self.objects = {}
        self.fail_after_uploads = None

    async def close(self):
        pass

    def _owner(self, token):
        return {"token-a": "user_a", "token-b": "user_b"}[token]

    async def list_screenings(self, token):
        owner = self._owner(token)
        return [row for row in self.records if row["patient_id"] == owner]

    async def get_screening(self, token, screening_id):
        owner = self._owner(token)
        return next(
            (row for row in self.records
             if row["id"] == screening_id and row["patient_id"] == owner),
            None,
        )

    async def find_by_idempotency(self, token, key):
        owner = self._owner(token)
        return next(
            (row for row in self.records
             if row["patient_id"] == owner and row["idempotency_key"] == key),
            None,
        )

    async def upload_asset(self, path, contents, content_type):
        if self.fail_after_uploads is not None and len(self.objects) >= self.fail_after_uploads:
            raise PersistenceUnavailable("synthetic upload failure")
        self.objects[path] = (contents, content_type)

    async def delete_asset(self, path):
        self.objects.pop(path, None)

    async def save_metadata(self, screening_id, owner_id, key, result, assets):
        row = {
            "id": screening_id,
            "created_at": "2026-11-11T10:00:00Z",
            "patient_id": owner_id,
            "idempotency_key": key,
            "screening_results": {
                "primary_prediction": result["primary_prediction"],
                "primary_score": result["primary_score"],
                "primary_predictions": result["primary_predictions"],
                "cancer_verification": result["cancer_verification"],
                "screening_status": result["screening_status"],
                "primary_model": result["model"]["primary"],
                "verification_model": result["model"]["verification"],
                "gradcam_available": result["gradcam"]["available"],
                "gradcam_label": result["gradcam"].get("label"),
                "disclaimer": result["disclaimer"],
            },
            "image_assets": assets,
        }
        self.records.append(row)
        return screening_id, True

    async def download_asset(self, token, path):
        if path not in self.objects:
            return httpx.Response(404)
        contents, content_type = self.objects[path]
        return httpx.Response(200, content=contents, headers={"content-type": content_type})

    async def begin_delete(self, screening_id, owner_id):
        record = next(
            (row for row in self.records
             if row["id"] == screening_id and row["patient_id"] == owner_id),
            None,
        )
        return record["image_assets"] if record else []

    async def finalize_delete(self, screening_id, owner_id):
        self.records[:] = [
            row for row in self.records
            if not (row["id"] == screening_id and row["patient_id"] == owner_id)
        ]


class HistoryApiTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repository = MemoryRepository()
        self.screening = SyntheticScreening()
        self.app = create_app(
            Settings(model_dir=Path("unused")),
            screening_service=self.screening,
            token_verifier=TokenVerifier(),
            history_repository_factory=lambda: self.repository,
        )

    async def request(self, method, path, token="token-a", **kwargs):
        headers = kwargs.pop("headers", {})
        if token is not None:
            headers["authorization"] = f"Bearer {token}"
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app), base_url="http://testserver"
        ) as client:
            return await client.request(method, path, headers=headers, **kwargs)

    async def save(self, key="save-request-0001", token="token-a"):
        return await self.request(
            "POST",
            "/screenings",
            token=token,
            data={"idempotency_key": key},
            files={"image": ("synthetic.png", png(), "image/png")},
        )

    async def test_save_list_detail_asset_and_delete(self):
        saved = await self.save()
        self.assertEqual(saved.status_code, 200)
        body = saved.json()
        self.assertEqual(body["primary_prediction"], "Normal")
        self.assertNotIn("image_base64", body["gradcam"])
        self.assertEqual(self.screening.calls, 1)
        self.assertEqual(len(self.repository.objects), 2)

        listed = await self.request("GET", "/screenings")
        self.assertEqual(len(listed.json()["items"]), 1)
        detail = await self.request("GET", f"/screenings/{body['id']}")
        self.assertEqual(detail.json()["id"], body["id"])
        image = await self.request(
            "GET", f"/screenings/{body['id']}/assets/original"
        )
        self.assertEqual(image.status_code, 200)
        self.assertEqual(image.headers["cache-control"], "private, no-store")

        deleted = await self.request("DELETE", f"/screenings/{body['id']}")
        self.assertEqual(deleted.status_code, 204)
        self.assertEqual(self.repository.records, [])
        self.assertEqual(self.repository.objects, {})

    async def test_idempotent_retry_does_not_repeat_inference_or_storage(self):
        first = await self.save()
        second = await self.save()
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.json()["id"], first.json()["id"])
        self.assertEqual(self.screening.calls, 1)
        self.assertEqual(len(self.repository.records), 1)
        self.assertEqual(len(self.repository.objects), 2)

    async def test_cross_user_and_unauthenticated_access_are_denied(self):
        saved = await self.save()
        screening_id = saved.json()["id"]
        self.assertEqual(
            (await self.request("GET", f"/screenings/{screening_id}", token="token-b")).status_code,
            404,
        )
        self.assertEqual(
            (await self.request("DELETE", f"/screenings/{screening_id}", token="token-b")).status_code,
            404,
        )
        self.assertEqual(
            (await self.request("GET", "/screenings", token=None)).status_code,
            401,
        )

    async def test_partial_upload_is_compensated(self):
        self.repository.fail_after_uploads = 1
        response = await self.save("save-request-failure")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(self.repository.objects, {})
        self.assertEqual(self.repository.records, [])

    async def test_invalid_idempotency_and_oversized_image_are_rejected(self):
        invalid = await self.save("short")
        self.assertEqual(invalid.status_code, 400)
        oversized = await self.request(
            "POST",
            "/screenings",
            data={"idempotency_key": "save-request-oversized"},
            files={"image": ("large.png", b"x" * (10 * 1024 * 1024 + 1), "image/png")},
        )
        self.assertEqual(oversized.status_code, 413)
        self.assertEqual(self.screening.calls, 0)


if __name__ == "__main__":
    unittest.main()
