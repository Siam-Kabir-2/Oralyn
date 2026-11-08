"""Supabase REST and Storage adapter with explicit privilege boundaries."""

from __future__ import annotations

import logging
from typing import Any
from urllib.parse import quote

import httpx


logger = logging.getLogger(__name__)


class PersistenceUnavailable(Exception):
    pass


class PersistenceConflict(Exception):
    pass


class SupabaseRepository:
    screening_select = (
        "id,created_at,patient_id,idempotency_key,"
        "screening_results(*),image_assets(*)"
    )

    def __init__(self, settings, client: httpx.AsyncClient | None = None):
        if not settings.persistence_configured:
            raise PersistenceUnavailable("Supabase persistence is not configured")
        self.url = settings.supabase_url
        self.publishable_key = settings.supabase_publishable_key
        self.secret_key = settings.supabase_secret_key
        self.bucket = settings.supabase_storage_bucket
        self._owns_client = client is None
        self.client = client or httpx.AsyncClient(
            timeout=settings.supabase_timeout_seconds,
            follow_redirects=False,
            headers={"User-Agent": "Oralyn-Backend/1.0"},
        )

    async def close(self) -> None:
        if self._owns_client:
            await self.client.aclose()

    def _user_headers(self, token: str) -> dict[str, str]:
        return {
            "apikey": self.publishable_key,
            "authorization": f"Bearer {token}",
            "accept": "application/json",
        }

    def _admin_headers(self) -> dict[str, str]:
        # Modern opaque Supabase keys belong in apikey, never as bearer JWTs.
        return {"apikey": self.secret_key, "accept": "application/json"}

    async def _request(self, method: str, url: str, **kwargs) -> httpx.Response:
        try:
            response = await self.client.request(method, url, **kwargs)
        except (httpx.TimeoutException, httpx.NetworkError):
            raise PersistenceUnavailable("Supabase request failed") from None
        if response.status_code >= 500:
            raise PersistenceUnavailable("Supabase service failed")
        return response

    async def list_screenings(self, token: str) -> list[dict[str, Any]]:
        response = await self._request(
            "GET",
            f"{self.url}/rest/v1/screenings",
            headers=self._user_headers(token),
            params={
                "select": self.screening_select,
                "order": "created_at.desc",
                "limit": "100",
            },
        )
        if response.status_code != 200:
            raise PersistenceUnavailable("Could not load screening history")
        return response.json()

    async def get_screening(
        self, token: str, screening_id: str
    ) -> dict[str, Any] | None:
        response = await self._request(
            "GET",
            f"{self.url}/rest/v1/screenings",
            headers=self._user_headers(token),
            params={
                "select": self.screening_select,
                "id": f"eq.{screening_id}",
                "limit": "1",
            },
        )
        if response.status_code != 200:
            raise PersistenceUnavailable("Could not load screening")
        rows = response.json()
        return rows[0] if rows else None

    async def find_by_idempotency(
        self, token: str, idempotency_key: str
    ) -> dict[str, Any] | None:
        response = await self._request(
            "GET",
            f"{self.url}/rest/v1/screenings",
            headers=self._user_headers(token),
            params={
                "select": self.screening_select,
                "idempotency_key": f"eq.{idempotency_key}",
                "limit": "1",
            },
        )
        if response.status_code != 200:
            raise PersistenceUnavailable("Could not check save request")
        rows = response.json()
        return rows[0] if rows else None

    async def upload_asset(
        self, object_path: str, contents: bytes, content_type: str
    ) -> None:
        response = await self._request(
            "POST",
            f"{self.url}/storage/v1/object/{quote(self.bucket)}/{quote(object_path)}",
            headers={
                **self._admin_headers(),
                "content-type": content_type,
                "x-upsert": "false",
            },
            content=contents,
        )
        if response.status_code not in (200, 201):
            if response.status_code == 409:
                raise PersistenceConflict("Storage object already exists")
            raise PersistenceUnavailable("Could not store private image")

    async def delete_asset(self, object_path: str) -> None:
        response = await self._request(
            "DELETE",
            f"{self.url}/storage/v1/object/{quote(self.bucket)}/{quote(object_path)}",
            headers=self._admin_headers(),
        )
        if response.status_code not in (200, 204, 404):
            raise PersistenceUnavailable("Could not delete private image")

    async def download_asset(self, token: str, object_path: str) -> httpx.Response:
        response = await self._request(
            "GET",
            f"{self.url}/storage/v1/object/authenticated/"
            f"{quote(self.bucket)}/{quote(object_path)}",
            headers=self._user_headers(token),
        )
        if response.status_code == 404:
            return response
        if response.status_code != 200:
            raise PersistenceUnavailable("Could not load private image")
        return response

    async def save_metadata(
        self,
        screening_id: str,
        owner_id: str,
        idempotency_key: str,
        result: dict[str, Any],
        assets: list[dict[str, Any]],
    ) -> tuple[str, bool]:
        response = await self._request(
            "POST",
            f"{self.url}/rest/v1/rpc/save_screening",
            headers={**self._admin_headers(), "content-type": "application/json"},
            json={
                "p_screening_id": screening_id,
                "p_owner_id": owner_id,
                "p_idempotency_key": idempotency_key,
                "p_result": result,
                "p_assets": assets,
            },
        )
        if response.status_code not in (200, 201):
            raise PersistenceUnavailable("Could not save screening metadata")
        row = response.json()[0]
        return row["screening_id"], row["created"]

    async def begin_delete(
        self, screening_id: str, owner_id: str
    ) -> list[dict[str, str]]:
        response = await self._request(
            "POST",
            f"{self.url}/rest/v1/rpc/begin_screening_delete",
            headers={**self._admin_headers(), "content-type": "application/json"},
            json={"p_screening_id": screening_id, "p_owner_id": owner_id},
        )
        if response.status_code not in (200, 201):
            raise PersistenceUnavailable("Could not begin screening deletion")
        return response.json()

    async def finalize_delete(self, screening_id: str, owner_id: str) -> None:
        await self._delete_rpc("finalize_screening_delete", screening_id, owner_id)

    async def restore_delete(self, screening_id: str, owner_id: str) -> None:
        await self._delete_rpc("restore_screening_delete", screening_id, owner_id)

    async def _delete_rpc(
        self, function: str, screening_id: str, owner_id: str
    ) -> None:
        response = await self._request(
            "POST",
            f"{self.url}/rest/v1/rpc/{function}",
            headers={**self._admin_headers(), "content-type": "application/json"},
            json={"p_screening_id": screening_id, "p_owner_id": owner_id},
        )
        if response.status_code not in (200, 204):
            raise PersistenceUnavailable("Could not update deletion state")
