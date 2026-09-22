# Oralyn

Flutter mobile prototype for camera-assisted oral screening, explainable sample
results, prevention guidance, referral support, and nearby care discovery.

The camera and gallery use the phone's native photo picker, and the captured
photo is previewed throughout the screening flow. The photo remains in memory
for the current session and is not uploaded. AI analysis, authentication,
location, doctor search, and saved history still use deterministic local sample
data and are clearly labelled as prototype behavior.

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
