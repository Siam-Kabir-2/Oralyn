# Admin module development contract

For Md. Shahidur Rahman. Implement on `feature/admin-module` from the shared integration baseline. The current Flutter Admin landing is intentionally minimal; it grants no administrative operation.

## Purpose and existing architecture

One Clerk application authenticates Patients, Doctors and Admins. Flutter obtains a Clerk session token and sends it to FastAPI. FastAPI verifies the token, then resolves the application role from `public.profiles`. Supabase PostgreSQL holds Doctor profiles, screening review requests, case assignments and reviews. Oral images remain in private Storage. Never accept a client-provided role or operator ID as authority.

The Phase 3C schema is in `supabase/migrations/202611120001_phase3c_authorization.sql`. The Doctor onboarding extension is `supabase/migrations/202611130001_doctor_onboarding.sql`; it was applied to the authorized development project `arokswvcjddbzwthtqkh` on 2026-11-14 and both SQL suites passed. Do not apply it there again. It adds `admin` to `profiles.application_role`, `doctor_profiles.workplace`, and service-role-only Doctor application/profile functions. It does not add Admin endpoints or policies.

## Trusted Admin authentication

The Admin sign-in entry uses the same Clerk session as other roles. There is no public Admin registration. A trusted, separately authenticated operator must provision `profiles.application_role = 'admin'` for a known Clerk subject through a server-side administrative procedure. Do not expose the Supabase secret key, an Admin-provisioning RPC, or role updates to Flutter. The current `GET /me` returns the authoritative role and the Flutter landing recognizes `admin`, but every future Admin API must verify the Clerk identity **and** query the current database role before any privileged operation. Use a strict server-side Admin dependency, audit the resolved subject, and return 403 for non-Admins. Treat self-supplied `assigned_by`, `verified_by`, and similar fields as untrusted.

## Existing shared contracts

| Record / operation | Current implementation | Admin module work |
| --- | --- | --- |
| `profiles` | Clerk subject and trusted application role | Trusted Admin provisioning and revocation procedure |
| `doctor_profiles` | Application fields, workplace, verification state and metadata | Application queue, verification decisions and management |
| `POST /doctor/applications` | Patient account applies; persists pending only | Read the same record; do not create a second application table |
| `GET/PUT /doctor/profile` | Doctor sees own record; credential edits return to pending | Review changed credentials before re-approval |
| `GET /doctors` | Authenticated, sanitized verified profiles | Keep public display limited to verified records |
| `review_requests` | Patient requests review for an owned saved screening | Pending assignment queue |
| `case_assignments` | Active assignment and revocation fields | Assign, reassign and revoke through trusted operations |
| `doctor_reviews` | Assigned verified Doctor saves/submits structured review | Oversight metadata only; preserve clinical authorship |
| `case_audit_events` | Case access audit records | Privacy-conscious activity view |

Phase 3C already defines service-role-only `set_doctor_verification`, `assign_review_case`, and `revoke_review_assignment` functions. Inspect their signatures and transition rules before using them. The old operator scripts are for trusted development administration, not mobile endpoints. The Admin module must supply its own server-side authorization layer before invoking these functions. Reassignment should revoke the old active assignment and then assign an eligible verified Doctor in a controlled transaction; check the unique active-assignment constraint and review status. Case access is also enforced by RLS, so revocation and Doctor suspension immediately block future case reads. Review how credential edits returning to pending affect an existing assignment before approval.

## Screens and workflows

1. **Dashboard:** pending Doctor applications, verified and suspended Doctors, pending review requests, active assignments and recent administrative actions. Fetch server data; use empty/loading/error states.
2. **Applications:** inspect professional details from `doctor_profiles`; approve or reject with an authenticated Admin action. Show decision state and operator/time metadata. Re-review pending credential changes.
3. **Doctor management:** view current state; suspend or reinstate through trusted verification operations. A rejected application needs a defined reapplication policy before a retry endpoint is added. Do not edit a Doctor's profile or impersonate them.
4. **Assignment management:** inspect only the data needed to assign a case; select a verified Doctor; revoke or reassign, with a visible confirmation and an audit record. Do not download private oral images merely to assign work.
5. **Activity:** action type, target reference, operator, timestamp and outcome. Avoid patient identifiers, medical text, tokens, raw images and secrets in logs.

Use FastAPI endpoints backed by a `require_admin` dependency, narrow request/response schemas, database constraints, transaction-safe state changes and RLS for direct user access. Do not use the Supabase service key from Flutter. If Admin APIs use the service key, each action must first verify the current database role and its specific permission; service-role access bypasses RLS.

## Security and tests

Test missing/invalid/expired Clerk tokens (401), Patient and Doctor access to Admin routes (403), self-assigned Admin claims, duplicate approvals, rejected/suspended transitions, assignment to unverified Doctors, duplicate active assignments, cross-patient access, revocation, and concurrent updates. Verify that a suspended Doctor cannot read cases or private images and that an Admin cannot gain private clinical records merely by opening the dashboard. Run SQL/RLS tests in a disposable development environment; do not change production without explicit approval. Use synthetic cases only.

## Doctor review and future chat

Patient screening → Patient review request → Admin assigns verified Doctor → Doctor submits structured feedback → Patient reads feedback. Those steps already have foundations and must remain functional. A later chat feature may let a Patient request conversation about an eligible reviewed case. The **assigned Doctor**, not the Admin, decides whether to approve that chat. Admin verification and assignment do not grant blanket access to private conversations. No chat API, table, approval or message service exists in this phase; do not implement chat as part of the Admin module. See `docs/FUTURE_CHAT_ARCHITECTURE.md`.
