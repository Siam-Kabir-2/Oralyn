# Doctor assignment and case messaging

## Why this change exists

In the Oralyn development project, two review requests existed but neither had
an active case assignment. One request stored a preferred verified Doctor. A
preference alone does not grant case access, so the Doctor workspace correctly
showed no case. This change lets a Patient explicitly share a saved screening
with a verified Doctor and creates the assignment in the same database
transaction.

The screening flow now defaults to private automatic saving. The result screen
can start Doctor sharing without a separate Save tap: if the result was not
saved, it saves first, then opens the consent and Doctor selection flow. A
failed save stops sharing. AI inference, model files, class mapping, guidance,
and `/predict` response fields are unchanged.

## Database rollout

Target only Supabase project `arokswvcjddbzwthtqkh`, which its owner has
identified as development-only with synthetic, disposable records. Its
Dashboard labels the `main` branch **PRODUCTION**. The Free plan has no
scheduled database backup. A committed migration has no automatic rollback.
Confirm the project reference and take an appropriate project backup or accept
the disposable-data risk before applying anything. These two migrations require
separate owner approval; approval for earlier migrations does not cover them.

Dependencies: Phase 3B screening persistence, Phase 3C authorization, Doctor
onboarding, and the 2026-11-16 Doctor preference migration. Apply these files
in order, once each, as complete transaction-wrapped queries:

1. `supabase/migrations/202611170000_patient_doctor_assignment.sql`
2. `supabase/migrations/202611170001_case_messages.sql`

The first adds a `patient_assigned` audit event and
`request_and_assign_doctor(uuid,uuid)`. It verifies the Clerk JWT subject,
screening ownership and saved state, Doctor role and verification, and any
prior revocation. It is idempotent for the same active Doctor. It will not let
a Patient switch Doctors or undo an operator revocation. The second creates a
private message table and three guarded, signed-in-only RPCs. A Patient can
read their earlier messages after revocation; the Doctor immediately loses
access. Neither client nor server uses a client-supplied role to grant access.

After applying both migrations, run these rollback-only pgTAP files in fresh
SQL Editor queries, one at a time. Each uses `finish(true)` and ends in
`rollback;`; stop at the first error:

1. `supabase/tests/patient_assignment_checks.sql` — 15 assertions
2. `supabase/tests/case_messages_checks.sql` — 20 assertions
3. `supabase/tests/review_doctor_preference_checks.sql` — 14 assertions
4. `supabase/tests/phase3c_authorization_checks.sql` — 26 assertions
5. `supabase/tests/doctor_onboarding_checks.sql` — 13 assertions

Read-only postcheck:

```sql
select
  to_regprocedure('public.request_and_assign_doctor(uuid,uuid)') is not null
    as assignment_rpc,
  to_regclass('oralyn_private.case_messages') is not null as message_table,
  to_regprocedure('public.send_case_message(uuid,uuid,text)') is not null
    as send_rpc,
  (select count(*) from public.profiles
    where clerk_user_id like 'user_assign%' or clerk_user_id like 'user_chat%')
    as synthetic_test_profiles_left;
```

Expected: three `true` values and zero test profiles. The rollback-only tests
must not leave case or message rows either. Re-run Supabase security and
performance advisors after migration. Existing advisor findings about other
SECURITY DEFINER RPCs and RLS performance should be reviewed separately.

## Application flow

1. Patient completes a screening with a synthetic image. Private auto-save is
   on by default; an opted-out result is saved on tapping **Send to a verified
   Doctor** because a Doctor cannot access an in-memory image.
2. Patient chooses a live verified Doctor, reads the case-sharing disclosure,
   and taps **Consent and assign**. The assignment and audit record appear
   immediately; the same Doctor can retry safely.
3. Doctor refreshes Cases. The assigned case appears with its private image,
   AI result, review form, and **Message Patient about this case** action.
4. Patient opens the saved History record to see assignment status, Doctor
   feedback, and the private conversation. Doctor uses the Messages tab.
5. Both parties can exchange text messages. The client polls every ten seconds
   while the thread is open. Pagination and retry IDs prevent accidental
   duplicate sends. There are no attachments, push notifications, or emergency
   response guarantees.
6. Trusted operator revocation removes Doctor case and message access. The
   Patient can read old messages but cannot send more on that assignment.

Use only synthetic accounts and images. Verify Patient B cannot read Patient
A's case or messages, an unrelated Doctor cannot read or send, and a suspended
Doctor loses access. Do not paste bearer tokens into reports.

## Verification status

Local backend suite: 42 tests passed with mocked model inference. Flutter
suite: 51 tests passed. Flutter static analysis reported no issues before the
last copy edits and should be rerun for the final state. The 15 and 20 new SQL
assertions have **not** run against the remote database yet. The Android
Patient-to-Doctor-to-messaging flow has **not** been observed end to end on a
device. These features must not be described as production-ready until that
work, operational controls, and clinical review are complete.

Remaining security and operational work includes retention/deletion semantics
for messages, abuse and rate limits, a durable notification strategy, database
backup and restore drills, monitoring, and device-level accessibility and
visual QA. Case messages may contain sensitive information, so the current
implementation intentionally avoids message-body logging.
