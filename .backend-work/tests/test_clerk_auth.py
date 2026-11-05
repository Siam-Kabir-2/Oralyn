"""Clerk JWT validation with synthetic keys and no live account data."""

import time
import io
import unittest
from pathlib import Path
from unittest.mock import patch

import jwt
import httpx
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException
from PIL import Image

from app.core.auth import ClerkTokenVerifier
from app.core.config import Settings
from app.main import create_app


ISSUER = "https://unit-test.clerk.accounts.dev"


class ClerkTokenVerifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.public_jwk = jwt.algorithms.RSAAlgorithm.to_jwk(cls.private_key.public_key(), as_dict=True)
        cls.public_jwk["kid"] = "test-key"
        cls.public_jwk["alg"] = "RS256"

    def setUp(self):
        self.verifier = ClerkTokenVerifier(ISSUER, ("https://oralyn.example",))
        self.fetcher = patch.object(
            self.verifier.jwks, "fetch_data", return_value={"keys": [self.public_jwk]}
        )
        self.fetcher.start()
        self.addCleanup(self.fetcher.stop)

    def token(self, **overrides):
        now = int(time.time())
        claims = {
            "iss": ISSUER,
            "sub": "user_synthetic",
            "sid": "sess_synthetic",
            "iat": now,
            "nbf": now,
            "exp": now + 60,
            "azp": "https://oralyn.example",
        }
        claims.update(overrides)
        return jwt.encode(
            claims, self.private_key, algorithm="RS256", headers={"kid": "test-key"}
        )

    def test_accepts_valid_clerk_session(self):
        identity = self.verifier.verify(self.token())
        self.assertEqual(identity.user_id, "user_synthetic")
        self.assertEqual(identity.session_id, "sess_synthetic")

    def test_rejects_expired_or_future_session(self):
        now = int(time.time())
        for claims in ({"exp": now - 30}, {"nbf": now + 30}):
            with self.subTest(claims=claims):
                with self.assertRaises(HTTPException) as error:
                    self.verifier.verify(self.token(**claims))
                self.assertEqual(error.exception.status_code, 401)

    def test_rejects_wrong_issuer_and_invalid_subject(self):
        for claims in ({"iss": "https://other.example"}, {"sub": "attacker"}):
            with self.subTest(claims=claims):
                with self.assertRaises(HTTPException) as error:
                    self.verifier.verify(self.token(**claims))
                self.assertEqual(error.exception.status_code, 401)

    def test_rejects_unapproved_party(self):
        with self.assertRaises(HTTPException) as error:
            self.verifier.verify(self.token(azp="https://attacker.example"))
        self.assertEqual(error.exception.status_code, 403)

    def test_rejects_tampered_signature(self):
        attacker_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        now = int(time.time())
        forged = jwt.encode(
            {"iss": ISSUER, "sub": "user_synthetic", "sid": "sess_synthetic",
             "iat": now, "nbf": now, "exp": now + 60,
             "azp": "https://oralyn.example"},
            attacker_key,
            algorithm="RS256",
            headers={"kid": "test-key"},
        )
        with self.assertRaises(HTTPException) as error:
            self.verifier.verify(forged)
        self.assertEqual(error.exception.status_code, 401)


class ClerkApiIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_signed_session_reaches_predict_and_invalid_session_does_not(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        jwk = jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key(), as_dict=True)
        jwk["kid"] = "integration-key"
        verifier = ClerkTokenVerifier(ISSUER)
        verifier.jwks.fetch_data = lambda: {"keys": [jwk]}
        now = int(time.time())
        token = jwt.encode(
            {"iss": ISSUER, "sub": "user_synthetic", "sid": "sess_synthetic",
             "iat": now, "nbf": now, "exp": now + 60},
            key, algorithm="RS256", headers={"kid": "integration-key"},
        )

        class SyntheticScreening:
            calls = 0

            def screen(self, image):
                self.calls += 1
                return {"synthetic": True}

        screening = SyntheticScreening()
        app = create_app(
            Settings(api_key="", model_dir=Path("unused")),
            screening_service=screening,
            token_verifier=verifier,
        )
        image = io.BytesIO()
        Image.new("RGB", (16, 16), (100, 80, 70)).save(image, "PNG")
        files = {"image": ("synthetic.png", image.getvalue(), "image/png")}
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://testserver"
        ) as client:
            valid = await client.post(
                "/predict", headers={"authorization": f"Bearer {token}"}, files=files
            )
            invalid = await client.post(
                "/predict", headers={"authorization": "Bearer forged"}, files=files
            )
        self.assertEqual(valid.status_code, 200)
        self.assertEqual(valid.json(), {"synthetic": True})
        self.assertEqual(invalid.status_code, 401)
        self.assertEqual(screening.calls, 1)


if __name__ == "__main__":
    unittest.main()
