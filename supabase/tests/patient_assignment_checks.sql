-- Development-only checks for direct consented assignment. No rows persist.
begin;
create extension if not exists pgtap;
select plan(15);

set local role service_role;
insert into public.profiles(clerk_user_id, application_role) values
  ('user_assignpatienta', 'patient'),
  ('user_assignpatientb', 'patient'),
  ('user_assigndoctorA', 'doctor'),
  ('user_assigndoctorB', 'doctor'),
  ('user_assigndoctorC', 'doctor');
insert into public.doctor_profiles(
  clerk_user_id, display_name, specialization, qualification,
  registration_reference, verification_state, verified_at, verified_by
) values
  ('user_assigndoctorA', 'Synthetic Doctor A', 'Oral medicine',
   'Synthetic degree', 'TEST-ASSIGN-A', 'verified', now(), 'test-operator'),
  ('user_assigndoctorB', 'Synthetic Doctor B', 'Oral medicine',
   'Synthetic degree', 'TEST-ASSIGN-B', 'verified', now(), 'test-operator'),
  ('user_assigndoctorC', 'Synthetic Doctor C', 'Oral medicine',
   'Synthetic degree', 'TEST-ASSIGN-C', 'pending', null, null);
insert into public.screenings(id, patient_id, idempotency_key) values
  ('50000000-0000-4000-8000-000000000001',
   'user_assignpatienta', 'assign-owner-key-0001'),
  ('50000000-0000-4000-8000-000000000002',
   'user_assignpatienta', 'assign-owner-key-0002');
select set_config('test.doctor_a', (select directory_id::text
  from public.doctor_profiles where clerk_user_id='user_assigndoctorA'), true);
select set_config('test.doctor_b', (select directory_id::text
  from public.doctor_profiles where clerk_user_id='user_assigndoctorB'), true);
select set_config('test.doctor_c', (select directory_id::text
  from public.doctor_profiles where clerk_user_id='user_assigndoctorC'), true);

select ok(has_function_privilege('authenticated',
  'public.request_and_assign_doctor(uuid,uuid)', 'EXECUTE'),
  'authenticated Patient can invoke the assignment RPC');
select ok(not has_function_privilege('anon',
  'public.request_and_assign_doctor(uuid,uuid)', 'EXECUTE'),
  'anonymous caller cannot invoke the assignment RPC');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_assignpatienta","role":"authenticated"}', true);
select is((select status from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid)),
  'assigned'::text, 'consented selection assigns immediately');
set local role service_role;
select set_config('test.assignment_id', (select ca.id::text
  from public.case_assignments ca join public.review_requests rr
  on rr.id=ca.review_request_id
  where rr.screening_id='50000000-0000-4000-8000-000000000001'), true);
select is((select count(*)::bigint from public.case_assignments
  where id=current_setting('test.assignment_id')::uuid
    and revoked_at is null), 1::bigint, 'active assignment exists');
select is((select count(*)::bigint from public.case_audit_events
  where assignment_id=current_setting('test.assignment_id')::uuid
    and event_kind='patient_assigned'), 1::bigint,
  'Patient assignment is audited');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_assignpatienta","role":"authenticated"}', true);
select is((select assignment_id from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid)),
  current_setting('test.assignment_id')::uuid,
  'response returns the existing assignment identifier');
select is((select assignment_id from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid)),
  current_setting('test.assignment_id')::uuid,
  'retry is idempotent');
set local role service_role;
select is((select count(*)::bigint from public.case_assignments
  where review_request_id=(select id from public.review_requests
    where screening_id='50000000-0000-4000-8000-000000000001')),
  1::bigint, 'retry creates no duplicate case');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_assignpatientb","role":"authenticated"}', true);
select throws_ok($$select * from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_a')::uuid)$$,
  '42501', null, 'another Patient cannot assign this screening');
select set_config('request.jwt.claims',
  '{"sub":"user_assignpatienta","role":"authenticated"}', true);
select throws_ok($$select * from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_c')::uuid)$$,
  '42501', null, 'pending Doctor cannot receive a case');
select throws_ok($$select * from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_b')::uuid)$$,
  '23505', null, 'Patient cannot switch an active case to another Doctor');

select set_config('request.jwt.claims',
  '{"sub":"user_assigndoctorA","role":"authenticated"}', true);
select throws_ok($$select * from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_a')::uuid)$$,
  '42501', null, 'Doctor cannot assign a Patient case');
select ok(public.can_review_screening(
  '50000000-0000-4000-8000-000000000001'),
  'assigned verified Doctor can review the screening');

set local role service_role;
select public.revoke_review_assignment(
  current_setting('test.assignment_id')::uuid, 'test-operator');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_assigndoctorA","role":"authenticated"}', true);
select ok(not public.can_review_screening(
  '50000000-0000-4000-8000-000000000001'),
  'revoked Doctor loses case access');
select set_config('request.jwt.claims',
  '{"sub":"user_assignpatienta","role":"authenticated"}', true);
select throws_ok($$select * from public.request_and_assign_doctor(
  '50000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid)$$,
  '42501', null, 'Patient cannot undo a trusted revocation');

select * from finish(true);
select '15 pgTAP assertions passed' as test_result;
rollback;
