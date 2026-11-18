"""Read verified Patient identity from Clerk without trusting mobile fields."""

from datetime import datetime, timezone
import re

import httpx


class ClerkProfileUnavailable(Exception):
    pass


class ClerkProfileClient:
    def __init__(self, secret_key: str, client: httpx.AsyncClient | None = None):
        if not secret_key.startswith("sk_"):
            raise ClerkProfileUnavailable("Clerk backend access is not configured")
        self._owns_client = client is None
        self.client = client or httpx.AsyncClient(
            base_url="https://api.clerk.com/v1/",
            timeout=8,
            follow_redirects=False,
        )
        self._headers = {"Authorization": f"Bearer {secret_key}"}

    async def close(self) -> None:
        if self._owns_client:
            await self.client.aclose()

    async def patient_identity(self, user_id: str) -> dict:
        if not re.fullmatch(r"user_[A-Za-z0-9]+", user_id):
            raise ClerkProfileUnavailable("Invalid Patient identifier")
        try:
            response = await self.client.get(
                f"users/{user_id}", headers=self._headers,
            )
        except (httpx.TimeoutException, httpx.NetworkError):
            raise ClerkProfileUnavailable("Clerk profile is unavailable") from None
        if response.status_code != 200:
            raise ClerkProfileUnavailable("Clerk profile is unavailable")
        try:
            user = response.json()
            if not isinstance(user, dict) or user.get("id") != user_id:
                raise ValueError("Unexpected Clerk user")
            name = " ".join(str(user.get(field) or "").strip()
                            for field in ("first_name", "last_name")).strip()
            if not name:
                name = str(user.get("username") or "").strip()
            if len(name) < 2:
                name = ""
            primary_id = user.get("primary_email_address_id")
            email = None
            for entry in user.get("email_addresses") or []:
                if not isinstance(entry, dict) or entry.get("id") != primary_id:
                    continue
                verification = entry.get("verification") or {}
                if (isinstance(verification, dict)
                        and verification.get("status") == "verified"):
                    email = entry.get("email_address")
                break
            created_ms = user.get("created_at")
            created_at = (datetime.fromtimestamp(created_ms / 1000, timezone.utc)
                          .isoformat() if isinstance(created_ms, (int, float))
                          else None)
            return {
                "display_name": name[:160] or None,
                "verified_email": (email if isinstance(email, str)
                                   and 3 <= len(email) <= 320 else None),
                "clerk_created_at": created_at,
            }
        except (ValueError, TypeError, OverflowError):
            raise ClerkProfileUnavailable("Clerk profile response is invalid") from None
