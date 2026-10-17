# Oralyn System Project — Reconstructed Project Context

**Reconstruction date:** 29 October 2026 (Asia/Dhaka)  
**Workspace:** `D:\System Project`  
**Reconstruction baseline:** `main` at commit `24037b8`; recovered work was organized into later commits on 29 October 2026  
**Current app version in source:** `1.5.0+8`  
**Document purpose:** Recover the most complete, evidence-based context possible after the original project chat was lost.

> **Medical scope:** Oralyn is an AI-assisted research/prototype screening system. It is not a diagnostic system and must not be used to confirm or rule out disease, replace a clinical examination, or make emergency or treatment decisions.

---

## 1. Evidence and confidence rules

This document deliberately separates facts from inference and unknowns.

- **Verified** means the statement is supported by current source code, Git history, build artifacts, tests, or runtime logs found in the workspace.
- **Inferred** means the explanation is strongly suggested by the code or artifact sequence but was not recorded in a surviving design decision.
- **Unknown** means the available project files and referenced conversation do not establish the answer.

### Sources recovered

| Source | What it establishes | Limitations |
|---|---|---|
| Referenced ChatGPT conversation `Prepare Project Context Markdown` | The user asked for a full reconstruction after losing the earlier system-project chat. | The conversation contains only that request and a broken/self-referential assistant placeholder. It contains no recoverable project decisions or implementation history. |
| Git repository in `D:\System Project` | Nine original milestones from 28 September to 1 October 2026, followed by recovered API, UI, test, backend, prototype, screenshot, and documentation commits created on 29 October 2026. | The later work was initially found as one uncommitted working tree, so Git still cannot prove its original edit order or every original decision. |
| Current Flutter source | The present mobile app architecture, screens, API integration, data models, settings, and mock/live boundaries. | Source presence does not by itself prove production readiness or clinical validity. |
| `D:\oralyn-backend` and `.backend-work` | The FastAPI service, two PyTorch model files, Grad-CAM, requirements, local environment, and tunnel launcher. The copied `main.py` and `requirements.txt` match byte-for-byte between both locations. | Model training code, dataset documentation, evaluation results, and deployment history are absent. |
| APK files `Oralyn-v1.0.0.apk` through `Oralyn-v1.5.0.apk` | Multiple Android build milestones exist, with distinct timestamps, sizes, and hashes. | The source tree has no tag or manifest mapping each APK to a precise commit or feature set. File names alone are not enough to assign exact changes to each APK. |
| Tests and analysis run on 29 October 2026 | Eight Flutter tests passed; `flutter analyze --no-pub` reported no issues. | These are unit/widget checks, not clinical validation, penetration testing, device-matrix testing, or full end-to-end production testing. |
| Server logs | Local and tunneled health checks and prediction requests previously returned successful responses; expected 400/401/422 cases also occurred. | Logs do not prove current tunnel availability or ongoing uptime. |
| Static web prototype | A visual reference for home, capture, analysis, result, history, care, and profile screens. | It is a local HTML/CSS/JS prototype, not a functional web application or backend client. |

### Important recovery conclusion

**Verified:** The lost prior discussion itself could not be recovered from the referenced conversation. This document reconstructs the project from the surviving repository and artifacts. No missing decision has been invented.

---

## 2. Executive summary

Oralyn is a Flutter-based Android application intended to guide a user through photographing a visible oral concern, submit that image to an AI-assisted screening service, present careful and explainable screening guidance, and direct the user toward appropriate professional care.

The project evolved in two clear phases:

1. **Committed UI prototype:** onboarding, simulated authentication, home navigation, real camera/gallery image selection, a lightweight photo-quality flow, deterministic mock screening results, education, mock history, mock doctors/clinics, referral guidance, and profile/privacy screens.
2. **Recovered live-inference integration:** the selected photo is uploaded to a FastAPI service through an HTTPS Cloudflare tunnel. A primary four-class ResNet50 produces the screening class and scores. A second binary ResNet50 runs only for higher-concern primary classes. Grad-CAM can return an attention overlay. The Flutter result screen maps this response into non-diagnostic guidance.

The current source is internally analyzable and its eight tests pass. It is still a prototype/research system, not production or clinical software. Authentication, user accounts, saved history, location, providers, maps, notifications, sharing, and deletion remain simulated or non-functional. The backend uses an ephemeral Quick Tunnel. A shared API credential was found in the pending mobile source during reconstruction and was removed before committing; build-time client credentials are still extractable and are not a production authentication design.

---

## 3. Project goals, scope, and non-goals

### 3.1 Verified product goals

The surviving implementation supports these goals:

1. Make capturing or selecting an oral photo simple and guided.
2. Warn users when the file may be too small and provide capture-quality guidance.
3. Run AI-assisted visible-pattern screening on the selected photo.
4. Express results as care guidance rather than a diagnosis.
5. Show model confidence/score information and, when available, a Grad-CAM attention overlay.
6. Add a conditional second-model verification signal for OPMD or oral-cancer primary classifications.
7. Make professional next steps prominent, including referral and nearby-care experiences.
8. Preserve an explicit medical disclaimer throughout the result journey.
9. Provide education about self-checks, prevention, warning signs, and when to seek care.

### 3.2 Current classification and guidance scope

The Flutter client accepts four primary model class names:

| API class | User-facing interpretation | Base guidance mapping |
|---|---|---|
| `Normal` | Healthy pattern | Low concern; continue routine care and monitor changes. |
| `Variation_from_Normal` | Benign/variation pattern | Professional review is recommended if the area persists or changes. |
| `OPMD` | OPMD-related pattern | Professional or prompt specialist review, depending on the second model. |
| `Oral_Cancer` | Pattern requiring specialist review | Professional or prompt specialist review, depending on the second model. |

`OPMD` is used by the code as a model class name. The source does not define or clinically document the label beyond presenting it as an OPMD-related pattern.

### 3.3 Explicit non-goals in the current system

- It does not provide a clinical diagnosis.
- It does not confirm or rule out cancer.
- It does not replace a dentist, oral medicine specialist, biopsy, pathology, or emergency care.
- It does not yet provide real authentication or account security.
- It does not yet persist genuine screening history.
- It does not yet provide verified real-world doctors, clinics, distances, availability, calls, or directions.

### 3.4 Unknown product decisions

The surviving files do not establish:

- the intended target users, countries, languages, age groups, or clinical settings;
- whether Oralyn is intended for research, a student project, a consumer product, or a regulated clinical workflow;
- the business model, owner, sponsor, or deployment budget;
- the required regulatory pathway or data residency rules;
- the formal clinical escalation protocol;
- an agreed production launch date or acceptance criteria.

---

## 4. Current implementation status at a glance

| Area | Status | Verified behavior |
|---|---|---|
| Splash and onboarding | Implemented | Opens with Oralyn branding and onboarding guidance. |
| Login, registration, password recovery | UI prototype only | Inputs and navigation exist; credentials are not transmitted; recovery email is simulated. |
| Home and bottom navigation | Implemented UI | Home, History, Care, Profile, and central screening action are available. |
| Camera and gallery | Implemented | Uses `image_picker`, rear camera preference, max 1600×1600, JPEG quality 88, and Android lost-data recovery. |
| Photo preview | Implemented | Selected bytes are previewed and carried through the current flow in memory. |
| Photo-quality check | Prototype only | Three animated checks are shown. The only implemented warning heuristic is file size below 45,000 bytes; lighting and framing are not actually analyzed. |
| Live AI request | Implemented | Multipart HTTPS `POST` sends the image to `/predict` with `x-api-key`. |
| Primary model | Implemented in backend | ResNet50 four-class inference on CPU. |
| Conditional verification model | Implemented in backend | Binary ResNet50 runs only when primary prediction is `OPMD` or `Oral_Cancer`. |
| Grad-CAM | Implemented with fallback | Primary-model attention overlay is returned as a base64 JPEG when generation succeeds; prediction still succeeds if Grad-CAM fails. |
| Result explanation | Implemented | Status, summary, recommendation, scores, model names, verification signal, overlay, and disclaimer are rendered. |
| Save result | Simulated | Button only shows a success snackbar; it does not persist the result. |
| Share result | Not implemented | Share icon has an empty callback. |
| Screening history | Mock data | Bundled deterministic records are displayed; new results are not added. |
| Doctor/clinic search and referral | Mock data | Fictional providers and distances are shown. |
| Map and location | Mock/prototype | No real map or geolocation integration. |
| Profile and personal data | Mock data | Demo identity is hard-coded; editing/password changes are simulated. |
| Delete history | Simulated | Confirmation and snackbar exist; bundled records are unchanged. |
| API server URL setting | Implemented | HTTPS endpoint is validated, normalized, and stored with `shared_preferences`. |
| Notifications and language | Simulated | UI messages only; English is the only shown language. |
| Education | Implemented static content | Self-check, prevention, and urgent-care guidance screens exist. |
| Web application | Not implemented | Only a static visual prototype exists. |
| Android build artifacts | Available | APKs from `v1.0.0` through `v1.5.0` are present. |

---

## 5. User journey

### 5.1 Entry and account flow

1. `main.dart` starts `OralynApp` with the light theme and `/` splash route.
2. Splash advances to onboarding.
3. Onboarding advances to login.
4. Login, registration, and password recovery simulate successful account actions and navigate locally.
5. The main shell displays Home, History, Care, Profile, and a prominent new-screening button.

### 5.2 Screening flow

1. **Preparation:** capture instructions and privacy/upload wording are shown.
2. **Capture:** the app automatically attempts to open the native rear-camera picker; the user may also choose a gallery image.
3. **In-memory photo object:** bytes, file name, camera/gallery origin, and a small-file warning are stored in `ScreeningPhoto`.
4. **Preview:** the user checks and accepts or retakes the image.
5. **Quality screen:** three staged UI checks are shown. A file under 45 KB triggers a warning, but the user may continue.
6. **Analysis:** the app requests the configured prediction endpoint and animates three stages: secure upload, two-stage review, and guidance preparation.
7. **Error recovery:** network/API errors offer Retry, Update Server URL, or Choose Another Photo.
8. **Result:** the API response is converted to `ScreeningResult` and displayed with status, scores, optional verification signal, optional Grad-CAM overlay, next steps, and disclaimer.
9. **Referral:** the user can enter a mock care-finding/referral flow.

### 5.3 What actually happens to the image

- **Verified client behavior:** the selected image bytes are held in the `ScreeningPhoto` object for the current navigation flow.
- **Verified client behavior:** when analysis starts, those bytes are uploaded to the configured HTTPS endpoint.
- **Verified backend behavior:** FastAPI reads the upload into memory, opens it with Pillow, preprocesses it, runs inference, and returns JSON. The source does not write the uploaded image to disk or a database.
- **Unknown operational behavior:** no formal retention policy exists for reverse-proxy infrastructure, server memory, crash dumps, access logs, backups, or a future hosted environment. Therefore the project cannot yet promise complete end-to-end deletion or zero retention.

---

## 6. System architecture

```text
Android user
   |
   v
Flutter mobile app
   |  capture/gallery -> in-memory ScreeningPhoto
   |  multipart HTTPS POST /predict
   |  header: x-api-key
   v
Cloudflare Quick Tunnel (development)
   |
   v
FastAPI + Uvicorn on 127.0.0.1:8000
   |
   +--> Validate API key, MIME type, image readability, and <=10 MB size
   |
   +--> Pillow RGB conversion + resize to 224x224 + ImageNet normalization
   |
   +--> Primary ResNet50 (four classes)
   |       |
   |       +--> Grad-CAM on final layer4 block (best-effort)
   |       |
   |       +--> If OPMD or Oral_Cancer:
   |               secondary ResNet50 binary verification
   |
   +--> JSON response with classes, scores, status, model names,
        optional verification, optional base64 attention image, disclaimer
   |
   v
Flutter response mapper -> ScreeningResult -> guidance/result UI
```

### 6.1 Flutter application structure

| Layer | Main files | Responsibility |
|---|---|---|
| Entry point | `lib/main.dart` | Creates `MaterialApp`, theme, routes, and initial splash. |
| Routing | `lib/core/routes/app_routes.dart` | Central named-route table and transitions. |
| Theme/design tokens | `lib/core/theme/` | Colors, spacing, and Material theme. |
| Constants/config | `lib/core/constants/`, `lib/core/config/` | App wording and default API endpoint/key configuration. |
| Models | `lib/models/` | Screening, photo/session, doctor, and clinic data structures. |
| Controllers | `lib/controllers/` | Lightweight orchestration for screening, history, and doctors. |
| Services | `lib/services/` | Live prediction API, persisted endpoint setting, and mock services. |
| Mock domain data | `lib/data/mock/mock_data.dart` | Deterministic result scenarios, providers, clinics, and history. |
| Screens | `lib/views/screens/` | Authentication, onboarding, home, screening, result, referral, care, history, education, profile, and server settings. |
| Shared widgets | `lib/views/widgets/common/app_components.dart` | Reusable buttons, headers, branding, placeholders, cards, and UI helpers. |

The project does not use a dedicated state-management package. `ScreeningController` extends `ChangeNotifier`, while other screens mostly hold local widget state and pass route arguments.

### 6.2 Backend structure

| Item | Location | Responsibility |
|---|---|---|
| FastAPI service | `D:\oralyn-backend\main.py` | Authentication, validation, preprocessing, inference, Grad-CAM, status mapping, and JSON response. |
| Workspace copy | `.backend-work/main.py` | Byte-identical recovered copy of the current backend source. |
| Python dependencies | `D:\oralyn-backend\requirements.txt` and `.backend-work/requirements.txt` | Backend package list; the two copies are byte-identical. |
| Primary checkpoint | `D:\oralyn-backend\models\resnet50_smartom_best.pth` | Four-class primary model; 94,387,731 bytes. |
| Verification checkpoint | `D:\oralyn-backend\models\resnet50_bmiocd_binary_best.pth` | Binary verification model; 94,373,431 bytes. |
| Environment | `D:\oralyn-backend\.env` | Holds backend secret configuration. Contents are intentionally not reproduced here. |
| Tunnel binary | `D:\oralyn-backend\cloudflared.exe` | Exposes the local Uvicorn server during development. |
| Launcher | `Start-Oralyn-Server.ps1` | Starts Uvicorn, waits for `/health`, starts Cloudflare, and stops Uvicorn when the launcher exits. |

The backend explicitly selects CPU inference with `torch.device("cpu")`.

### 6.3 Static web prototype

`oralyn-web-prototype/dist/` contains `index.html`, `styles.css`, `app.js`, and an SVG asset. It provides eight visual states: home, capture, analyzing, result, history, saved detail, care, and profile. Its JavaScript only switches screens, updates URL hashes, injects icons, and shows toast messages. It contains no API request or persistence logic.

**Inferred:** The visual prototype appears to be a design reference for the later Flutter home/navigation/result redesign because its information architecture and wording closely match current Flutter changes. No surviving document explicitly confirms that design handoff.

---

## 7. Technology stack

### 7.1 Mobile/client

| Technology | Verified use |
|---|---|
| Flutter / Dart | Cross-platform UI, with Android as the built and packaged target. Dart SDK constraint is `>=3.3.0 <4.0.0`. |
| Material Design | Theme, widgets, routing, forms, dialogs, navigation, and animations. |
| `image_picker ^1.2.3` | Native camera/gallery picker and Android lost-data recovery. |
| `http ^1.2.0` | HTTP client and multipart request. |
| `http_parser ^4.1.0` | Upload MIME type construction. |
| `shared_preferences ^2.3.0` | Persists the user-selected prediction URL. |
| Android Internet permission | Added for live API access. |
| Local Flutter SDK | `.tooling/flutter` supports development without requiring a global Flutter install. |

### 7.2 Backend/AI

| Technology | Verified use |
|---|---|
| Python | Backend runtime in `D:\oralyn-backend\.venv`. |
| FastAPI | `/`, `/health`, and `/predict` endpoints plus Swagger `/docs`. |
| Uvicorn | Local ASGI server on `127.0.0.1:8000`. |
| PyTorch / torchvision | ResNet50 model construction, checkpoint loading, transforms, softmax inference. |
| Pillow | Image decoding, RGB conversion, overlay resizing, and JPEG encoding. |
| NumPy | Grad-CAM and image-array processing. |
| `grad-cam 1.5.7` | Grad-CAM generation for the primary model. |
| `python-multipart` | FastAPI multipart upload handling. |
| `python-dotenv` | Loads `ORALYN_API_KEY` from the backend environment. |
| Cloudflare Quick Tunnel | Temporary public HTTPS access to the local backend. |

### 7.3 Model preprocessing and output

The current backend:

1. converts the image to RGB;
2. resizes it to 224×224;
3. converts it to a tensor;
4. normalizes channels with ImageNet means `[0.485, 0.456, 0.406]` and standard deviations `[0.229, 0.224, 0.225]`;
5. applies softmax and returns every class ordered by descending score.

**Unknown:** The repository has no training scripts, hyperparameters, dataset manifests, patient-level split method, augmentation record, performance metrics, calibration study, subgroup/fairness analysis, external validation, model card, or license/provenance documentation for either checkpoint.

---

## 8. Prediction API contract

### 8.1 Endpoints

| Method | Path | Authentication | Purpose |
|---|---|---|---|
| `GET` | `/` | None | Basic online/service/model response. |
| `GET` | `/health` | None | Returns `{"status":"healthy"}` after app/model startup. |
| `POST` | `/predict` | `x-api-key` | Validates and screens one uploaded image. |
| `GET` | `/docs` | None in current source | FastAPI interactive documentation. `/docs/predict` is not an API route. |

### 8.2 Request

- Content type: multipart form data.
- Image field name: `image`.
- Authentication header: `x-api-key`.
- Client-supported formats: JPG/JPEG, PNG, WEBP, and BMP, determined from name or magic bytes.
- Client and server maximum size: 10 MB.
- Client timeout: 45 seconds.

### 8.3 Response fields consumed by Flutter

```json
{
  "primary_prediction": "OPMD",
  "primary_score": 0.8234,
  "primary_predictions": [
    {"class": "OPMD", "score": 0.8234}
  ],
  "cancer_verification": {
    "performed": true,
    "prediction": "Cancer",
    "score": 0.71,
    "predictions": [
      {"class": "Cancer", "score": 0.71}
    ]
  },
  "gradcam": {
    "available": true,
    "label": "Area highlighted for review",
    "image_base64": "data:image/jpeg;base64,..."
  },
  "screening_status": "Prompt Specialist Review",
  "model": {
    "primary": "ResNet50 SMART-OM 4-class",
    "verification": "ResNet50 BMIOCD binary"
  },
  "disclaimer": "AI-assisted research screening only. This result is not a clinical diagnosis."
}
```

The example shows the schema, not an actual patient result.

### 8.4 Backend decision mapping

| Primary result | Secondary model run? | Screening status |
|---|---:|---|
| `Normal` | No | `Low Concern` |
| `Variation_from_Normal` | No | `Review Recommended` |
| `OPMD` or `Oral_Cancer` + verification `Cancer` | Yes | `Prompt Specialist Review` |
| `OPMD` or `Oral_Cancer` + any other accepted verification result | Yes | `Professional Review Recommended` |

### 8.5 Client error handling

The Flutter service maps errors into configuration, unauthorized, invalid-image, payload-too-large, rate-limited, timeout, network, server, or invalid-response categories. It presents plain-language messages and lets the user retry or update the endpoint.

The client also validates required JSON fields. Unknown class names/status values, malformed prediction lists, missing verification data, or invalid Grad-CAM data are treated as unreadable responses instead of silently producing a misleading result.

---

## 9. Configuration, privacy, and security

### 9.1 Prediction URL behavior

- A default base URL is compiled through `lib/core/config/api_config.dart`.
- It can be overridden at build time with `ORALYN_API_BASE_URL`.
- The user can update it from **Profile → Screening server**.
- The saved value uses `shared_preferences`.
- The settings service accepts HTTPS only, rejects credentials/query/fragment, removes trailing slashes, adds `/predict` to a bare host, and corrects `/docs` or `/docs/predict` to `/predict`.

### 9.2 Quick Tunnel limitation

The README and `ApiConfig` were aligned during reconstruction, but the configured `trycloudflare.com` address is still a Quick Tunnel address. It can change whenever the tunnel restarts, so it must not be treated as stable. The in-app setting is the development recovery mechanism.

### 9.3 API credential risk

The pending Flutter configuration originally included a shared API key in source. The actual value is intentionally omitted from this document, and the value was removed before the changes were committed. The client now reads `ORALYN_API_KEY` from a build-time Dart definition.

This is unsafe for production because any key embedded in an APK can be recovered. The README already acknowledges this. Before distributing beyond controlled testing:

1. rotate the previously exposed/shared key;
2. remove long-lived service credentials from the client;
3. introduce authenticated users or short-lived scoped client tokens through a trusted gateway;
4. add rate limiting, abuse controls, monitoring, and revocation.

### 9.4 CORS

The backend allows `http://127.0.0.1:8081` for a local Flutter Web preview, with `GET`, `POST`, and `OPTIONS` and the `Content-Type`/`x-api-key` headers. Native Android requests do not depend on browser CORS. Any real web deployment would need an explicit production origin policy.

### 9.5 Data persistence

| Data | Current persistence |
|---|---|
| Selected photo | Held in memory for the active Flutter flow; uploaded during analysis. |
| Prediction endpoint | Persisted locally through `shared_preferences`. |
| New screening result | Not persisted. Save is a visual simulation. |
| Screening history | Bundled mock records; resets with app data/build. |
| User identity | Hard-coded demo profile; no account database. |
| Credentials | Not transmitted by the current simulated authentication screens. |
| Backend uploaded image | Not written to storage by current `main.py`; broader infrastructure retention is undocumented. |

---

## 10. Implementation history reconstructed from Git

All timestamps below are from Git and use the original `+06:00` offset.

### 28 September 2026 — committed prototype foundation

1. **`3aceb69` — `chore: initialize Flutter platform project`**  
   Created Flutter/Android/Web scaffolding, project metadata, analysis settings, and initial package configuration.

2. **`c15f85a` — `feat: add theme and mock domain layer`**  
   Added theme tokens, domain models, controllers, deterministic mock results/providers/history, and mock AI/location/doctor services.  
   **Why, verified from structure:** establish a complete data and service boundary so the UI could be built without a live backend.

3. **`ef83247` — `feat: build shared UI and entry flows`**  
   Added shared components, splash/onboarding, authentication UI, home, and main shell.

4. **`4a89b4e` — `feat: implement screening and result journey`**  
   Added screening preparation/capture journey, result presentation, and referral screen using the prototype service/data.

5. **`09136eb` — `feat: add care history and profile experiences`**  
   Added routing, main entry point, doctors, education, history, and profile/privacy/about screens.

6. **`8f80547` — `test: document and verify the prototype`**  
   Added README instructions and an initial widget test.

### 1 October 2026 — committed camera and guidance improvements

7. **`8e132a5` — `feat(screening): capture and retain real photos`**  
   Added `image_picker`, Android camera workflow, in-memory `ScreeningPhoto`, route argument propagation, preview, and real selected-image display. At this committed stage, the image was explicitly not uploaded and analysis remained mock.

8. **`d85ea5f` — `feat(guidance): expand prevention and care recommendations`**  
   Expanded education and result guidance and added disclaimer-focused widget tests.

9. **`24037b8` — `docs: describe camera flow and Android build`**  
   Updated README with camera flow, local Flutter commands, verification commands, mock-data location, and release APK build instructions.

### 14–15 October 2026 — recovered integration/build period

The working tree and artifact timestamps showed substantial work after the last original commit. Because this work was found uncommitted, its original edit order is not fully recoverable. It was reviewed and organized into logical commits on 29 October 2026.

Verified changes include:

1. **Live API replaces mock analysis in the active screening path.**  
   `ScreeningController` now uses `ScreeningApiService` and accepts the selected `ScreeningPhoto`.  
   **Reason:** analyze the user-selected image instead of returning a deterministic sample.

2. **Multipart upload and strict response mapping were added.**  
   New HTTP dependencies, input validation, timeout/error categories, and JSON field checks connect Flutter to FastAPI safely enough for controlled development.  
   **Reason:** make transport failures understandable and prevent malformed backend responses from becoming misleading UI results.

3. **Configurable endpoint storage was added.**  
   `ApiSettingsService` and `ApiSettingsScreen` handle changing Quick Tunnel URLs.  
   **Reason, verified by README/launcher behavior:** Quick Tunnel hostnames change after restart, so the phone needs a runtime update path without rebuilding the APK.

4. **Android Internet permission was added.**  
   **Reason:** permit the app to call the remote prediction endpoint.

5. **The result model and UI were expanded.**  
   `ScreeningResult` now stores class score lists, model names, verification results, Grad-CAM data, and the API disclaimer. The result screen displays these with careful non-diagnostic wording.

6. **The backend gained two-stage inference and Grad-CAM.**  
   The primary model always runs; the binary model runs only for OPMD/oral-cancer primary outputs. Grad-CAM is best-effort and protected by a lock because its hook state is shared.  
   **Reason, inferred from code/UI:** provide an additional higher-concern signal while avoiding unnecessary second-model execution and give users a limited visual explanation.

7. **Backend resilience checks were added.**  
   A smoke test confirms invalid images return 400 and that forced Grad-CAM failure still returns a successful prediction with `available: false`. During reconstruction, its personal Downloads-file dependency was replaced with an in-memory generated test image, and the backend root became configurable through `ORALYN_BACKEND_ROOT`.

8. **The design system and major mobile screens were revised.**  
   Home, bottom navigation, onboarding, screening, result, theme colors, theme styles, branding, and shared components were substantially redesigned.  
   **Reason, inferred:** align the Flutter app with the recovered static product-design prototype and make the care journey more legible and polished.

9. **Environment-file patterns were added to `.gitignore`, and the pending hard-coded client key was removed before commit.**  
   **Reason:** reduce the chance of committing backend secrets.

10. **Multiple APKs were built.**  
    Artifacts labeled `v1.1.0` through `v1.5.0` were produced during this period. Exact feature-to-APK mapping is unknown because there are no matching Git tags or release notes.

---

## 11. Current repository and artifact state

### 11.1 Git state and recovered commits

The reconstruction began on `main` at `24037b8` with 19 modified tracked files and 11 untracked paths. The recovered work was reviewed and split into these commits:

| Commit | Purpose |
|---|---|
| `ecdb371` | Mobile screening API integration and configurable endpoint. |
| `8e4d10f` | Model signals, verification details, and attention-overlay result UI. |
| `a717626` | Visual system, onboarding, home, navigation, and shared UI refresh. |
| `cf32755` | API/settings, response mapping, authorization, onboarding, and disclaimer tests. |
| `58a2f28` | FastAPI two-stage inference service, Grad-CAM, smoke check, and launcher. |
| `06c921f` | Static mobile-experience web prototype. |
| `9221189` | Reviewed development/API screenshots. |
| Documentation commit | README, ignore rules, and this reconstructed context. |

Two safety/portability adjustments were made while preparing the commits: the hard-coded client API key was replaced with a build-time `ORALYN_API_KEY`, and the backend smoke test now generates its own image and accepts an `ORALYN_BACKEND_ROOT` override. No unrelated project behavior was changed.

At the time these commits were prepared, the repository had no configured Git remote. The commits therefore remain local until a repository URL is supplied.

### 11.2 APK inventory

Hashes are included so artifacts can be identified exactly. They do not establish which source revision produced each APK.

| File | Bytes | Modified (Asia/Dhaka) | SHA-256 |
|---|---:|---|---|
| `Oralyn-v1.0.0.apk` | 50,385,538 | 2026-10-01 06:55:38 | `B7FF1F9CF31DDA5EDBA411A84D39DB05457B23DCA9516DD7B6243BD4E9A73F43` |
| `Oralyn-v1.1.0.apk` | 52,247,147 | 2026-10-14 01:15:29 | `68299D8C362BC6E62DEEB2049EAD270C8718E9525995CBD1DDF35383789D9384` |
| `Oralyn-v1.1.1.apk` | 52,247,147 | 2026-10-14 02:01:12 | `1121E3F46B5CBB65542B89040071F6F4F9BA920F7F8A5A33834AD0C3DF69BF6A` |
| `Oralyn-v1.1.2.apk` | 52,247,151 | 2026-10-15 03:17:20 | `BCAC200960228678DFBD1311CBB4317A46D9F0ECD4AB3EF74F36828D8B7706F2` |
| `Oralyn-v1.2.0.apk` | 52,247,151 | 2026-10-15 06:26:27 | `68A21F3113BDD038C8E4530B8AEE608BA5D46CEE6D1E9142C1708FD1CAE7ACC8` |
| `Oralyn-v1.3.0.apk` | 52,329,219 | 2026-10-15 07:39:05 | `EB46BAA50541E7F6777D39E04830763DACA4E50ABE157E6B7E764520AB71C785` |
| `Oralyn-v1.4.0.apk` | 52,444,051 | 2026-10-15 08:52:29 | `CED05FDBBB581F9B3AC14163DF2C4FEED25FD33CEE99239892DCCDFA2BC1B4E6` |
| `Oralyn-v1.5.0.apk` | 52,329,071 | 2026-10-15 09:04:58 | `CDC2867F1487D53740B054F42E6DCBC161E1E2EB94B7CA7F355C502E5C4F0450` |

### 11.3 Recovered backend hashes

| File | SHA-256 |
|---|---|
| Current `main.py` in both locations | `B1F37EBF5215761BB695EC1F6B97E15183960566521A9DF547717FB6F2AFB78D` |
| Current `requirements.txt` in both locations | `C87FD0C9CCA5DCD2A7AF9C5CF683674703BB67B227333248E0E5B6C80A18B444` |
| Primary checkpoint | `6A649F91DD9C8EC5FB51BAC4358431BC02BBE09BCCF095EEA1DBEC3EE150510E` |
| Verification checkpoint | `99E774F47AE4DAB349E687626F0A8E66EF815EC03407646E40C4CD221BD0B0A9` |

---

## 12. Verification performed during reconstruction

### 12.1 Flutter tests — passed

Run on 29 October 2026 with existing local packages:

```powershell
.\.tooling\flutter\bin\flutter.bat test --no-pub
```

All eight tests passed:

1. bare Cloudflare URL receives `/predict`;
2. Swagger docs URL is corrected;
3. non-HTTPS URLs and query parameters are rejected;
4. image upload and successful higher-concern response mapping;
5. low-concern result without second-model verification;
6. unauthorized API key error handling;
7. app launches into onboarding;
8. medical disclaimer remains visible on the result screen.

### 12.2 Static analysis — passed

```powershell
.\.tooling\flutter\bin\flutter.bat analyze --no-pub
```

Result: **No issues found**.

### 12.3 Backend evidence

Recovered logs contain:

- repeated successful `/health` responses;
- multiple successful `/predict` responses;
- expected 400 invalid request, 401 unauthorized, and 422 validation responses;
- an earlier failed CORS preflight followed by successful `OPTIONS` and tunneled `POST` requests after CORS support was present.

The backend smoke-test source also checks invalid-image rejection and graceful Grad-CAM failure. It was made self-contained with a generated image during reconstruction but was not rerun because it loads the large local model checkpoints. The log and source evidence are recorded without claiming a fresh run.

### 12.4 What has not been verified

- a fresh release APK build from the current working tree;
- installation and full journey on a physical phone during this reconstruction;
- current Quick Tunnel availability;
- live inference against the current default URL;
- backend cold-start time, throughput, memory use, or concurrent load;
- any clinical performance, safety, fairness, or regulatory claims.

---

## 13. Known gaps, inconsistencies, and risks

### 13.1 Critical before external distribution

1. **Any build-time API key remains recoverable from the app.** The previously exposed key must be rotated, and production access needs a real client authentication/token design.
2. **Quick Tunnel is ephemeral.** Use a stable named tunnel or hosted service with a controlled domain and deployment process.
3. **Clinical evidence is absent.** No metrics, calibration, external validation, model card, or clinician-approved decision thresholds are in the repository.
4. **Privacy governance is absent.** There is no consent record, retention schedule, data-processing agreement, incident plan, or deletion verification.
5. **Medical wording requires expert review.** Current language is cautious, but a qualified clinician and relevant regulatory/privacy experts must approve it for the intended market.

### 13.2 Product gaps

- Authentication and password flows are simulations.
- Save, delete, notifications, profile edits, and sharing are simulations or no-ops.
- History does not receive the newly generated screening result.
- Providers, clinics, distances, hours, map, contact, and directions are mock data/UI.
- The result/share flow cannot generate a clinician-friendly report.
- Language/localization is not implemented.
- Accessibility has not been formally audited.

### 13.3 AI/backend gaps

- Training and evaluation provenance is missing.
- API key authentication alone is insufficient for user-level access control.
- No visible rate limiter, request quota, audit trail, structured monitoring, or alerting exists.
- No model version/checkpoint hash is returned in the API response.
- Backend file paths are relative to the working directory.
- CPU-only inference may have latency/capacity limits; no benchmark is recorded.
- The Grad-CAM overlay is explanatory support, not lesion segmentation, but users may still misinterpret it without usability testing.
- The smoke test defaults to the recovered Windows backend path, though `ORALYN_BACKEND_ROOT` can now override it.

### 13.4 Code/release gaps

- The recovered changes are committed locally but remain untagged and unpushed because no Git remote is configured.
- APKs have no matching Git tags, changelog, signing record, or reproducible-build record.
- README and source contain different default tunnel URLs.
- `pubspec.yaml` says `1.5.0+8`, but there is no Git release tag establishing that version.
- The older `MockAiService` and some legacy explainability wording remain in the tree even though the active flow uses the live service.
- There are unit/widget tests but no automated backend test suite, integration test that launches both services, or device end-to-end test.

---

## 14. Recommended remaining work

### Priority 0 — secure and preserve the current work

1. Rotate the previously exposed/shared API key.
2. Remove long-lived secrets from Flutter source and APK builds.
3. Fix the README/default-endpoint mismatch and document one supported configuration method.
4. Review the recovered commit series, configure the intended remote, push it, and tag the exact source used for the next APK.
5. Move the backend into a version-controlled repository or a clearly versioned subproject without committing `.env`, virtual environments, model secrets, or unnecessary binaries.
6. Add a changelog mapping app version, Git commit, backend version, and model checkpoint hashes.

### Priority 1 — establish clinical/research validity

1. Document both datasets/checkpoints, class definitions, licenses, consent, inclusion/exclusion criteria, and patient-level train/validation/test splits.
2. Record sensitivity, specificity, precision, recall, F1, AUROC, confusion matrices, calibration, confidence intervals, and subgroup performance.
3. Validate on an external dataset and in the intended capture conditions.
4. Have clinicians define safe referral thresholds and review every piece of result/guidance copy.
5. Write a model card and intended-use/contraindication statement.
6. Decide whether the system is a research demonstrator or a regulated medical product before changing claims or distribution.

### Priority 2 — production backend and privacy

1. Deploy to a stable managed environment with a controlled domain, TLS, backups, monitoring, and explicit data-region selection.
2. Add user/session authentication, short-lived tokens, rate limiting, abuse prevention, and key rotation.
3. Define image/result retention and deletion; minimize logs and verify that images are not unintentionally retained.
4. Add request IDs, model versions, structured logs, health/readiness checks, metrics, and alerting without logging sensitive images.
5. Containerize and pin dependency versions for reproducibility.
6. Add backend unit/API tests, malformed-image tests, concurrency tests, model-load tests, and Grad-CAM degradation tests using repository-owned fixtures.

### Priority 3 — complete the product

1. Implement real authentication and account recovery.
2. Persist results securely and encrypted; make Save, History, Delete, and Export truthful.
3. Implement report sharing with clear consent and redaction controls.
4. Integrate verified provider data, geolocation, maps, contact, and directions—or remove those claims until available.
5. Replace the file-size-only quality heuristic with real blur, exposure/glare, framing, and minimum-detail checks, clearly distinguishing technical quality from clinical suitability.
6. Add localization and a full accessibility audit.
7. Add offline/error-state handling and clear instructions when the screening service is unavailable.

### Priority 4 — testing and release discipline

1. Add end-to-end tests for capture → upload → response → result using a controlled test server.
2. Test supported Android versions, camera vendors, permissions, poor networks, timeouts, large files, rotation, process death, and accessibility settings.
3. Add CI for formatting, analysis, tests, backend checks, dependency scanning, and reproducible builds.
4. Create signed release procedures, artifact checksums, release notes, and rollback instructions.
5. Perform security/privacy review and usability testing, especially around risk wording and Grad-CAM interpretation.

---

## 15. How to run the recovered system

### 15.1 Start backend and development tunnel

Prerequisites already referenced by the launcher:

- `D:\oralyn-backend\.venv\Scripts\python.exe`
- `D:\oralyn-backend\cloudflared.exe`
- model checkpoints under `D:\oralyn-backend\models`
- `ORALYN_API_KEY` in the backend environment

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Oralyn-Server.ps1
```

Wait for Cloudflare to print an HTTPS URL, keep the terminal open, then enter that URL in **Profile → Screening server**. The app adds `/predict` when needed.

### 15.2 Run Flutter on a configured device

```powershell
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat run
```

Optional build-time endpoint override:

```powershell
.\.tooling\flutter\bin\flutter.bat run `
  --dart-define=ORALYN_API_BASE_URL=https://your-controlled-host.example `
  --dart-define=ORALYN_API_KEY=<development-key>
```

Do not put a long-lived production API secret in a `dart-define`; compiled client values remain extractable.

### 15.3 Verify Flutter

```powershell
.\.tooling\flutter\bin\flutter.bat analyze
.\.tooling\flutter\bin\flutter.bat test
```

If dependencies are already present and network access is unavailable, use `--no-pub` as used during this reconstruction.

### 15.4 Build Android APK

```powershell
.\.tooling\flutter\bin\flutter.bat build apk --release
```

Expected generated artifact:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Before distributing a new APK, first resolve the security and release-traceability items in this document.

---

## 16. Practical handoff checklist

Use this list when resuming work:

- [ ] Read this context file and the current `README.md`.
- [ ] Inspect `git status` before editing and keep the recovered commit series intact.
- [ ] Confirm which tunnel/host is currently active; do not trust either saved Quick Tunnel URL to remain live.
- [ ] Rotate the previously exposed shared API key before broader testing.
- [ ] Decide how the backend and large model files will be versioned and backed up.
- [ ] Create coherent commits for API integration, settings, backend, result UI, design refresh, tests, and documentation.
- [ ] Tag the exact source/backend/model combination used for each future APK.
- [ ] Keep every result screen explicit that scores are model similarity/confidence signals, not diagnostic probabilities.
- [ ] Do not claim clinical accuracy until the missing validation evidence exists.
- [ ] Replace simulated features or label them unmistakably as prototypes.

---

## 17. Final known/unknown boundary

### What is known

The project has a functional Flutter prototype, real photo capture, a current live-inference client path, a local two-model FastAPI backend, conditional verification, Grad-CAM, configurable tunnel URL, multiple APK builds, passing Flutter tests, and clean static analysis. The exact committed history up to 1 October 2026 is recoverable.

### What is not known

The lost design conversation, model training history, dataset governance, clinical metrics, intended regulatory status, exact feature mapping for APK versions after `v1.0.0`, and the rationale for every uncommitted visual edit are not recoverable from the available evidence.

### Safe conclusion

Oralyn is best described today as a **technically integrated, AI-assisted oral-screening research prototype with substantial mobile UX, but incomplete product services, security hardening, release traceability, and clinical validation**.
