# Phase 3A authentication integration

Status: core email authentication is implemented and verified with the existing
Clerk development application. Google sign-in remains a separate native OAuth
configuration task. No patient records or Supabase integration were added.

## Compatibility and existing application

- Baseline: the completed Phase 2 backend integration, with a clean working tree.
- Local Flutter 3.47.5 and Dart 3.13.4 meet `clerk_flutter` 0.0.18-beta's
  Flutter 3.27.4 and Dart 3.6.2 minimums. The package is community maintained,
  beta, and supports Android/iOS/macOS; it does not support the available
  Windows/Chrome development targets for live authentication.
- The existing Clerk development instance at
  `https://balanced-mammal-1206.clerk.accounts.dev` is used. Its public
  publishable key is the Flutter default; no secret key is in source.
- Dashboard email/password sign-up and sign-in, email-code verification,
  password reset, device trust, and Google social connection are enabled.
  The dashboard minimum password length is 15 characters. No new Clerk
  application was created.
- Google is deliberately absent from the mobile sign-in UI until a native
  external-browser redirect, deep-link handler, and Clerk redirect allowlist
  are configured and tested. The SDK's default social flow embeds a WebView;
  Google does not allow this authentication path.

## Changes and reasons

| Files | Change | Security benefit / risk |
| --- | --- | --- |
| `pubspec.yaml`, `pubspec.lock`, `lib/core/config/clerk_config.dart` | Pin Clerk Flutter 0.0.18-beta, add secure storage, and use the existing public instance key. | No backend secret in the client. Beta SDK can change; keep the exact pin. |
| `lib/services/clerk_secure_persistor.dart`, `lib/services/clerk_session_provider.dart`, `lib/main.dart` | Store Clerk's client/session cache in platform protected storage, restore it at startup, handle initialization errors, and fetch a fresh token for screening. | Replaces the SDK's default plaintext file persistence for auth values. Native secure-storage behavior still needs device testing. |
| `lib/views/screens/auth/auth_screens.dart`, `lib/core/routes/app_routes.dart`, `lib/views/screens/onboarding/onboarding_screens.dart`, `lib/views/screens/profile/profile_screens.dart`, `lib/views/screens/home/home_screen.dart`, `lib/core/theme/app_theme.dart` | Replace simulated credentials with Clerk panels, email-code verification and recovery; guard protected routes; restore navigation; sign out; display the real user's identity while keeping Oralyn's shell and colors. | A signed-in Clerk session with an unexpired session record is required for protected navigation. The pinned SDK's internal panel imports are a maintenance risk. Local mock history and doctor content remain demonstration data. |
| `android/app/src/main/AndroidManifest.xml` | Disable Android auto backup of app data. | Avoid restoring encrypted session values without the matching Android Keystore key. This also disables backup for other app data. |
| `lib/services/screening_api_service.dart`, `lib/core/config/api_config.dart` | Send `Authorization: Bearer` with a fresh session token; refuse an upload without one. | Removes the extractable shared mobile key from requests. Old APKs using `x-api-key` receive 401 and must be upgraded. |
| `.backend-work/app/core/auth.py`, `.backend-work/app/core/config.py`, `.backend-work/app/api/routes.py`, `.backend-work/app/main.py`, `.backend-work/requirements.txt` | Verify RS256 JWTs against the configured Clerk issuer's JWKS; require signature, issuer, `sub`, `sid`, `exp`, `iat`, and `nbf`; optionally enforce audience and authorized party; put verified identity in `request.state`; require it for `/predict`. | Client-supplied IDs and roles are ignored. Invalid/expired tokens return 401, disallowed parties 403, and JWKS unavailability 503. A revoked session token may remain valid until its short expiry because this path does not call Clerk on every request. |
| `Start-Oralyn-Server.ps1`, `README.md`, backend smoke scripts, tests | Set the public development issuer in the local launcher, update instructions, and use bearer tokens in synthetic tests. | Keeps private runtime files outside Git. Real-token Uvicorn integration awaits a signed-in test account token. |

The existing `/predict` multipart `image` field, successful response JSON,
model checkpoint files, preprocessing, class mapping, conditional model chain,
Grad-CAM behavior, and screening guidance were not changed.

## Authentication architecture

The mobile Clerk SDK completes email registration, verification, sign-in,
recovery, session restoration, and sign-out. Its session cache uses
`flutter_secure_storage`. The screening service gets the current short-lived
session token just before each upload. FastAPI downloads signing keys from the
fixed HTTPS issuer, validates the JWT, and stores only verified `user_id` and
`session_id` in request context. No patient/doctor role is granted by the
client. Future doctor verification and case permissions require PostgreSQL
records and FastAPI checks before any real patient data is stored.

`CLERK_ISSUER` is required for a direct backend launch; the local launcher
sets the existing development issuer. `CLERK_AUTHORIZED_PARTIES` is an optional
comma-separated allowlist for `azp`. `CLERK_AUDIENCE` is optional if a token
template uses `aud`. The old `ORALYN_API_KEY` setting is no longer read by the
backend and grants no access to `/predict`; rotate previously distributed
copies and remove it from private runtime files after upgrading old clients.

## Verification and limits

- Backend contract and JWT tests: 21 passed with synthetic images, generated
  RSA keys, valid/expired/tampered/wrong-issuer tokens, unauthorized requests,
  and mocked inference. The successful prediction contract remained intact.
- Real-checkpoint Grad-CAM smoke test: passed using a synthetic 256×256 image;
  conditional second-model behavior and the Grad-CAM fallback passed.
- Flutter analysis: no issues. Flutter test suite: 13 passed, including secure
  cache restoration/removal, bearer upload, and expired-session refusal.
- Android debug APK: built and installed on Samsung SM-M356B. On November 11,
  the app registered a synthetic `+clerk_test` account, completed email-code
  verification with Clerk's reserved test code, restored the signed-in session
  after force-stop/relaunch, signed out, signed back in with password and a
  device-trust email-code challenge, and completed password recovery with a
  new synthetic password. The protected home/profile screens appeared only
  after Clerk sign-in. The final APK restored the session after reinstall and
  showed the Clerk user's name in the home greeting. No personal inbox or
  patient image was used.
  One synthetic test user remains in the development Clerk instance for
  repeatable follow-up checks; local test passwords and session tokens were
  removed after testing.
- A separate real Clerk token from the same test account reached FastAPI's
  `/predict` ASGI endpoint with both real checkpoints and a synthetic image:
  200 with Grad-CAM. Forged and missing tokens returned 401. The same token
  reached a live local Uvicorn process: `/health` 200, `/predict` 200, real
  Grad-CAM available. The first live run hit the 35-second model-readiness
  deadline while Android compilation was active; after raising that test
  deadline to 90 seconds and removing build contention, the rerun passed.
  The phone-to-public-HTTPS deployment path still needs a network check.
- Google sign-in was not exercised because native external-browser redirect
  handling and the Clerk allowlist are not configured. The SDK's default
  embedded WebView path is excluded from this app.

Before Supabase, configure and verify the native Google redirect if desired;
add server-side patient/case and verified-doctor authorization, database row
policies, image retention and deletion rules, rate limiting, and a stable HTTPS
backend endpoint. Restrict authorized parties and audience where the deployed
Clerk token format supplies them. The existing AI screening is research
guidance and still needs clinical validation.
