# Oralyn

Flutter mobile app for camera-assisted oral screening, prevention guidance,
referral support, and nearby care discovery.

The camera and gallery use the phone's native photo picker, and the captured
photo is previewed throughout the screening flow. When screening starts, the
photo is uploaded to the configured FastAPI prediction service. Authentication,
location, doctor search, and saved history still use local prototype data.

## Prediction API configuration

The app includes a development Cloudflare Quick Tunnel URL. The base URL can be
changed on the phone from **Profile → Screening server**. If a screening
request fails, the error screen also provides **Update Server URL**.

The API key is intentionally not stored in source control. Provide a
development key at build or run time:

```powershell
.\.tooling\flutter\bin\flutter.bat run `
  --dart-define=ORALYN_API_KEY=<development-key>
```

You can still override the initial default URL at build time:

```powershell
.\.tooling\flutter\bin\flutter.bat run `
  --dart-define=ORALYN_API_BASE_URL=https://new-host.example
```

The current default endpoint is
`https://manufacturing-yea-guild-roommates.trycloudflare.com/predict`. The app
sends a multipart `POST` using the `image` field and the `x-api-key` header. The
build-time key can still be extracted from the compiled APK, so a
user-authenticated proxy or short-lived client token should replace it before
production.

FastAPI exposes interactive Swagger documentation at `/docs`; documentation
URLs such as `/docs/predict` are not API routes. The in-app URL editor corrects
those pasted documentation URLs to `/predict` automatically.

Cloudflare Quick Tunnel URLs can change when `cloudflared` restarts. Use a named
tunnel with a stable hostname for distributed builds.

## Start the backend and tunnel

The backend and `cloudflared.exe` are stored in `D:\oralyn-backend`. Start both
with one command from this project:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Oralyn-Server.ps1
```

Wait for Cloudflare to print its `https://...trycloudflare.com` URL. Keep that
terminal open, then open **Profile → Screening server** in Oralyn and paste the
URL. The app automatically adds `/predict`. Closing the terminal stops the
backend/tunnel, and restarting a Quick Tunnel produces a new URL.

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
