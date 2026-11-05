"""Validate Clerk session JWTs before protected API work."""

from dataclasses import dataclass
from urllib.parse import urlparse

import jwt
from fastapi import HTTPException, Request
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientConnectionError


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: str
    session_id: str


class ClerkTokenVerifier:
    def __init__(
        self, issuer: str, authorized_parties: tuple[str, ...] = (),
        audience: str | None = None,
    ):
        parsed = urlparse(issuer)
        if (
            parsed.scheme != "https" or not parsed.hostname
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment
            or parsed.username or parsed.password
        ):
            raise ValueError("CLERK_ISSUER must be an HTTPS origin")
        self.issuer = issuer.rstrip("/")
        self.authorized_parties = authorized_parties
        self.audience = audience
        self.jwks = PyJWKClient(
            f"{self.issuer}/.well-known/jwks.json",
            cache_jwk_set=True,
            lifespan=300,
            timeout=5,
        )

    def verify(self, token: str) -> AuthenticatedUser:
        try:
            header = jwt.get_unverified_header(token)
            if header.get("alg") != "RS256" or not header.get("kid"):
                raise jwt.InvalidTokenError("Unsupported token header")
            key = self.jwks.get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token,
                key.key,
                algorithms=["RS256"],
                issuer=self.issuer,
                audience=self.audience,
                options={"require": ["iss", "sub", "sid", "exp", "iat", "nbf"]},
                leeway=5,
            )
        except PyJWKClientConnectionError:
            raise HTTPException(status_code=503, detail="Authentication unavailable") from None
        except (jwt.PyJWTError, ValueError):
            raise HTTPException(status_code=401, detail="Invalid or expired session") from None

        user_id, session_id = claims.get("sub"), claims.get("sid")
        if not isinstance(user_id, str) or not user_id.startswith("user_"):
            raise HTTPException(status_code=401, detail="Invalid session subject")
        if not isinstance(session_id, str) or not session_id.startswith("sess_"):
            raise HTTPException(status_code=401, detail="Invalid session identifier")
        party = claims.get("azp")
        if self.authorized_parties and party not in self.authorized_parties:
            raise HTTPException(status_code=403, detail="Session origin is not authorized")
        return AuthenticatedUser(user_id=user_id, session_id=session_id)


def authenticated_user(request: Request) -> AuthenticatedUser:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token or len(token) > 8192:
        raise HTTPException(
            status_code=401,
            detail="Bearer session token required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    verifier = request.app.state.token_verifier
    if verifier is None:
        raise HTTPException(status_code=503, detail="Authentication unavailable")
    identity = verifier.verify(token)
    request.state.identity = identity
    return identity
