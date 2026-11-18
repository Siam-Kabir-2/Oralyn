# Patient profiles in Supabase

## Scope

`public.profiles` remains the authoritative application-role table. The new
`public.patient_profiles` table holds only Patient display name, verified
primary email, Clerk account creation time, and last synchronization time.
Screening count is derived from `public.screenings`; it is not copied into a
profile column. Doctor information stays in `public.doctor_profiles`.

The Flutter Patient Profile screen already reads the signed-in user's name and
email from Clerk. No Admin API or Admin UI was changed here. The Admin module
owner can later expose a narrow Patient list through a FastAPI route that
checks the current database Admin role. The mobile app must never receive the
Supabase secret key or query all Patient profiles directly.

## Synchronization

FastAPI's authenticated `GET /me` first verifies the Clerk session and checks
the database role. For a Patient, and only when `CLERK_SECRET_KEY` is configured
on the server, it fetches that same user's record from Clerk's Backend API.
Only the primary email with a verified status is stored. Clerk API failures do
not block login or screening; synchronization is retried on the next `/me`.
Name, email, Clerk creation date and Clerk key are never logged.

`CLERK_SECRET_KEY` is configured in `D:\oralyn-backend\.env` on the
development machine. Obtain it from the existing Clerk development instance's
API Keys page on another machine. Never put the value in Flutter or commit it.
Restart FastAPI after changing the environment file.

The migration at `supabase/migrations/202611190001_patient_profiles.sql` was
applied to Oralyn development project `arokswvcjddbzwthtqkh` on 19 November
2026. It created placeholder rows for the existing three Patient profiles.
Those rows initially had null identity fields until trusted Clerk
synchronization ran.
The migration enables RLS, grants Patients read access only to their own row,
and gives mobile users no insert or update privilege.

To backfill existing development Patients after adding the Clerk key, first
check the locked project target without writes, then run the explicit apply:

```powershell
Set-Location 'D:\System Project\backend'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' .\backfill_patient_profiles.py --env-file 'D:\oralyn-backend\.env'
& 'D:\oralyn-backend\.venv\Scripts\python.exe' .\backfill_patient_profiles.py --env-file 'D:\oralyn-backend\.env' --apply
```

The script refuses any Supabase project other than the named development
project and any Clerk key other than a development secret. It prints counts,
never profile values. A deleted or unavailable Clerk account is skipped.

Read-only verification in the development SQL Editor:

```sql
select p.clerk_user_id, pp.display_name, pp.verified_email,
       pp.clerk_created_at, pp.synced_at,
       (select count(*) from public.screenings s
        where s.patient_id = p.clerk_user_id) as screening_count
from public.profiles p
left join public.patient_profiles pp using (clerk_user_id)
where p.application_role = 'patient'
order by p.created_at desc;
```

## Verification and limits

The migration was applied only to project `arokswvcjddbzwthtqkh`.
`supabase/tests/patient_profiles_checks.sql` returned 12 passing pgTAP
assertions and rolled back its synthetic rows. A follow-up read found three
Patient profile rows, no leftover test rows, and RLS enabled. The locked
backfill dry run found three Patients; the live Clerk backfill then synced all
three with zero unavailable users. A final read-only query found 3/3 rows with
display names, verified emails, Clerk creation dates and sync timestamps.
All 46 backend tests passed with mocked Clerk responses. FastAPI was restarted
with the backend-only key, and the existing Cloudflare `/health` URL returned
`healthy`. An interactive Patient `/me` request with a live session has not
been tested after the restart.

Clerk remains the source of truth. If a Patient changes their name or verified
email, the next `/me` refreshes the cache. Avoid using the cached email as an
authorization claim; authorization continues to use verified Clerk subjects
and current database roles.
