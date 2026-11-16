"""Case messaging stays behind Clerk identity and database membership checks."""

import unittest
from pathlib import Path
from uuid import uuid4

import httpx
from fastapi import HTTPException

from app.core.auth import AuthenticatedUser
from app.core.config import Settings
from app.main import create_app
from app.persistence.supabase import PersistenceConflict


class Verifier:
    def verify(self, token):
        if token not in {"patient", "doctor", "other"}:
            raise HTTPException(401, "Invalid or expired session")
        return AuthenticatedUser(f"user_{token}", f"sess_{token}")


class Repository:
    def __init__(self, assignment_id):
        self.assignment_id = assignment_id
        self.calls = []

    async def close(self):
        pass

    async def list_conversations(self, token):
        if token == "other":
            return []
        return [{"assignment_id": self.assignment_id, "is_active": True}]

    async def list_case_messages(self, token, assignment_id, before_at,
                                 before_id, limit):
        self.calls.append(("list", token, assignment_id, before_at,
                           before_id, limit))
        if token == "other" or assignment_id != self.assignment_id:
            raise PermissionError()
        return [{"id": str(uuid4()), "body": "Synthetic question",
                 "sender_is_self": token == "patient",
                 "created_at": "2026-11-17T00:00:00Z"}]

    async def send_case_message(self, token, assignment_id,
                                client_message_id, body):
        self.calls.append(("send", token, assignment_id,
                           client_message_id, body))
        if token == "other" or assignment_id != self.assignment_id:
            raise PermissionError()
        if body == "conflict":
            raise PersistenceConflict()
        return {"id": str(uuid4()), "body": body, "sender_is_self": True,
                "created_at": "2026-11-17T00:00:00Z"}


class MessageRouteTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.assignment_id = str(uuid4())
        self.repo = Repository(self.assignment_id)
        self.app = create_app(
            Settings(model_dir=Path("unused")), screening_service=object(),
            token_verifier=Verifier(),
            history_repository_factory=lambda: self.repo,
        )

    async def call(self, method, path, token="patient", json=None):
        headers = {} if token is None else {"Authorization": f"Bearer {token}"}
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=self.app), base_url="http://test"
        ) as client:
            return await client.request(method, path, headers=headers, json=json)

    async def test_conversations_require_authentication(self):
        self.assertEqual((await self.call("GET", "/conversations", None)).status_code,
                         401)
        self.assertEqual(len((await self.call("GET", "/conversations"))
                             .json()["items"]), 1)
        self.assertEqual((await self.call("GET", "/conversations", "other"))
                         .json()["items"], [])

    async def test_message_membership_and_cursor_validation(self):
        path = f"/cases/{self.assignment_id}/messages"
        self.assertEqual((await self.call("GET", path, None)).status_code, 401)
        self.assertEqual((await self.call("GET", path + "?before_id=" + str(uuid4())))
                         .status_code, 422)
        self.assertEqual((await self.call("GET", path + "?limit=101"))
                         .status_code, 422)
        self.assertEqual((await self.call("GET", path, "other")).status_code,
                         404)
        response = await self.call("GET", path, "doctor")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()["items"][0]["sender_is_self"])
        self.assertEqual(self.repo.calls[-1][-1], 50)

    async def test_send_requires_member_and_valid_content(self):
        path = f"/cases/{self.assignment_id}/messages"
        payload = {"client_message_id": str(uuid4()), "body": "  Synthetic question  "}
        self.assertEqual((await self.call("POST", path, None, payload)).status_code,
                         401)
        self.assertEqual((await self.call("POST", path, "other", payload))
                         .status_code, 404)
        self.assertEqual((await self.call("POST", path,
                                          json={**payload, "body": "   "}))
                         .status_code, 422)
        self.assertEqual((await self.call("POST", path,
                                          json={**payload, "body": "x" * 2001}))
                         .status_code, 422)
        response = await self.call("POST", path, json=payload)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["body"], "Synthetic question")
        self.assertEqual(self.repo.calls[-1][-1], "Synthetic question")

    async def test_conflicting_retry_is_rejected(self):
        path = f"/cases/{self.assignment_id}/messages"
        response = await self.call("POST", path, json={
            "client_message_id": str(uuid4()), "body": "conflict"})
        self.assertEqual(response.status_code, 409)
