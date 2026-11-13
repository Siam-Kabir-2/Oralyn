# Doctor onboarding implementation and verification

Branch: `feature/doctor-onboarding`. This work extends the Phase 4 Patient/Doctor review system. It does not change model checkpoints, preprocessing, prediction contract, clinical guidance or existing case authorization. No migration was applied remotely and no production data was used.

## Changes and reasons

| Area | Change | Reason and security effect |
| --- | --- | --- |
| Flutter entry | Patient, Doctor and Admin sign-in choices share the existing Clerk flow. Admin has no registration. | Role choice is navigation intent only; it grants no database permission. |
| Trusted routing | `GET /me` determines Patient, Doctor or Admin route. Doctor verification state determines dashboard, pending, rejected or suspended view. Refresh re-queries the server. | Protected workspace data is not shown while resolving role; unverified Doctors do not fetch cases. An Admin account sees only a minimal landing until Admin APIs exist. |
| Doctor application | Clerk-authenticated Patient submits professional details to `POST /doctor/applications`. A service-role-only database function creates a pending Doctor record. | No self-verification, client role field or public Admin assignment. Duplicate application is rejected. |
| Professional profile | `GET/PUT /doctor/profile` loads the authenticated Doctor's own record. The server validates editable fields. A changed verified profile returns to pending and clears approval metadata. | Doctors cannot edit role, approval state or assignments through this API. Existing RLS blocks pending/suspended case reads. |
| Verified directory | Patient Find Care fetches sanitized, verified professional profiles through authenticated `GET /doctors`. | The view does not use fabricated Doctor credentials or expose Clerk IDs, registration references or approval metadata. Referral/map demo data remains a separate prototype. |
| Communication UI | Saved screening details show a disabled “Request chat · Coming Soon” control. Doctor workspace links to a static Messages screen with a disabled composer. | Existing structured reviews remain real; no fake requests, approvals, messages or chat tables exist. |
| Database | New transaction-wrapped migration extends the Phase 3C schema with `admin`, `workplace` and service-role-only application/profile RPCs. | Preserves Phase 3C ownership, RLS and assignment policy. The migration must be reviewed and applied to the development project before new account flows are live. |

## API and database contracts

- `POST /doctor/applications`: Clerk bearer token and `display_name`, `registration_reference`, `qualification`, `specialization`, `workplace`; returns `201` and `{"verification_state":"pending"}`. Only an account currently resolved as Patient can apply.
- `GET /doctor/profile`: the current Doctor's own professional record; no arbitrary user ID parameter.
- `PUT /doctor/profile`: same editable fields; verified changes require re-verification. Rejected and suspended accounts cannot edit through this route.
- `GET /doctors`: verified records only; returns `items` containing display name, specialization, qualification and workplace. It does not return private identifiers or registration reference.
- `GET /me`: existing authoritative role-resolution endpoint. Existing case and review endpoints are unchanged.

FastAPI verifies Clerk tokens. Supabase RPCs are callable with the server secret key only; the app holds public Clerk configuration and its own session token. Admin provisioning and verification still require a trusted operator. The Flutter Admin landing has no privileged action. New Admin endpoints must check the current database role server-side before calling service-role functions; see `docs/ADMIN_MODULE_README.md`.

## Verification

- Baseline: 29 backend tests and 29 Flutter tests passed after restoring the local `O:` workspace alias and refreshing Flutter generated files.
- Current source: 33 backend unit/integration tests passed; 35 Flutter tests passed; `flutter analyze --no-pub` found no issues. Tests use synthetic or mocked records. The role-transition test exposed and confirmed a Future-returning setState retry bug; all affected refresh/retry callbacks were fixed. The local test runner required localhost socket access outside the restricted sandbox.
- Real-checkpoint smoke: passed with `ORALYN_MODEL_DIR=D:\oralyn-backend\models`, using a generated image. Invalid-image rejection, Grad-CAM availability/failure tolerance and conditional model chaining passed.
- New `supabase/tests/doctor_onboarding_checks.sql`: **not executed**. It contains 13 rollback-only pgtap assertions for role provisioning, pending state, RPC grants, own-profile RLS and re-verification. Run only after applying the new migration to an authorized development database.
- Physical Android registration, login, approval, role restoration and full case flow: **not tested in this change**. Do not treat the new Doctor application as live-ready until the migration and device verification pass.

## Remaining integration and security work

1. Review and apply `supabase/migrations/202611130001_doctor_onboarding.sql` to the authorized development project only; check existing schema/backup first. Then run `supabase/tests/doctor_onboarding_checks.sql` and the existing Phase 3C assertions using synthetic records.
2. Implement a trusted Admin API and provisioning process. The present Admin landing is intentionally inert. Document who can approve/reject/suspend and audit each operation.
3. Verify the full Android path with a new synthetic applicant: Clerk registration, application, pending status, trusted approval, dashboard, profile edit returning to pending, and case denial during pending/suspended states. Check a second Patient cannot read another's case or private images.
4. The referral/map screens still contain clearly separate mock care-facility content. Do not present those records as verified Oralyn Doctors; future location integration needs its own authoritative source and consent policy.
5. Chat is only a UI prototype. Future server and data design is in `docs/FUTURE_CHAT_ARCHITECTURE.md`.

## Local commands

From `D:\System Project` on Windows:

```powershell
subst O: 'D:\System Project'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
O:\.tooling\flutter\bin\flutter.bat analyze --no-pub
O:\.tooling\flutter\bin\flutter.bat test --no-pub -r compact
Set-Location 'D:\System Project\backend'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' -m unittest discover -s tests -q
$env:ORALYN_MODEL_DIR = 'D:\oralyn-backend\models'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' .\backend_gradcam_smoke_test.py
```

For Android/server setup, use `docs/PHASE4_MANUAL_TESTING.md`. It remains applicable to existing review workflows; apply the new migration before testing Doctor registration/profile.
