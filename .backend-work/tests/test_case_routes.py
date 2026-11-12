"""Case API authorization contracts without real accounts or patient data."""

import unittest
from pathlib import Path
from uuid import uuid4

import httpx
from fastapi import HTTPException

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app


class TokenVerifier:
    def verify(self, token):
        if token not in {"patient", "doctor", "suspended"}:
            raise HTTPException(401, "Invalid or expired session")
        return AuthenticatedUser(f"user_{token}", f"sess_{token}")


class CaseRepository:
    def __init__(self):
        self.requests = {}
        self.assignments = []
        self.state = "verified"
        self.review_version = 0
        self.case_accesses = 0

    async def close(self):
        pass

    async def identity_profile(self, token, user_id):
        if token == "patient":
            return {"clerk_user_id": user_id, "application_role": "patient",
                    "doctor_profiles": None}
        return {"clerk_user_id": user_id, "application_role": "doctor",
                "doctor_profiles": {"verification_state":
                                    "suspended" if token == "suspended" else self.state}}

    async def request_review(self, token, screening_id):
        if token != "patient" or screening_id != self.owned_screening:
            raise PermissionError()
        return self.requests.setdefault(
            screening_id, {"id": str(uuid4()), "status": "pending_assignment"}
        )

    async def list_review_requests(self, token):
        return list(self.requests.values()) if token == "patient" else []

    async def my_doctor_feedback(self, token):
        return [{"screening_id": self.owned_screening,
                 "observations": "Synthetic feedback"}] if token == "patient" else []

    async def list_assigned_cases(self, token):
        return self.assignments if token == "doctor" else []

    async def get_screening(self, token, screening_id):
        if token == "doctor" and screening_id == self.owned_screening:
            return {"id": screening_id, "created_at": "2026-11-12T00:00:00Z",
                    "screening_results": {"primary_prediction": "Normal",
                    "primary_score": 0.8, "primary_predictions": [],
                    "cancer_verification": {"performed": False},
                    "screening_status": "Low Concern", "primary_model": "primary",
                    "verification_model": "secondary", "gradcam_available": False,
                    "disclaimer": "Synthetic test."}, "image_assets": []}
        return None

    async def get_doctor_review(self, token, assignment_id):
        return None

    async def record_case_access(self, token, assignment_id):
        self.case_accesses += 1

    async def save_doctor_review(self, token, assignment_id, payload):
        from app.persistence.supabase import PersistenceConflict
        if not self.assignments or self.assignments[0]["id"] != assignment_id:
            raise PermissionError()
        if payload["expected_version"] != self.review_version:
            raise PersistenceConflict()
        self.review_version += 1
        return {"review_id": "synthetic-review", "review_version": self.review_version,
                "review_state": "submitted" if payload["submit"] else "draft"}


class CaseRoutesTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = CaseRepository()
        self.repo.owned_screening = str(uuid4())
        self.app = create_app(
            Settings(model_dir=Path("unused")), screening_service=object(),
            token_verifier=TokenVerifier(),
            history_repository_factory=lambda: self.repo,
        )

    async def call(self, method, path, token="patient", json=None):
        headers = {} if token is None else {"Authorization": f"Bearer {token}"}
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app), base_url="http://test"
        ) as client:
            return await client.request(method, path, headers=headers, json=json)

    async def test_consent_owner_and_idempotent_review_request(self):
        path = f"/screenings/{self.repo.owned_screening}/review-request"
        self.assertEqual((await self.call("POST", path,
                                     json={"consent_to_share": False})).status_code, 400)
        self.assertEqual((await self.call("POST", path, token=None,
                                     json={"consent_to_share": True})).status_code, 401)
        self.assertEqual((await self.call("POST", f"/screenings/{uuid4()}/review-request",
                                     json={"consent_to_share": True})).status_code, 404)
        first = await self.call("POST", path, json={"consent_to_share": True})
        second = await self.call("POST", path, json={"consent_to_share": True})
        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.json(), second.json())
        self.assertEqual(len((await self.call("GET", "/review-requests")).json()["items"]), 1)
        self.assertEqual((await self.call("GET", "/feedback")).json()["items"][0]
                         ["observations"], "Synthetic feedback")
        self.assertEqual((await self.call("GET", "/feedback", "doctor")).status_code, 403)
        self.assertEqual((await self.call("POST", path, token="doctor",
                                     json={"consent_to_share": True})).status_code, 403)

    async def test_doctor_verification_is_database_backed(self):
        assignment_id = str(uuid4())
        self.repo.assignments = [{"id": assignment_id,
                                  "review_requests": {"screening_id": self.repo.owned_screening}}]
        self.assertEqual((await self.call("GET", "/doctor/cases")).status_code, 403)
        self.assertEqual((await self.call("GET", "/doctor/cases", "suspended")).status_code, 403)
        self.assertEqual(len((await self.call("GET", "/doctor/cases", "doctor")).json()["items"]), 1)
        detail = await self.call("GET", f"/doctor/cases/{assignment_id}", "doctor")
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.json()["screening"]["primary_prediction"], "Normal")
        self.assertEqual(self.repo.case_accesses, 1)
        self.repo.assignments = []
        self.assertEqual((await self.call("GET", f"/doctor/cases/{assignment_id}",
                                          "doctor")).status_code, 404)
        self.repo.state = "suspended"
        self.assertEqual((await self.call("GET", "/doctor/cases", "doctor")).status_code, 403)

    async def test_review_version_and_assignment_are_enforced(self):
        assignment_id = str(uuid4())
        self.repo.assignments = [{"id": assignment_id,
                                  "review_requests": {"screening_id": self.repo.owned_screening}}]
        path = f"/doctor/cases/{assignment_id}/review"
        payload = {"expected_version": 0, "observations": "Synthetic observation",
                   "recommendations": "Synthetic recommendation", "follow_up": "Review later",
                   "submit": False}
        self.assertEqual((await self.call("PUT", path, "patient", payload)).status_code, 403)
        self.assertEqual((await self.call("PUT", path, "doctor",
                          {**payload, "observations": ""})).status_code, 422)
        self.assertEqual((await self.call("PUT", path, "doctor", payload)).json()["review_version"], 1)
        self.assertEqual((await self.call("PUT", path, "doctor", payload)).status_code, 409)
        payload["expected_version"] = 1
        payload["submit"] = True
        self.assertEqual((await self.call("PUT", path, "doctor", payload)).json()["review_state"],
                         "submitted")
        self.repo.assignments = []
        self.assertEqual((await self.call("PUT", path, "doctor", payload)).status_code, 404)
