# Application refinement and verification

This change remains on `feature/doctor-onboarding`. It preserves Clerk role
verification, FastAPI screening inference, the `/predict` contract, model
checkpoints, Grad-CAM, Supabase RLS and private Storage. Only the approved
Oralyn development project schema was changed; no other project or real
patient data was changed.

## Confirmed causes and changes

| Cause | Change | Result and limit |
| --- | --- | --- |
| The Patient shell keeps tab details in nested Navigators, but the shell did not dispatch Android back to the active tab. | The shell observes its tab routes. Back pops the active detail, then returns a secondary tab to Home; Home root keeps standard Android behavior. | Details retain the bottom bar. Physical gesture and button testing are still needed. |
| The result app-bar back button cleared the root stack. Signed-in auth routes also remained below the home route. | Result back now pops its route. Successful sign-in replaces auth routes with a role-resolving home route. | Back should return to the prior screen without reopening sign-in after login. Logout still clears protected routes. |
| Doctor work was one long page with no persistent navigation. | Verified Doctors now have Dashboard, Cases, Reviews, Messages and Profile tabs. Cases and review groups use authenticated assigned-case data; profile and disabled messaging reuse existing screens. | Case details remain full screen. No fabricated counts, cases or messages were added. |
| Saving was a separate action after a successful result. | Preparation offers an explicit private-save choice. When selected, analysis saves automatically before showing the result. The result shows confirmed saved or failed state and retains the same idempotency key for retry. | The current backend re-runs model inference during `/screenings` save; it does not accept client-created predictions. The result remains visible on save failure. |
| Review selection used illustrative care content, while Find Care used verified backend profiles. | The result and saved-history actions now open the verified Doctor directory. The review path sends an opaque public Doctor UUID and displays the request as pending assignment. The separate care-location demo is explicitly labeled. | The preferred Doctor is a request hint. Only a trusted Admin assignment grants case access. The migration is applied, but the live mobile flow still needs testing. |

## Development database migration

The owner ran `supabase/migrations/202611160001_review_doctor_preference.sql`
in Supabase development project `arokswvcjddbzwthtqkh` on 2026-11-16. The SQL
Editor reported `Success. No rows returned`. It adds a public
opaque UUID to Doctor profiles, a nullable UUID preference on review
requests and an authenticated RPC. The RPC checks the current Clerk subject,
saved-screening ownership, Patient role and Doctor verification, and rejects a
different preference on an existing request. It never creates an assignment.
The existing legacy review RPC remains available for old clients.

The file is transaction-wrapped, so a failed statement would have rolled
back. Once committed, there is no automatic down migration; restoring a backup
or a reviewed forward fix would be required. The first 14-assertion run stopped
at a synthetic fixture that violated the pre-existing 16-character minimum
for screening idempotency keys. That test transaction rolled back. The fixture
has been corrected. The 14, 26 Phase 3C and 13 Doctor onboarding suites now
use `finish(true)` so assertion failures surface as SQL errors; each suite
ends with `rollback;`. The owner then ran all three updated suites in separate
SQL Editor queries and reported that all three showed passed results. The
individual TAP rows were not exported for independent review. A read-only
follow-up query returned `rpc_present=true`, `test_profiles_left=0` and
`test_screenings_left=0` for the new suite's synthetic fixture IDs.

Restart the FastAPI process to use the updated backend code. A running Uvicorn
process without reload serves the old code.

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
- The new SQL suite initially stopped at a fixture error and rolled back.
  After correction, the owner reported that the 14, 26 and 13 assertion suites
  all passed with `finish(true)`. This is owner-observed SQL Editor evidence;
  individual TAP rows were not independently captured. Real Android back
  gestures and the Patient → preference → Admin assignment → Doctor review →
  feedback path remain unverified.
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
