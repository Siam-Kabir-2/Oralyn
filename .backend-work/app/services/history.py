"""Orchestrate authoritative inference and durable private history."""

from __future__ import annotations

import base64
import binascii
import hashlib
import logging
import uuid
from typing import Any

from app.persistence.supabase import PersistenceUnavailable
from starlette.concurrency import run_in_threadpool


logger = logging.getLogger(__name__)


def _gradcam_bytes(result: dict[str, Any]) -> tuple[bytes, str] | None:
    gradcam = result.get("gradcam", {})
    value = gradcam.get("image_base64")
    if not gradcam.get("available") or not isinstance(value, str):
        return None
    try:
        header, encoded = value.split(",", 1)
        if header != "data:image/jpeg;base64":
            raise ValueError
        decoded = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        logger.warning("gradcam_persistence_skipped reason=invalid_encoding")
        return None
    return decoded, "image/jpeg"


def public_screening(record: dict[str, Any]) -> dict[str, Any]:
    raw_result = record.get("screening_results") or {}
    if isinstance(raw_result, list):
        raw_result = raw_result[0] if raw_result else {}
    assets = record.get("image_assets") or []
    asset_kinds = {item["asset_kind"] for item in assets}
    screening_id = record["id"]
    gradcam_available = bool(raw_result.get("gradcam_available"))
    return {
        "id": screening_id,
        "created_at": record["created_at"],
        "primary_prediction": raw_result.get("primary_prediction"),
        "primary_score": raw_result.get("primary_score"),
        "primary_predictions": raw_result.get("primary_predictions", []),
        "cancer_verification": raw_result.get(
            "cancer_verification", {"performed": False}
        ),
        "gradcam": {
            "available": gradcam_available and "gradcam" in asset_kinds,
            **(
                {"label": raw_result.get("gradcam_label")}
                if gradcam_available
                else {}
            ),
            **(
                {"asset_path": f"/screenings/{screening_id}/assets/gradcam"}
                if "gradcam" in asset_kinds
                else {}
            ),
        },
        "screening_status": raw_result.get("screening_status"),
        "model": {
            "primary": raw_result.get("primary_model"),
            "verification": raw_result.get("verification_model"),
        },
        "disclaimer": raw_result.get("disclaimer"),
        "image_path": (
            f"/screenings/{screening_id}/assets/original"
            if "original" in asset_kinds
            else None
        ),
    }


class ScreeningHistoryService:
    def __init__(self, repository, screening_service):
        self.repository = repository
        self.screening_service = screening_service

    async def save(
        self,
        *,
        owner_id: str,
        token: str,
        idempotency_key: str,
        validated_image,
    ) -> dict[str, Any]:
        existing = await self.repository.find_by_idempotency(token, idempotency_key)
        if existing is not None:
            return public_screening(existing)

        screening_id = str(uuid.uuid4())
        result = await run_in_threadpool(
            self.screening_service.screen, validated_image.image
        )
        original_path = (
            f"{owner_id}/{screening_id}/original.{validated_image.extension}"
        )
        payloads = [
            (
                "original",
                original_path,
                validated_image.contents,
                validated_image.content_type,
            )
        ]
        gradcam = _gradcam_bytes(result)
        if gradcam is not None:
            payloads.append(
                ("gradcam", f"{owner_id}/{screening_id}/gradcam.jpg", *gradcam)
            )

        uploaded: list[str] = []
        committed = False
        try:
            for _, path, contents, content_type in payloads:
                await self.repository.upload_asset(path, contents, content_type)
                uploaded.append(path)
            assets = [
                {
                    "asset_kind": kind,
                    "bucket_id": self.repository.bucket,
                    "object_path": path,
                    "content_type": content_type,
                    "byte_size": len(contents),
                    "sha256": hashlib.sha256(contents).hexdigest(),
                }
                for kind, path, contents, content_type in payloads
            ]
            stored_result = {
                **result,
                "gradcam": {
                    key: value
                    for key, value in result["gradcam"].items()
                    if key != "image_base64"
                },
            }
            saved_id, created = await self.repository.save_metadata(
                screening_id,
                owner_id,
                idempotency_key,
                stored_result,
                assets,
            )
            committed = created
            if not created:
                for path in uploaded:
                    await self.repository.delete_asset(path)
                existing = await self.repository.get_screening(token, saved_id)
                if existing is None:
                    raise PersistenceUnavailable("Saved screening was not readable")
                return public_screening(existing)
            record = await self.repository.get_screening(token, saved_id)
            if record is None:
                raise PersistenceUnavailable("Saved screening was not readable")
            return public_screening(record)
        except Exception:
            # A committed row must retain its assets. A later read failure is
            # retried by the same idempotency key, not compensated as a write.
            if not committed:
                for path in reversed(uploaded):
                    try:
                        await self.repository.delete_asset(path)
                    except PersistenceUnavailable:
                        logger.error("screening_save_cleanup_failed")
            raise

    async def delete(self, screening_id: str, owner_id: str) -> None:
        assets = await self.repository.begin_delete(screening_id, owner_id)
        if not assets:
            return False
        # A partial storage deletion stays hidden as 'deleting'. Retrying the
        # endpoint resumes cleanup; restoring 'saved' would expose broken refs.
        for asset in assets:
            await self.repository.delete_asset(asset["object_path"])
        await self.repository.finalize_delete(screening_id, owner_id)
        return True
