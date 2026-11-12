-- Run only in development after the Phase 3C migration. Rolls back test rows.
begin;
create extension if not exists pgtap;
select plan(17);

set local role service_role;
insert into public.profiles(clerk_user_id, application_role)
values ('user_p3ca', 'patient'), ('user_p3cb', 'patient'),
       ('user_d3ca', 'doctor'), ('user_d3cb', 'doctor');
insert into public.doctor_profiles(
  clerk_user_id, display_name, specialization, qualification,
  registration_reference, verification_state, verified_at, verified_by
) values
  ('user_d3ca', 'Synthetic Doctor A', 'Oral medicine', 'Synthetic degree',
   'TEST-001', 'verified', now(), 'development-operator'),
  ('user_d3cb', 'Synthetic Doctor B', 'Oral medicine', 'Synthetic degree',
   'TEST-002', 'pending', null, null);
insert into public.screenings(id, patient_id, idempotency_key) values
  ('30000000-0000-4000-8000-000000000001', 'user_p3ca', 'phase3c-owner-one'),
  ('30000000-0000-4000-8000-000000000002', 'user_p3cb', 'phase3c-owner-two');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_p3ca","role":"authenticated"}', true);
select results_eq(
  'select count(*)::bigint from public.screenings', array[1::bigint],
  'patient sees only owned screening');
select ok(not has_table_privilege('authenticated', 'public.profiles', 'UPDATE'),
  'patient cannot update trusted role');
select ok(not has_function_privilege('authenticated',
  'public.enroll_doctor_candidate(text,text,text,text,text,text)', 'EXECUTE'),
  'public cannot enroll a Doctor');
select ok(not has_function_privilege('authenticated',
  'public.set_doctor_verification(text,text,text)', 'EXECUTE'),
  'public cannot verify a Doctor');
select is(
  (select status from public.request_screening_review(
    '30000000-0000-4000-8000-000000000001')),
  'pending_assignment'::text, 'owner can request review');

set local role service_role;
insert into public.case_assignments(review_request_id, doctor_id, assigned_by)
select id, 'user_d3ca', 'development-operator' from public.review_requests
where screening_id = '30000000-0000-4000-8000-000000000001';
update public.review_requests set status = 'assigned'
where screening_id = '30000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_d3ca","role":"authenticated"}', true);
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  true, 'verified assigned Doctor can access case');
select is(public.can_review_screening('30000000-0000-4000-8000-000000000002'),
  false, 'verified unassigned Doctor cannot access another case');
select results_eq('select count(*)::bigint from public.screenings',
  array[1::bigint], 'Doctor sees only assigned case');
select lives_ok(
  $$select public.record_case_access(
    (select id from public.case_assignments where doctor_id = 'user_d3ca'))$$,
  'authorized Doctor case access can be audited');
select is((select review_state from public.save_doctor_review(
  (select id from public.case_assignments where doctor_id = 'user_d3ca'),
  0, 'Synthetic observation', 'Synthetic recommendation', 'Review later', false)),
  'draft'::text, 'assigned Doctor can save a draft');
select throws_ok(
  $$select * from public.save_doctor_review(
    (select id from public.case_assignments where doctor_id = 'user_d3ca'),
    0, 'Stale observation', 'Stale recommendation', 'Review later', false)$$,
  '23505', null, 'stale review version is rejected');
select is((select review_state from public.save_doctor_review(
  (select id from public.case_assignments where doctor_id = 'user_d3ca'),
  1, 'Synthetic observation', 'Synthetic recommendation', 'Review later', true)),
  'submitted'::text, 'Doctor can submit the review once');
select ok(not has_function_privilege('anon',
  'public.save_doctor_review(uuid,integer,text,text,text,boolean)', 'EXECUTE'),
  'anonymous users cannot submit reviews');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_p3ca","role":"authenticated"}', true);
select is((select count(*)::bigint from public.my_doctor_feedback()),
  1::bigint, 'owner can read finalized Doctor feedback');
select set_config('request.jwt.claims',
  '{"sub":"user_d3cb","role":"authenticated"}', true);
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  false, 'unverified Doctor cannot access case');

set local role service_role;
update public.doctor_profiles set verification_state = 'suspended'
where clerk_user_id = 'user_d3ca';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_d3ca","role":"authenticated"}', true);
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  false, 'suspension takes effect without token refresh');

set local role service_role;
update public.doctor_profiles set verification_state = 'verified'
where clerk_user_id = 'user_d3ca';
update public.case_assignments set revoked_at = now(), revoked_by = 'development-operator'
where doctor_id = 'user_d3ca';
set local role authenticated;
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  false, 'assignment revocation takes effect without token refresh');

select * from finish();
rollback;
