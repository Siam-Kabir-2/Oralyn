-- Run only in development after the Phase 3C migration. Rolls back test rows.
begin;
create extension if not exists pgtap;
select plan(26);

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
insert into public.image_assets(
  screening_id, owner_id, asset_kind, object_path,
  content_type, byte_size, sha256
) values
  ('30000000-0000-4000-8000-000000000001', 'user_p3ca', 'original',
   'user_p3ca/30000000-0000-4000-8000-000000000001/original.png',
   'image/png', 1, repeat('0', 64)),
  ('30000000-0000-4000-8000-000000000002', 'user_p3cb', 'original',
   'user_p3cb/30000000-0000-4000-8000-000000000002/original.png',
   'image/png', 1, repeat('1', 64));
insert into storage.objects(bucket_id, name) values
  ('screening-images',
   'user_p3ca/30000000-0000-4000-8000-000000000001/original.png'),
  ('screening-images',
   'user_p3cb/30000000-0000-4000-8000-000000000002/original.png');

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
select ok(not has_function_privilege('authenticated',
  'public.assign_review_case(uuid,text,text)', 'EXECUTE'),
  'public cannot assign a Doctor');
select ok(not has_function_privilege('authenticated',
  'public.revoke_review_assignment(uuid,text)', 'EXECUTE'),
  'public cannot revoke an assignment');
select throws_ok(
  $$insert into public.case_assignments(review_request_id, doctor_id, assigned_by)
    values (gen_random_uuid(), 'user_d3ca', 'self-assigned')$$,
  '42501', null, 'patient cannot directly assign a case');
select is(
  (select status from public.request_screening_review(
    '30000000-0000-4000-8000-000000000001')),
  'pending_assignment'::text, 'owner can request review');
select results_eq(
  $$select count(*)::bigint from storage.objects
    where bucket_id = 'screening-images'$$,
  array[1::bigint], 'patient sees only their private Storage object');
select is_empty(
  $$select name from storage.objects
    where name like 'user_p3cb/%'$$,
  'patient cannot read another patient Storage object');

set local role service_role;
insert into public.review_requests(screening_id, patient_id)
values ('30000000-0000-4000-8000-000000000002', 'user_p3cb');
select throws_ok(
  $$select public.assign_review_case(
    (select id from public.review_requests
      where screening_id = '30000000-0000-4000-8000-000000000002'),
    'user_d3cb', 'development-operator')$$,
  'P0001', 'doctor is not verified',
  'trusted assignment rejects an unverified Doctor');
select public.assign_review_case(
  (select id from public.review_requests
    where screening_id = '30000000-0000-4000-8000-000000000001'),
  'user_d3ca', 'development-operator');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_d3ca","role":"authenticated"}', true);
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  true, 'verified assigned Doctor can access case');
select is(public.can_review_screening('30000000-0000-4000-8000-000000000002'),
  false, 'verified unassigned Doctor cannot access another case');
select results_eq('select count(*)::bigint from public.screenings',
  array[1::bigint], 'Doctor sees only assigned case');
select results_eq(
  $$select count(*)::bigint from storage.objects
    where bucket_id = 'screening-images'$$,
  array[1::bigint], 'assigned Doctor sees only the assigned private object');
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
select is_empty(
  $$select name from storage.objects where bucket_id = 'screening-images'$$,
  'suspended Doctor loses private Storage access');

set local role service_role;
update public.doctor_profiles set verification_state = 'verified'
where clerk_user_id = 'user_d3ca';
update public.case_assignments set revoked_at = now(), revoked_by = 'development-operator'
where doctor_id = 'user_d3ca';
set local role authenticated;
select is(public.can_review_screening('30000000-0000-4000-8000-000000000001'),
  false, 'assignment revocation takes effect without token refresh');
select is_empty(
  $$select name from storage.objects where bucket_id = 'screening-images'$$,
  'revoked Doctor loses private Storage access');

select * from finish();
rollback;
