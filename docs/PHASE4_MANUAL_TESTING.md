# Oralyn Phase 4 manual testing guide

This guide tests the development workflow only. Use the existing Clerk and
Supabase **development** projects, synthetic accounts and a generated image.
Do not use a production project, real patient information or a real clinical
image. Do not paste Clerk sessions or Supabase keys into screenshots, chat,
terminal history or the Flutter application.

## Current readiness

The local Python environment, both model checkpoints, Cloudflare tunnel tool,
Flutter SDK and private backend `.env` exist. The configured Supabase project
has the Phase 3B schema, but the Phase 3C migration is not applied yet. On the
current workstation Flutter also reports that the Android SDK is unavailable,
so install or reconnect that SDK before running on the phone.

Run the read-only prerequisite checker at any time:

```powershell
cd 'D:\System Project'
powershell -ExecutionPolicy Bypass `
  -File .\scripts\Test-Oralyn-Phase4Prerequisites.ps1
```

It prints only file/configuration presence and schema status. It never prints
keys and never changes the database. Before the migration it should report
the six Phase 3C schema checks as `FAIL`; after a correct migration they should
all report `OK`.

## 1. Apply and verify Phase 3C in development

This step changes the selected Supabase database. In the Supabase Dashboard,
check the project name and URL carefully and continue only if it is the
existing Oralyn development project. Stop if there is any doubt.

1. Open **Supabase Dashboard → SQL Editor → New query**.
2. Copy the migration from the repository:

   ```powershell
   Get-Content `
     '.\supabase\migrations\202611120001_phase3c_authorization.sql' `
     -Raw | Set-Clipboard
   ```

3. Paste it into the SQL Editor. Confirm the editor is connected to the
   development project, then select **Run** once.
4. Do not rerun a successful migration. It is intentionally a one-time,
   versioned migration.
5. Run the prerequisite checker again. Every schema check should be `OK`.

Run the transaction-contained authorization suite next:

```powershell
Get-Content `
  '.\supabase\tests\phase3c_authorization_checks.sql' `
  -Raw | Set-Clipboard
```

Paste it into a new SQL Editor query and run it. Expected result: all 26 pgtap
assertions pass, `finish()` reports no failures and the final `rollback`
removes all synthetic rows. The assertions cover Patient ownership, blocked
role changes, blocked self-assignment, verified/unverified/suspended Doctors,
active/revoked assignments, stale review versions, finalized feedback, and
Patient/Doctor private Storage RLS.

If `pgtap` cannot be created, enable the pgtap extension for the development
project and rerun the test query. If the migration reports that an object
already exists, stop rather than editing around the error. Use this read-only
query to inspect what exists:

```sql
select
  to_regclass('public.doctor_profiles') as doctor_profiles,
  to_regclass('public.review_requests') as review_requests,
  to_regclass('public.case_assignments') as case_assignments,
  to_regclass('public.doctor_reviews') as doctor_reviews,
  to_regclass('public.case_audit_events') as case_audit_events,
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'application_role'
  ) as profiles_has_application_role;
```

## 2. Private backend configuration

The backend reads `D:\oralyn-backend\.env`; it is ignored by Git. Keep these
values there, using keys from the existing development dashboards:

```dotenv
SUPABASE_URL=https://YOUR-DEVELOPMENT-PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
SUPABASE_SECRET_KEY=sb_secret_...
SUPABASE_STORAGE_BUCKET=screening-images
```

`Start-Oralyn-Server.ps1` supplies the existing public Clerk development
issuer when `CLERK_ISSUER` is not already set. `CLERK_AUTHORIZED_PARTIES` and
`CLERK_AUDIENCE` are optional claim restrictions; set them only to values that
match the existing Clerk session tokens. Never put `SUPABASE_SECRET_KEY` or a
Clerk secret key in Flutter or in a `--dart-define`.

Supabase Authentication → Third-Party Auth must show the existing Clerk
development domain as enabled. Clerk's Supabase integration must add
`role: authenticated` to session tokens. Otherwise PostgreSQL will not apply
the authenticated policies to Clerk sessions.

## 3. Start FastAPI and the HTTPS tunnel

From a PowerShell window:

```powershell
cd 'D:\System Project'
powershell -ExecutionPolicy Bypass -File .\Start-Oralyn-Server.ps1
```

The script starts Uvicorn at `http://127.0.0.1:8000`, waits for both models,
then starts a Cloudflare Quick Tunnel. Expected result:

- `FastAPI is healthy.` appears.
- Cloudflare prints a new `https://...trycloudflare.com` URL.
- `http://127.0.0.1:8000/health` returns `{"status":"healthy"}`.

Keep that window open. A Quick Tunnel URL usually changes after a restart.
Backend logs are `oralyn-server.log` and `oralyn-server-error.log`; they are
ignored by Git. Stop the tunnel and server with **Ctrl+C** when testing ends.

## 4. Prepare Android

Flutter currently cannot find an Android SDK. Install Android Studio or the
Android command-line SDK with Platform Tools, then point Flutter to it. For a
default Android Studio installation:

```powershell
cd O:\
& 'O:\.tooling\flutter\bin\flutter.bat' config `
  --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
& 'O:\.tooling\flutter\bin\flutter.bat' doctor --android-licenses
& 'O:\.tooling\flutter\bin\flutter.bat' doctor -v
```

This workstation has `O:\` as the space-free alias of `D:\System Project`.
Flutter's native-asset hook fails when it invokes the SDK through the path
containing a space. If `O:\` is ever missing, recreate the alias in an
Administrator PowerShell window with `subst O: 'D:\System Project'`, then use
`O:\` for all Flutter commands.

On the phone, enable Developer options and USB debugging, select **File
transfer**, connect the USB cable and accept the RSA authorization prompt.
Then run:

```powershell
& 'O:\.tooling\flutter\bin\flutter.bat' devices
```

Expected result: the Android phone appears with a device ID. If it says
`unauthorized`, unlock the phone and accept the prompt. If no Android device
appears, try another data-capable cable/USB port and confirm Windows Device
Manager shows an Android ADB interface.

Start the app with the current tunnel URL so a clean installation does not
start with an expired default URL:

```powershell
cd O:\
& 'O:\.tooling\flutter\bin\flutter.bat' pub get
& 'O:\.tooling\flutter\bin\flutter.bat' run `
  -d YOUR_ANDROID_DEVICE_ID `
  --dart-define=ORALYN_API_BASE_URL=https://YOUR-TUNNEL.trycloudflare.com
```

The app adds `/predict` automatically. If the tunnel changes later, use
**Profile → Screening server** as a Patient, or the server icon in the Doctor
workspace. The account-profile error screen also links to **Screening server**.
Paste only the HTTPS tunnel origin, save it, return, and tap **Try again**.

## 5. Create synthetic accounts

Use three Clerk development accounts: Patient A, Patient B and Doctor A. Use
invented names, no personal email content and unique temporary test passwords.
The existing Clerk development instance supports its reserved test-email
flow; an address containing `+clerk_test` can use the test verification code
`424242`. If that dashboard feature is disabled, use controlled development
inboxes instead.

For each account:

1. Register in Oralyn and complete email verification.
2. Confirm the protected home screen opens.
3. Record its Clerk `user_...` ID from Clerk Dashboard → Users. Do not record
   or share its session token.
4. Sign out before creating the next account.

Expected result: new accounts are Patients. An ordinary account has no UI or
database permission to promote itself, verify a Doctor or assign a case.

Promote only Doctor A using Supabase SQL Editor. Replace the placeholder with
Doctor A's Clerk user ID:

```sql
select public.enroll_doctor_candidate(
  'user_REPLACE_WITH_DOCTOR_ID',
  'Synthetic Doctor A',
  'Oral medicine test profile',
  'Synthetic qualification',
  'TEST-REG-001',
  'phase4-manual-test'
);
```

Sign in as Doctor A before verification. Expected result: the Doctor workspace
shows `Verification pending` and no case data. Then verify the test Doctor:

```sql
select public.set_doctor_verification(
  'user_REPLACE_WITH_DOCTOR_ID',
  'verified',
  'phase4-manual-test'
);
```

Sign out and back in, or force-stop and reopen Oralyn. Expected result:
`Verification active` appears. Doctor verification remains read-only in the
app.

## 6. Create and load a synthetic image

Generate a plain, non-identifiable PNG on the computer:

```powershell
Add-Type -AssemblyName System.Drawing
$syntheticImage = Join-Path $env:TEMP 'oralyn-synthetic.png'
$bitmap = New-Object System.Drawing.Bitmap 512,512
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::FromArgb(180,120,115))
$graphics.FillEllipse([System.Drawing.Brushes]::LightPink,120,160,272,180)
$bitmap.Save($syntheticImage,[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
$syntheticImage
```

Copy it to the connected phone after the Android SDK is installed:

```powershell
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adb push $syntheticImage /sdcard/Download/oralyn-synthetic.png
```

The generated pattern is only a transport and workflow test. Its model output
has no clinical meaning.

## 7. Patient screening and review request

Sign in as Patient A and perform these steps:

1. Tap **Start screening** and select the generated PNG from Downloads.
2. Continue through preview, quality and analysis.
3. Expected: a real AI-assisted result appears with a primary class, score,
   existing guidance and Grad-CAM when available. The secondary model runs
   only for `OPMD` or `Oral_Cancer` primary output.
4. Tap **Save result**. Expected: `Screening saved to your private history.`
5. Open **History**, then the saved record. Expected: original image, result
   and private visual explanation load.
6. Tap **Request Doctor review**, read the sharing explanation, then tap
   **I consent and request review**.
7. Expected: status becomes **Pending assignment**. Reopening the record must
   show the same persisted request rather than creating a duplicate.

In Supabase SQL Editor, find the synthetic request without exposing image data:

```sql
select rr.id, rr.screening_id, rr.status, rr.created_at
from public.review_requests rr
where rr.patient_id = 'user_REPLACE_WITH_PATIENT_A_ID'
order by rr.created_at desc;
```

## 8. Assign, review, revoke and reassign

Assign the request to verified Doctor A. Replace both placeholders:

```sql
select public.assign_review_case(
  'REPLACE_WITH_REVIEW_REQUEST_UUID'::uuid,
  'user_REPLACE_WITH_DOCTOR_ID',
  'phase4-manual-test'
) as assignment_id;
```

Sign in as Doctor A. Expected: one assigned case appears. Open it and verify:

- the original private image loads;
- the AI class, score breakdown and guidance match the saved Patient record;
- secondary verification appears only when it was performed;
- Grad-CAM is labelled as a visual explanation, not lesion segmentation;
- no unrelated Patient record appears.

Enter obviously synthetic text, for example `Synthetic workflow observation`,
`Synthetic workflow recommendation`, and `Synthetic follow-up only`. Tap
**Save draft**. Expected: success message, no duplicate review, and the case
state becomes `in_review` after returning to the refreshed case list.

Test revocation before final submission. Find the active assignment:

```sql
select ca.id, ca.review_request_id, ca.doctor_id, rr.status
from public.case_assignments ca
join public.review_requests rr on rr.id = ca.review_request_id
where ca.review_request_id = 'REPLACE_WITH_REVIEW_REQUEST_UUID'::uuid
  and ca.revoked_at is null;
```

Revoke it:

```sql
select public.revoke_review_assignment(
  'REPLACE_WITH_ASSIGNMENT_UUID'::uuid,
  'phase4-manual-test'
);
```

Return to/reload the Doctor workspace. Expected: the case disappears. A stale
open detail must fail on the next API/image/save request. The request returns
to `pending_assignment`. Reassign it by running `assign_review_case` again;
this returns a new assignment ID. Expected: Doctor A sees it again with a new,
separate review form. The revoked draft is not silently transferred.

Complete the new review and tap **Submit review**. Expected: the backend
confirms persistence, the form becomes read-only, and the case status is
`reviewed`. Repeated or stale writes must return a conflict instead of
overwriting the submitted review.

## 9. Patient feedback and isolation

Sign out and sign in as Patient A. Open the original History record. Expected:

- review status is **Reviewed**;
- Doctor name and specialization appear;
- observations, recommendations and follow-up match the submitted synthetic
  text;
- Doctor feedback is separate from the immutable AI output.

Sign in as Patient B. Expected: Patient A's screening and feedback do not
appear in Home or History. Patient B cannot request a review for Patient A's
screening because the record is not visible. The 26 SQL assertions provide the
direct RLS and Storage-policy checks for cross-Patient and assigned-Doctor
access.

Suspend Doctor A to verify immediate permission removal:

```sql
select public.set_doctor_verification(
  'user_REPLACE_WITH_DOCTOR_ID',
  'suspended',
  'phase4-manual-test'
);
```

Expected: after refresh, Doctor A receives verified-Doctor denial and cannot
read assigned private case data. Restore the synthetic test account only if
more testing is required:

```sql
select public.set_doctor_verification(
  'user_REPLACE_WITH_DOCTOR_ID',
  'verified',
  'phase4-manual-test'
);
```

## 10. Automated verification commands

Run from the repository root:

```powershell
Push-Location 'D:\System Project\.backend-work'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' `
  -m unittest discover -s .\tests -v
Pop-Location

Push-Location O:\
& 'O:\.tooling\flutter\bin\flutter.bat' analyze
& 'O:\.tooling\flutter\bin\flutter.bat' test
Pop-Location

$env:ORALYN_MODEL_DIR = 'D:\oralyn-backend\models'
Push-Location .\.backend-work
& 'D:\oralyn-backend\.venv\Scripts\python.exe' `
  .\backend_gradcam_smoke_test.py
Pop-Location
```

The SQL suite is run in the Supabase development SQL Editor as described in
section 1. Do not describe it as passed until its pgtap output is visible.

## Troubleshooting

| Symptom | Likely cause and action |
| --- | --- |
| `Account profile is unavailable` | Phase 3C is absent, the tunnel URL is stale, or Supabase is unreachable. Run the prerequisite checker; use **Screening server**, then **Try again**. |
| Server never becomes healthy | Check `oralyn-server-error.log`; confirm both checkpoint files exist and port 8000 is free. Model startup can take about a minute on CPU. |
| App gets 401 | Sign in again. Check `CLERK_ISSUER` and Clerk/Supabase third-party auth. Do not reuse an old session token. |
| Doctor gets 403 | The database role is not Doctor, verification is pending/suspended, or the account needs to sign out/in after promotion. |
| Case/image returns 404 | The assignment was revoked, the case is not assigned to this Doctor, or RLS denied it. This is the expected privacy-safe response. |
| Review save returns 409 | Another save changed the review version. Leave and reopen the case before editing. |
| History/case service returns 503 | Check the private Supabase variables, migration, network and server logs. |
| SQL test plan fails | Do not change the expected plan count. Read the named failed assertion; the test transaction rolls back automatically. |
| Flutter sees no Android device | Install/configure the Android SDK, enable USB debugging, accept the RSA prompt and rerun `flutter devices`. |
| Images do not load after revocation | This is expected. Current assignment and verification are checked for each new metadata/Storage request. |
| Tunnel restarted | Copy the new HTTPS origin into **Screening server** for each app installation; do not append `/docs`. |

## Final manual checklist

1. Confirm the selected Supabase project is development.
2. Apply the Phase 3C migration once.
3. Run and observe all 26 SQL assertions passing.
4. Run the prerequisite checker and confirm every item is `OK`.
5. Start FastAPI and keep the Quick Tunnel window open.
6. Configure Android, connect the phone and run Oralyn with the tunnel URL.
7. Create Patient A, Patient B and Doctor A synthetic Clerk accounts.
8. Enroll Doctor A; confirm pending Doctors see no cases; then verify it.
9. Generate the synthetic PNG; screen and save it as Patient A.
10. Request review and confirm duplicate requests are prevented.
11. Assign the request to Doctor A and confirm only that case is visible.
12. Save a draft, revoke the assignment and confirm access disappears.
13. Reassign, submit synthetic feedback and confirm the review is read-only.
14. Confirm Patient A sees feedback separate from the AI result.
15. Confirm Patient B sees none of Patient A's history or feedback.
16. Suspend Doctor A and confirm case access is denied.
17. Run backend tests, Flutter analysis/tests and the real-checkpoint smoke.
18. Stop the server/tunnel and remove temporary test accounts/data when the
    approved development cleanup procedure is available.
