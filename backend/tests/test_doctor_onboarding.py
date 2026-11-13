"""Doctor onboarding is scoped to the verified session subject."""

import unittest
from pathlib import Path

import httpx
from fastapi import HTTPException

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app


class Verifier:
    def verify(self, token):
        if token not in {"patient", "doctor", "admin", "suspended"}:
            raise HTTPException(401, "Invalid session")
        return AuthenticatedUser(f"user_{token}", f"sess_{token}")


class Repository:
    def __init__(self):
        self.roles = {"patient": "patient", "doctor": "doctor",
                      "admin": "admin", "suspended": "doctor"}
        self.state = {"doctor": "verified", "suspended": "suspended"}
        self.application = None
        self.update = None

    async def close(self):
        pass

    async def identity_profile(self, token, user_id):
        assert user_id == f"user_{token}"
        return {"application_role": self.roles[token],
                "doctor_profiles": {"verification_state": self.state[token]}
                if token in self.state else None}

    async def apply_doctor_candidate(self, user_id, data):
        self.application = (user_id, data)
        self.roles["patient"] = "doctor"
        self.state["patient"] = "pending"

    async def doctor_profile(self, token, user_id):
        assert user_id == f"user_{token}"
        return {"display_name": "Synthetic Doctor",
                "verification_state": self.state[token]}

    async def update_doctor_profile(self, user_id, data):
        self.update = (user_id, data)
        self.state["doctor"] = "pending"


class DoctorOnboardingTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = Repository()
        self.app = create_app(Settings(model_dir=Path("unused")),
                              screening_service=object(), token_verifier=Verifier(),
                              history_repository_factory=lambda: self.repo)
        self.details = {"display_name": "Synthetic Doctor",
                        "specialization": "Oral medicine",
                        "qualification": "Synthetic degree",
                        "registration_reference": "TEST-001",
                        "workplace": "Test clinic"}

    async def call(self, method, path, token="patient", json=None):
        headers = {} if token is None else {"authorization": f"Bearer {token}"}
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=self.app),
                                     base_url="http://test") as client:
            return await client.request(method, path, headers=headers, json=json)

    async def test_application_requires_identity_and_stays_pending(self):
        self.assertEqual((await self.call("POST", "/doctor/applications", None,
                                     self.details)).status_code, 401)
        self.assertEqual((await self.call("POST", "/doctor/applications", "admin",
                                     self.details)).status_code, 409)
        result = await self.call("POST", "/doctor/applications", json=self.details)
        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.json(), {"verification_state": "pending"})
        self.assertEqual(self.repo.application[0], "user_patient")
        self.assertEqual((await self.call("POST", "/doctor/applications",
                                          json=self.details)).status_code, 409)

    async def test_profile_access_and_edit_are_role_restricted(self):
        self.assertEqual((await self.call("GET", "/doctor/profile")).status_code, 403)
        self.assertEqual((await self.call("GET", "/doctor/profile", "doctor")
                          ).json()["verification_state"], "verified")
        self.assertEqual((await self.call("PUT", "/doctor/profile", "suspended",
                                      self.details)).status_code, 403)
        result = await self.call("PUT", "/doctor/profile", "doctor", self.details)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.json()["verification_state"], "pending")
        self.assertEqual(self.repo.update[0], "user_doctor")
        self.assertEqual((await self.call("PUT", "/doctor/profile", "doctor",
                                      {**self.details, "workplace": " "})).status_code, 422)
