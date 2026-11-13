"""Server-only configuration. No secret is embedded in the mobile client here."""

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


BACKEND_ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Settings:
    model_dir: Path
    clerk_issuer: str = ""
    clerk_authorized_parties: tuple[str, ...] = ()
    clerk_audience: str | None = None
    supabase_url: str = ""
    supabase_publishable_key: str = ""
    supabase_secret_key: str = ""
    supabase_storage_bucket: str = "screening-images"
    supabase_timeout_seconds: float = 15.0
    max_image_bytes: int = 10 * 1024 * 1024
    # Flutter's picker caps each side at 1600 px; allow larger API clients
    # while bounding the original-size Grad-CAM overlay allocations.
    max_image_pixels: int = 4_000_000
    max_request_overhead: int = 64 * 1024

    @property
    def max_request_bytes(self) -> int:
        return self.max_image_bytes + self.max_request_overhead

    @classmethod
    def from_environment(cls) -> "Settings":
        env_file = os.getenv("ORALYN_ENV_FILE")
        load_dotenv(env_file if env_file else BACKEND_ROOT / ".env")
        model_dir = Path(os.getenv("ORALYN_MODEL_DIR", BACKEND_ROOT / "models"))
        return cls(
            model_dir=model_dir.resolve(),
            clerk_issuer=os.getenv("CLERK_ISSUER", "").rstrip("/"),
            clerk_authorized_parties=tuple(
                party.strip()
                for party in os.getenv("CLERK_AUTHORIZED_PARTIES", "").split(",")
                if party.strip()
            ),
            clerk_audience=os.getenv("CLERK_AUDIENCE") or None,
            supabase_url=os.getenv("SUPABASE_URL", "").rstrip("/"),
            supabase_publishable_key=os.getenv(
                "SUPABASE_PUBLISHABLE_KEY", ""
            ),
            supabase_secret_key=os.getenv("SUPABASE_SECRET_KEY", ""),
            supabase_storage_bucket=os.getenv(
                "SUPABASE_STORAGE_BUCKET", "screening-images"
            ),
        )

    @property
    def persistence_configured(self) -> bool:
        return bool(
            self.supabase_url
            and self.supabase_publishable_key
            and self.supabase_secret_key
        )
