# Oralyn

Flutter UI prototype for AI-assisted oral lesion screening, explainable results,
referral guidance, and nearby care discovery.

The application is frontend-only. AI analysis, authentication, location, camera,
doctor search, and saved history use deterministic local simulations.

## Lightweight development

The project includes a local Flutter SDK in `.tooling/` (ignored by Git). Android
Studio and an emulator are not required; a physical Android phone can be used.

```powershell
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat run -d chrome
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
