# Application refinement and verification

This change remains on `feature/doctor-onboarding`. It preserves Clerk role
verification, FastAPI screening inference, the `/predict` contract, model
checkpoints, Grad-CAM, Supabase RLS and private Storage. No remote schema or
production data was changed.

## Confirmed causes and changes

| Cause | Change | Result and limit |
| --- | --- | --- |
| The Patient shell keeps tab details in nested Navigators, but the shell did not dispatch Android back to the active tab. | The shell observes its tab routes. Back pops the active detail, then returns a secondary tab to Home; Home root keeps standard Android behavior. | Details retain the bottom bar. Physical gesture and button testing are still needed. |
| The result app-bar back button cleared the root stack. Signed-in auth routes also remained below the home route. | Result back now pops its route. Successful sign-in replaces auth routes with a role-resolving home route. | Back should return to the prior screen without reopening sign-in after login. Logout still clears protected routes. |
| Doctor work was one long page with no persistent navigation. | Verified Doctors now have Dashboard, Cases, Reviews, Messages and Profile tabs. Cases and review groups use authenticated assigned-case data; profile and disabled messaging reuse existing screens. | Case details remain full screen. No fabricated counts, cases or messages were added. |
| Saving was a separate action after a successful result. | Preparation offers an explicit private-save choice. When selected, analysis saves automatically before showing the result. The result shows confirmed saved or failed state and retains the same idempotency key for retry. | The current backend re-runs model inference during `/screenings` save; it does not accept client-created predictions. The result remains visible on save failure. |
| Review selection used illustrative care content, while Find Care used verified backend profiles. | The result and saved-history actions now open the verified Doctor directory. The review path sends an opaque public Doctor UUID and displays the request as pending assignment. The separate care-location demo is explicitly labeled. | The preferred Doctor is a request hint. Only a trusted Admin assignment grants case access. The new migration is required before this can work live. |

## Database change awaiting approval

`supabase/migrations/202611160001_review_doctor_preference.sql` is prepared but
**not applied** to Supabase project `arokswvcjddbzwthtqkh`. It adds a public
opaque UUID to Doctor profiles, a nullable UUID preference on review
requests and an authenticated RPC. The RPC checks the current Clerk subject,
saved-screening ownership, Patient role and Doctor verification, and rejects a
different preference on an existing request. It never creates an assignment.
The existing legacy review RPC remains available for old clients.

Before applying it, confirm the project reference, retain an export of the
disposable development schema/data if needed, and review the SQL. The file is
transaction-wrapped, so a failed statement rolls back. Once committed, there
is no automatic down migration; restoring a backup or a reviewed forward fix
would be required. After separate approval, run the migration in that one
development project and then run
`supabase/tests/review_doctor_preference_checks.sql`. Its 14 pgtap assertions
are transaction-wrapped and leave no test records when rolled back. Re-run the
existing 26 Phase 3C and 13 Doctor onboarding assertions after migration.

Until that migration is applied, `/doctors` can still display the legacy
sanitized directory, but it supplies no selectable Doctor identifier. The
picker reports that selection is unavailable; it never substitutes demo data.
Restart the FastAPI process after applying the migration to use the updated
backend code. A running Uvicorn process without reload serves the old code.

## Verification

- Flutter static analysis: no issues. All 46 Flutter tests passed. Widget
  tests cover navigation, Doctor tabs, automatic save success/failure,
  unsaved mode, account-switch protection and the live Doctor picker with
  synthetic data and mocked services. The final Doctor form layout also passed
  its focused widget tests after the full suite.
- All 38 backend tests passed. API consent/role checks, preference UUID
  forwarding, sanitized Doctor directory and preferred-review RPC use mocked
  Supabase responses. The real-checkpoint synthetic-image smoke test passed:
  invalid-image rejection, Grad-CAM availability/failure tolerance and
  conditional verification were observed.
- The new SQL suite and real Android back gestures have **not** run. The live
  Patient → preference → Admin assignment → Doctor review → feedback path
  remains unverified until the migration and device checks complete.
- Release APK built at
  `D:\System Project\build\app\outputs\flutter-apk\app-release.apk` on
  2026-11-16. SHA-256:
  `E8C79CF398A26844AC03CA6B0AA5A0F5656928BEDE8574E7BAD2D26FD9E4256A`.
  ADB showed no connected Android device during this verification.

## Android checks after migration

1. Install the newly built APK and configure the current HTTPS tunnel.
2. Sign in as a synthetic verified Doctor. Confirm all five tabs, case opening,
   profile and disabled Messages actions. From a case, press system Back and
   swipe Back; confirm return to Cases. Back from a secondary tab should open
   Dashboard.
3. Sign in as a synthetic Patient. Open a History detail and press system Back;
   confirm History remains selected. Open settings from Profile and go Back.
   Logout, then press Back; protected screens must not reopen.
4. Screen a synthetic image with private saving enabled. Confirm one History
   record appears without manual save. Disable it for another screening and
   confirm no automatic record. Test a temporary save failure and retry.
5. From a saved result choose a verified Doctor. Confirm the request says
   Pending assignment with the preferred Doctor, and no case appears for that
   Doctor yet. Assign through the trusted development Admin procedure; then
   review and submit synthetic feedback. Revoke the assignment and confirm
   case access is denied.

Use no real patient identifiers, oral images or clinical statements in these
checks. Do not apply this migration to another project or merge/deploy it as
part of this verification task.
