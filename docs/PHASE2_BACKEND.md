# Phase 2 — FastAPI security and modularization

## Baseline and scope

Started from clean commit `5eb7e2b` on the development branch. Before changes, the existing real-checkpoint backend smoke test passed and all 11 Flutter tests passed. The tracked `.backend-work/main.py` matched the older external runtime copy at baseline. The FastAPI source is now the tracked `.backend-work/` tree; `Start-Oralyn-Server.ps1` uses it while retaining the external Python environment, private `.env`, model files, and tunnel executable. The external legacy `main.py` was not modified. No model weight, class order, preprocessing, status rule, clinical guidance, database, or Flutter code changed in this phase. Implementation was committed in focused configuration, schema, inference, Grad-CAM, orchestration, upload, route, test, launcher, and documentation groups.

## Changes and reasons

| Files | Change | Security or maintenance benefit | Compatibility and risk |
|---|---|---|---|
| `app/api/upload.py` | Cap the complete multipart request at image limit plus 64 KB overhead, read at most 10 MB + 1 byte of the image, inspect decoded dimensions, and fully decode before inference | Bounds request memory and decoded-image resources; rejects malformed payloads | Images over 10 MB or 4 million decoded pixels now return 413. The Flutter picker caps each side at 1600 px. The bounded request replay may hold up to about 10 MB in memory in addition to Starlette's upload handling. |
| `app/api/routes.py` | Keep HTTP validation, key check, health and error mapping at the route boundary; run synchronous inference in a worker thread | Event loop remains responsive; internal exception messages do not reach clients or logs | Inference failure now returns a generic 503; successful `/predict` JSON is unchanged. Worker concurrency still needs deployment limits. |
| `app/services/screening.py` | Keep the explicit primary → optional Grad-CAM → conditional secondary chain and status mapping | One coherent place for business behavior; Grad-CAM failure leaves prediction available | Primary Normal/Variation still bypasses secondary verification. This is unchanged and requires clinical evaluation. |
| `app/ai/models.py`, `app/ai/gradcam.py` | Load both checkpoints once at startup, preserve 224×224 preprocessing and checkpoint class order, use restricted `weights_only=True` loading, and share a lock across primary inference and Grad-CAM hook access | Reduces unsafe pickle deserialization and hook-state races | Current checkpoints were verified with `weights_only=True`; a future checkpoint with other object types may require a reviewed migration. One worker per process loads its own model copies. |
| `app/core/config.py`, `app/main.py`, `main.py` | Centralize server-only settings, create the application with a lifespan readiness gate, and retain `uvicorn main:app` | Paths and secrets are explicit; failed model initialization prevents a false healthy state | Missing key or checkpoints now fail startup. `/health` returns 503 if screening service is unavailable. |
| `app/schemas/prediction.py` | Record the existing response shape as a typed contract | Makes the boundary easier to inspect and evolve | Runtime validation is supplied by API tests, not a new response serializer, to avoid changing JSON. |
| `Start-Oralyn-Server.ps1`, `README.md` | Launch tracked source with external secret and model paths; document setup and limits | Removes divergence between repo and launched code | The local launcher still assumes the existing `D:\oralyn-backend` runtime layout. |
| `tests/test_api_contract.py`, smoke/integration scripts, `requirements-dev.txt` | Test synthetic uploads and fake inference, plus real checkpoints and local Uvicorn | Detects contract, security and chaining regressions without patient images | Real-checkpoint tests require model files; API tests do not. |

The public success response still includes `primary_prediction`, `primary_score`, `primary_predictions`, `cancer_verification`, `gradcam`, `screening_status`, `model`, and `disclaimer`. The multipart field is `image`; the prototype header is `x-api-key`. Model names, screening status strings, explanation label and disclaimer remain unchanged. CORS remains limited to the local web preview origin.

## Verification

| Check | Result |
|---|---|
| FastAPI API contract suite with synthetic images and fake inference | 15 passed: exact response, all decision branches, auth, malformed/truncated/MIME errors, 10 MB boundary, streamed total-body cap, decoded pixel cap, Grad-CAM fallback, generic inference error, and startup/health failures |
| Real-checkpoint in-process API smoke | Passed: generated image, real primary inference and Grad-CAM, conditional verification consistency, and prediction preserved after deliberate Grad-CAM failure |
| Local Uvicorn integration with real checkpoints | Passed: `/health` 200 and `/predict` 200 with real overlay through an actual local HTTP port |
| Flutter analyzer and tests | `flutter analyze --no-pub` found no issues; all 11 Flutter tests passed. No Flutter files changed. |
| Source and launcher syntax | All 18 backend Python files parsed; PowerShell launcher parsed with zero errors; `git diff --check` passed. |

One generated 256×256 in-process screening took 723 ms in a local run; this includes HTTP handling and overlay work. It is a diagnostic sample, not a throughput benchmark or clinical-performance result. No real patient image was used. The tunnel itself and an Android device were not exercised in this phase.

## Remaining security and Supabase gate

This backend is easier to extend, but **real patient-data integration is not ready**. The shared mobile API key remains extractable; authentication, per-case authorization, verified doctor access, private image storage, audit/retention rules, rate limiting, deployment request timeouts, and idempotent persistence are still required. Supabase schema and access-policy design can proceed against these boundaries, but no database connection or role interface should be enabled until those controls are implemented and tested. The primary-model false-negative pathway and full chained-model clinical performance remain unvalidated.

If an operational regression appears, revert the Phase 2 commits and restore the previous launcher behavior from baseline `5eb7e2b`; the external checkpoints and legacy runtime copy are untouched. Review any future change to the 4 million-pixel limit against mobile picker behavior and measured memory use.
