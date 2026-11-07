# Oralyn

Flutter mobile app for camera-assisted oral screening, prevention guidance,
referral support, and nearby care discovery.

The camera and gallery use the phone's native photo picker, and the captured
photo is previewed throughout the screening flow. When screening starts, the
photo is uploaded to the configured FastAPI prediction service. Authentication
uses the existing Clerk development application; location, doctor search, and
saved history still use local prototype data.

## Prediction API configuration

The app includes a development Cloudflare Quick Tunnel URL. The base URL can be
changed on the phone from **Profile → Screening server**. If a screening
request fails, the error screen also provides **Update Server URL**.

The existing Clerk development publishable key is public and included as a
default. Override it for another Clerk instance at build or run time:

```powershell
.\.tooling\flutter\bin\flutter.bat run `
  --dart-define=CLERK_PUBLISHABLE_KEY=<publishable-key>
```

You can still override the initial default URL at build time:

```powershell
.\.tooling\flutter\bin\flutter.bat run `
  --dart-define=ORALYN_API_BASE_URL=https://new-host.example
```

The current default endpoint is
`https://manufacturing-yea-guild-roommates.trycloudflare.com/predict`. The app
sends a multipart `POST` using the `image` field and a short-lived Clerk
session token in the `Authorization: Bearer` header. The legacy shared mobile
API key is no longer accepted by `/predict`.

FastAPI exposes interactive Swagger documentation at `/docs`; documentation
URLs such as `/docs/predict` are not API routes. The in-app URL editor corrects
those pasted documentation URLs to `/predict` automatically.

Cloudflare Quick Tunnel URLs can change when `cloudflared` restarts. Use a named
tunnel with a stable hostname for distributed builds.

## Start the backend and tunnel

The FastAPI source is tracked in `.backend-work/`. The local Python environment,
model checkpoints, `.env`, and `cloudflared.exe` remain outside Git in
`D:\oralyn-backend`. The launcher runs the tracked source and points it to those
private runtime files:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Oralyn-Server.ps1
```

Wait for Cloudflare to print its `https://...trycloudflare.com` URL. Keep that
terminal open, then open **Profile → Screening server** in Oralyn and paste the
URL. The app automatically adds `/predict`. Closing the terminal stops the
backend/tunnel, and restarting a Quick Tunnel produces a new URL.

The backend loads both checkpoints once at startup. `/health` reports healthy
only when screening models are ready. `/predict` retains its multipart `image`
field, response fields, class mapping, and conditional
second-model behavior. Uploads are limited to 10 MB of image data, with a 64 KB
multipart allowance and a 4 million decoded-pixel limit. The mobile picker
resizes images to at most 1600 px on either side.

Backend checks use generated images; no patient images are included:

```powershell
cd .backend-work
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
$env:ORALYN_MODEL_DIR = 'D:\oralyn-backend\models'
python backend_gradcam_smoke_test.py
# With CLERK_ISSUER and ORALYN_TEST_SESSION_TOKEN set privately:
python backend_live_integration_test.py
```

The real-checkpoint checks need the local model files; the contract tests do
not. The launcher sets `CLERK_ISSUER` to the existing development issuer;
deployments can set `CLERK_AUTHORIZED_PARTIES` and `CLERK_AUDIENCE` to restrict
token claims. The live integration script requires `ORALYN_TEST_SESSION_TOKEN`
from a signed-in test account. See the [Phase 3A report](docs/PHASE3A_AUTH.md)
before using real patient records.

## Lightweight development

The project includes a local Flutter SDK in `.tooling/` (ignored by Git). Android
Studio and an emulator are not required; a physical Android phone can be used.

```powershell
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat run
```

Use `.\.tooling\flutter\bin\flutter.bat run` with a configured physical Android
device when the Android command-line SDK is available.

Static verification:

```powershell
.\.tooling\flutter\bin\flutter.bat analyze
.\.tooling\flutter\bin\flutter.bat test
```

Mock doctors, facilities, screening history, and result scenarios are configured
in `lib/data/mock/mock_data.dart`.

Build an installable Android APK:

```powershell
.\.tooling\flutter\bin\flutter.bat build apk --release
```

The generated file is `build/app/outputs/flutter-apk/app-release.apk`.
