"""Patient identity comes from Clerk and never from mobile request fields."""

import json
import unittest
from pathlib import Path

import httpx
from fastapi import HTTPException

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app
from app.persistence.supabase import SupabaseRepository
from app.services.clerk_profile import ClerkProfileClient, ClerkProfileUnavailable


class Verifier:
    def verify(self, token):
        if token not in {"patient", "doctor"}:
            raise HTTPException(401, "Invalid session")
        return AuthenticatedUser(f"user_{token}", f"sess_{token}")


class Repository:
    def __init__(self):
        self.synced = None

    async def close(self):
        pass

    async def identity_profile(self, token, user_id):
        assert user_id == f"user_{token}"
        return {"application_role": token}

    async def sync_patient_profile(self, user_id, fields):
        self.synced = (user_id, fields)


class Directory:
    def __init__(self, fail=False):
        self.calls = 0
        self.fail = fail

    async def close(self):
        pass

    async def patient_identity(self, user_id):
        self.calls += 1
        if self.fail:
            raise ClerkProfileUnavailable("Synthetic failure")
        return {"display_name": "Synthetic Patient",
                "verified_email": "patient@example.test",
                "clerk_created_at": "2026-11-01T00:00:00+00:00"}


class PatientProfileTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = Repository()
        self.directory = Directory()
        self.app = create_app(
            Settings(model_dir=Path("unused")),
            screening_service=object(), token_verifier=Verifier(),
            history_repository_factory=lambda: self.repo,
            clerk_profile_factory=lambda: self.directory,
        )

    async def call(self, token):
        headers = {} if token is None else {"authorization": f"Bearer {token}"}
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app), base_url="http://test",
        ) as client:
            return await client.get("/me", headers=headers)

    async def test_only_verified_patient_subject_is_synced(self):
        self.assertEqual((await self.call(None)).status_code, 401)
        self.assertIsNone(self.repo.synced)
        self.assertEqual((await self.call("doctor")).status_code, 200)
        self.assertEqual(self.directory.calls, 0)
        self.assertEqual((await self.call("patient")).status_code, 200)
        self.assertEqual(self.repo.synced[0], "user_patient")
        self.assertEqual(self.repo.synced[1]["verified_email"],
                         "patient@example.test")

    async def test_clerk_outage_does_not_block_patient_session(self):
        self.directory.fail = True
        response = await self.call("patient")
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(self.repo.synced)

    async def test_repository_writes_only_trusted_identity_fields(self):
        def handler(request):
            self.assertEqual(request.url.path, "/rest/v1/patient_profiles")
            self.assertEqual(request.method, "POST")
            self.assertEqual(request.headers["apikey"], "sb_secret_test")
            self.assertNotIn("authorization", request.headers)
            value = json.loads(request.read())
            self.assertEqual(value["clerk_user_id"], "user_patient")
            self.assertEqual(value["verified_email"], "patient@example.test")
            self.assertEqual(set(value), {"clerk_user_id", "display_name",
                                          "verified_email", "clerk_created_at",
                                          "synced_at"})
            return httpx.Response(201)

        settings = Settings(model_dir=Path("unused"),
            supabase_url="https://example.supabase.co",
            supabase_publishable_key="sb_publishable_test",
            supabase_secret_key="sb_secret_test")
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            repository = SupabaseRepository(settings, client=client)
            await repository.sync_patient_profile("user_patient", {
                "display_name": "Synthetic Patient",
                "verified_email": "patient@example.test",
                "clerk_created_at": "2026-11-01T00:00:00+00:00",
            })

    async def test_clerk_source_rejects_unverified_primary_email(self):
        def handler(request):
            self.assertEqual(request.url.path, "/v1/users/user_patient")
            return httpx.Response(200, json={
                "id": "user_patient", "first_name": "Synthetic",
                "last_name": "Patient", "created_at": 1793491200000,
                "primary_email_address_id": "email_primary",
                "email_addresses": [
                    {"id": "email_other", "email_address": "other@example.test",
                     "verification": {"status": "verified"}},
                    {"id": "email_primary", "email_address": "new@example.test",
                     "verification": {"status": "unverified"}},
                ],
            })

        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler),
            base_url="https://api.clerk.com/v1/",
        ) as client:
            directory = ClerkProfileClient("sk_test_synthetic", client)
            identity = await directory.patient_identity("user_patient")
        self.assertEqual(identity["display_name"], "Synthetic Patient")
        self.assertIsNone(identity["verified_email"])
        self.assertIsNotNone(identity["clerk_created_at"])
