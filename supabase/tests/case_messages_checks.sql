-- Development-only Patient/Doctor messaging checks. No rows persist.
begin;
create extension if not exists pgtap;
select plan(20);

set local role service_role;
insert into public.profiles(clerk_user_id, application_role) values
  ('user_chatpatienta', 'patient'), ('user_chatpatientb', 'patient'),
  ('user_chatdoctora', 'doctor'), ('user_chatdoctorb', 'doctor');
insert into public.doctor_profiles(
  clerk_user_id, display_name, specialization, qualification,
  registration_reference, verification_state, verified_at, verified_by
) values
  ('user_chatdoctora', 'Synthetic Doctor A', 'Oral medicine',
   'Synthetic degree', 'TEST-CHAT-A', 'verified', now(), 'test-operator'),
  ('user_chatdoctorb', 'Synthetic Doctor B', 'Oral medicine',
   'Synthetic degree', 'TEST-CHAT-B', 'verified', now(), 'test-operator');
insert into public.screenings(id, patient_id, idempotency_key)
values ('60000000-0000-4000-8000-000000000001',
  'user_chatpatienta', 'chat-owner-key-0001');
select set_config('test.doctor_a', (select directory_id::text
  from public.doctor_profiles where clerk_user_id='user_chatdoctora'), true);

select ok(to_regclass('oralyn_private.case_messages') is not null,
  'messages live in an unexposed private schema');
select ok(not has_table_privilege('anon',
  'oralyn_private.case_messages', 'SELECT'),
  'anonymous callers have no direct message table access');
select ok(not has_table_privilege('authenticated',
  'oralyn_private.case_messages', 'SELECT'),
  'signed-in clients have no direct message table access');
select ok(not has_function_privilege('anon',
  'public.send_case_message(uuid,uuid,text)', 'EXECUTE'),
  'anonymous callers cannot send messages');
select ok(has_function_privilege('authenticated',
  'public.send_case_message(uuid,uuid,text)', 'EXECUTE'),
  'authenticated members can use the guarded message RPC');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_chatpatienta","role":"authenticated"}', true);
select public.request_and_assign_doctor(
  '60000000-0000-4000-8000-000000000001',
  current_setting('test.doctor_a')::uuid);
set local role service_role;
select set_config('test.assignment_id', (select ca.id::text
  from public.case_assignments ca join public.review_requests rr
    on rr.id=ca.review_request_id
  where rr.screening_id='60000000-0000-4000-8000-000000000001'), true);
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_chatpatienta","role":"authenticated"}', true);
select is((select count(*)::bigint from public.my_case_conversations()),
  1::bigint, 'Patient sees the assigned conversation');
select is((select body from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000002', '  Synthetic question  ')),
  'Synthetic question'::text, 'Patient sends trimmed message text');
select is((select id from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000002', 'Synthetic question')),
  (select id from public.case_messages_page(
    current_setting('test.assignment_id')::uuid, null, null, 50) limit 1),
  'same client message id returns the same message');
set local role service_role;
select is((select count(*)::bigint from oralyn_private.case_messages),
  1::bigint, 'retry creates no duplicate message');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_chatpatienta","role":"authenticated"}', true);
select throws_ok($$select * from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000002', 'Different content')$$,
  '23505', null, 'same retry key cannot change message text');
select throws_ok($$select * from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000003', '   ')$$,
  '22023', null, 'blank message is rejected');

select set_config('request.jwt.claims',
  '{"sub":"user_chatpatientb","role":"authenticated"}', true);
select throws_ok($$select * from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)$$,
  '42501', null, 'unrelated Patient cannot read case messages');
select set_config('request.jwt.claims',
  '{"sub":"user_chatdoctora","role":"authenticated"}', true);
select is((select count(*)::bigint from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)),
  1::bigint, 'assigned Doctor can read the message');
select is((select sender_is_self from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50) limit 1),
  false, 'Doctor sees the Patient as the sender without Clerk ID');
select is((select body from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000004', 'Synthetic reply')),
  'Synthetic reply'::text, 'assigned Doctor can reply');
select set_config('request.jwt.claims',
  '{"sub":"user_chatdoctorb","role":"authenticated"}', true);
select throws_ok($$select * from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)$$,
  '42501', null, 'other verified Doctor cannot read this case');

set local role service_role;
select public.set_doctor_verification(
  'user_chatdoctora', 'suspended', 'test-operator');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_chatdoctora","role":"authenticated"}', true);
select throws_ok($$select * from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)$$,
  '42501', null, 'suspended Doctor loses message access');
set local role service_role;
select public.set_doctor_verification(
  'user_chatdoctora', 'verified', 'test-operator');
select public.revoke_review_assignment(
  current_setting('test.assignment_id')::uuid, 'test-operator');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_chatdoctora","role":"authenticated"}', true);
select throws_ok($$select * from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)$$,
  '42501', null, 'revoked Doctor loses message access');
select set_config('request.jwt.claims',
  '{"sub":"user_chatpatienta","role":"authenticated"}', true);
select is((select count(*)::bigint from public.case_messages_page(
  current_setting('test.assignment_id')::uuid, null, null, 50)),
  2::bigint, 'Patient retains earlier messages after revocation');
select throws_ok($$select * from public.send_case_message(
  current_setting('test.assignment_id')::uuid,
  '60000000-0000-4000-8000-000000000005', 'After revocation')$$,
  '42501', null, 'revoked case cannot receive new messages');

select * from finish(true);
select '20 pgTAP assertions passed' as test_result;
rollback;
