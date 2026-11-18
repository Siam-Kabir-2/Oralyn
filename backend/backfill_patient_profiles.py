"""Backfill disposable development Patient profiles from Clerk.

Dry run by default. Never prints names, emails, user IDs or keys.
"""

import argparse
import asyncio
import os
from urllib.parse import urlparse

from app.core.config import Settings
from app.persistence.supabase import SupabaseRepository
from app.services.clerk_profile import ClerkProfileClient, ClerkProfileUnavailable


DEV_PROJECT_REF = "arokswvcjddbzwthtqkh"


async def run(apply: bool) -> None:
    settings = Settings.from_environment()
    host = urlparse(settings.supabase_url).hostname
    if host != f"{DEV_PROJECT_REF}.supabase.co":
        raise RuntimeError("Refusing to access a project other than Oralyn development")
    if apply and not settings.clerk_secret_key.startswith("sk_test_"):
        raise RuntimeError("A Clerk development secret key is required")

    repository = SupabaseRepository(settings)
    directory = ClerkProfileClient(settings.clerk_secret_key) if apply else None
    try:
        offset = 0
        synced = 0
        skipped = 0
        while True:
            ids = await repository.patient_ids_for_sync(limit=100, offset=offset)
            if not ids:
                break
            if directory is not None:
                for user_id in ids:
                    try:
                        fields = await directory.patient_identity(user_id)
                    except ClerkProfileUnavailable:
                        skipped += 1
                        continue
                    await repository.sync_patient_profile(user_id, fields)
                    synced += 1
            offset += len(ids)
            if len(ids) < 100:
                break
        if apply:
            print(f"Development Patient profiles synced: {synced}; unavailable: {skipped}")
        else:
            print(f"Dry run: {offset} development Patient profiles; no writes")
    finally:
        if directory is not None:
            await directory.close()
        await repository.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", required=True,
                        help="Backend environment file outside the repository")
    parser.add_argument("--apply", action="store_true",
                        help="Write only to the locked Oralyn development project")
    arguments = parser.parse_args()
    os.environ["ORALYN_ENV_FILE"] = arguments.env_file
    asyncio.run(run(arguments.apply))
