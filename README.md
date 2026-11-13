# Oralyn

Oralyn is a Flutter app and FastAPI service for AI-assisted oral image screening. It supports Clerk sign-in, private screening history, Patient review requests, and a verified Doctor case workflow backed by Supabase. Screening output is guidance for follow-up, not a diagnosis. Nearby-care listings remain demonstration data.

## Repository

| Path | Purpose |
| --- | --- |
| `lib/`, `test/`, `android/` | Flutter app and tests |
| `backend/` | FastAPI application, dependency lists, and backend tests |
| `supabase/migrations/`, `supabase/tests/` | Versioned database SQL and authorization checks |
| `docs/` | Architecture, security notes, and manual verification |
| `Start-Oralyn-Server.ps1` | Windows development launcher for FastAPI and a Cloudflare Quick Tunnel |

The complete FastAPI **source** is in this repository under `backend/`. The separate `D:\oralyn-backend` directory used on the development workstation is a private runtime: it contains a Python virtual environment, model checkpoints, a local `.env`, and `cloudflared.exe`. Its older `main.py` is not the application launched by this repository. Do not commit the runtime directory, credentials, checkpoints, or patient images.

## Local requirements

- Flutter 3.47.5 and Dart 3.13.4 were used for the current app build.
- An Android SDK and JDK 17 are needed for Android builds.
- Python 3.13 was used for backend verification; install dependencies from `backend/requirements.txt`.
- The two existing ResNet50 checkpoints must be present in the private model directory as `resnet50_smartom_best.pth` and `resnet50_bmiocd_binary_best.pth`.
- Use the existing Clerk and Supabase development projects for live testing.

The Windows launcher expects the private runtime at `D:\oralyn-backend` by default. Pass `-RuntimeRoot` to use another location. It expects `<RuntimeRoot>\.venv\Scripts\python.exe`, `<RuntimeRoot>\models\`, `<RuntimeRoot>\.env`, and `<RuntimeRoot>\cloudflared.exe`.

Place backend configuration in the private `.env`:

```dotenv
SUPABASE_URL=https://YOUR-DEVELOPMENT-PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
SUPABASE_SECRET_KEY=YOUR_SERVER_SECRET_KEY
SUPABASE_STORAGE_BUCKET=screening-images
```

`CLERK_ISSUER` is required for direct backend launches. The Windows launcher supplies the public issuer of the existing development instance if it is unset. `CLERK_AUTHORIZED_PARTIES` and `CLERK_AUDIENCE` are optional claim restrictions. Never put server secrets in Flutter or `--dart-define`.

## Start FastAPI

From the repository root in PowerShell:

```powershell
.\Start-Oralyn-Server.ps1 -RuntimeRoot 'D:\oralyn-backend'
```

The launcher runs the tracked `backend/main.py` application on `http://127.0.0.1:8000`, waits for both models, then starts a Cloudflare Quick Tunnel. Confirm `/health` returns `{"status":"healthy"}`. Keep the launcher running while testing; a new Quick Tunnel usually gets a new HTTPS URL.

On the phone, open **Profile → Screening server** and enter the current `https://...trycloudflare.com` origin. The app appends `/predict`. The account-profile error screen also has a **Screening server** button. A saved URL on the phone can outlive the tunnel, so update it after a tunnel restart.

The API accepts a multipart `image` at `POST /predict` with a short-lived Clerk bearer token. The established response fields, model class mapping, conditional second-model inference, and Grad-CAM behavior are retained. Uploads are limited to 10 MB of image data and 4 million decoded pixels. `/docs` serves the local API documentation.

## Run the Flutter app

From the repository root, with an Android device connected:

```powershell
flutter pub get
flutter devices
flutter run --dart-define=ORALYN_API_BASE_URL=https://YOUR-CURRENT-TUNNEL.trycloudflare.com
```

The existing Clerk development publishable key is the app default. For another Clerk application, supply the **public** key with `--dart-define=CLERK_PUBLISHABLE_KEY=...`. Do not supply a Clerk secret key.

On the development workstation, the repository path contains a space. Flutter's native-asset tooling has required the space-free `O:\` alias; run Flutter from `O:\` if the build fails because of the path. The local Flutter SDK is in ignored `.tooling/flutter/`. See [the manual testing guide](docs/PHASE4_MANUAL_TESTING.md) for device setup, synthetic accounts, Doctor verification, and the complete Patient-to-Doctor test sequence.

## Verification

```powershell
flutter analyze
flutter test

Push-Location .\backend
& 'D:\oralyn-backend\.venv\Scripts\python.exe' -m unittest discover -s tests -v
$env:ORALYN_MODEL_DIR = 'D:\oralyn-backend\models'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' .\backend_gradcam_smoke_test.py
Pop-Location
```

The backend tests use synthetic images and mocked inference. The checkpoint smoke test needs the private model files. The database pgtap suite is in `supabase/tests/`; run it only against an authorized development project. The current development project passed all 26 Phase 3C SQL assertions. The full Android Patient-to-Doctor workflow still requires manual verification.

Build an Android APK with `flutter build apk --release`; Flutter writes it to `build/app/outputs/flutter-apk/app-release.apk`. The current development release uses an Android debug signing certificate and is not suitable for production distribution.

For architecture and security context, see [the design](docs/ARCHITECTURE_DESIGN.md), [backend report](docs/PHASE2_BACKEND.md), and [manual testing guide](docs/PHASE4_MANUAL_TESTING.md).
