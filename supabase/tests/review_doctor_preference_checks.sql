-- Development-only checks after 202611160001. Test rows roll back.
begin;
create extension if not exists pgtap;
select plan(14);

set local role service_role;
insert into public.profiles(clerk_user_id, application_role) values
  ('user_prefpatienta', 'patient'), ('user_prefpatientb', 'patient'),
  ('user_prefdoctora', 'doctor'), ('user_prefdoctorb', 'doctor'),
  ('user_prefdoctorc', 'doctor');
insert into public.doctor_profiles(
  clerk_user_id, display_name, specialization, qualification,
  registration_reference, verification_state, verified_at, verified_by
) values
  ('user_prefdoctora', 'Synthetic Doctor A', 'Oral medicine',
   'Synthetic degree', 'TEST-PREF-A', 'verified', now(), 'test-operator'),
  ('user_prefdoctorb', 'Synthetic Doctor B', 'Oral medicine',
   'Synthetic degree', 'TEST-PREF-B', 'verified', now(), 'test-operator'),
  ('user_prefdoctorc', 'Synthetic Doctor C', 'Oral medicine',
   'Synthetic degree', 'TEST-PREF-C', 'pending', null, null);
insert into public.screenings(id, patient_id, idempotency_key) values
  ('40000000-0000-4000-8000-000000000001', 'user_prefpatienta', 'pref-owner-one-0001'),
  ('40000000-0000-4000-8000-000000000002', 'user_prefpatienta', 'pref-owner-two-0002');

select has_column('public', 'doctor_profiles', 'directory_id',
  'Doctor directory has an opaque public identifier');
select has_column('public', 'review_requests', 'preferred_doctor_directory_id',
  'review request records the preferred Doctor by opaque UUID');
select isnt((select directory_id from public.doctor_profiles
  where clerk_user_id = 'user_prefdoctora'),
  (select directory_id from public.doctor_profiles
  where clerk_user_id = 'user_prefdoctorb'),
  'public Doctor identifiers are distinct');
select ok(has_function_privilege('authenticated',
  'public.request_review_with_preference(uuid,uuid)', 'EXECUTE'),
  'authenticated Patients can invoke the preference RPC');
select ok(not has_function_privilege('anon',
  'public.request_review_with_preference(uuid,uuid)', 'EXECUTE'),
  'anonymous users cannot invoke the preference RPC');
select set_config('test.doctor_a', (select directory_id::text
  from public.doctor_profiles where clerk_user_id = 'user_prefdoctora'), true);
select set_config('test.doctor_b', (select directory_id::text
  from public.doctor_profiles where clerk_user_id = 'user_prefdoctorb'), true);
select set_config('test.doctor_c', (select directory_id::text
  from public.doctor_profiles where clerk_user_id = 'user_prefdoctorc'), true);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_prefpatienta","role":"authenticated"}', true);
select is((select status from public.request_review_with_preference(
  '40000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid)),
  'pending_assignment'::text, 'selection remains pending trusted assignment');
select is((select preferred_doctor_directory_id from public.review_requests
  where screening_id = '40000000-0000-4000-8000-000000000001'),
  current_setting('test.doctor_a')::uuid, 'preferred Doctor is stored');
select is((select preferred_doctor_directory_id
  from public.request_review_with_preference(
    '40000000-0000-4000-8000-000000000001',
    current_setting('test.doctor_a')::uuid)),
  current_setting('test.doctor_a')::uuid,
  'same preference is idempotent');
select is((select count(*)::bigint from public.review_requests
  where screening_id = '40000000-0000-4000-8000-000000000001'),
  1::bigint, 'retry creates no duplicate request');
select throws_ok($$select * from public.request_review_with_preference(
  '40000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_b')::uuid)$$,
  '23505', null, 'existing request cannot switch Doctors silently');
select throws_ok($$select * from public.request_review_with_preference(
  '40000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_c')::uuid)$$,
  '42501', null, 'pending Doctor is ineligible');
select ok(not has_function_privilege('authenticated',
  'public.assign_review_case(uuid,text,text)', 'EXECUTE'),
  'Patient selection does not grant assignment authority');

select set_config('request.jwt.claims',
  '{"sub":"user_prefpatientb","role":"authenticated"}', true);
select throws_ok($$select * from public.request_review_with_preference(
  '40000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_b')::uuid)$$,
  '42501', null, 'another Patient cannot request review of this screening');

set local role service_role;
select public.set_doctor_verification('user_prefdoctora', 'suspended',
  'test-operator');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_prefpatienta","role":"authenticated"}', true);
select throws_ok($$select * from public.request_review_with_preference(
  '40000000-0000-4000-8000-000000000002',
  current_setting('test.doctor_a')::uuid)$$,
  '42501', null, 'suspended Doctor is ineligible');

select * from finish(true);
select '14 pgTAP assertions passed' as test_result;
rollback;
