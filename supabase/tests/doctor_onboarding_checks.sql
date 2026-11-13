-- Development-only, transaction-rolled-back checks. Run after the Doctor
-- onboarding migration. Never use identifiable accounts or production data.
begin;
create extension if not exists pgtap;
select plan(13);

set local role service_role;
insert into public.profiles(clerk_user_id, application_role)
values ('user_onboardtest', 'patient'), ('user_admintest', 'admin');
select is((select application_role from public.profiles
  where clerk_user_id = 'user_admintest'), 'admin'::text,
  'trusted role column accepts Admin provisioning');

select public.apply_doctor_candidate(
  'user_onboardtest', 'Synthetic Doctor', 'Oral medicine',
  'Synthetic degree', 'TEST-ONBOARD', 'Test institution');
select is((select application_role from public.profiles
  where clerk_user_id = 'user_onboardtest'), 'doctor'::text,
  'application creates a Doctor role through trusted RPC');
select is((select verification_state from public.doctor_profiles
  where clerk_user_id = 'user_onboardtest'), 'pending'::text,
  'new applicant remains pending');
select is((select workplace from public.doctor_profiles
  where clerk_user_id = 'user_onboardtest'), 'Test institution'::text,
  'workplace is persisted');
select throws_ok($$select public.apply_doctor_candidate(
  'user_onboardtest', 'Synthetic Doctor', 'Oral medicine',
  'Synthetic degree', 'TEST-ONBOARD', 'Test institution')$$,
  '42501', null, 'duplicate application is rejected');

set local role authenticated;
select ok(not has_function_privilege('authenticated',
  'public.apply_doctor_candidate(text,text,text,text,text,text)', 'EXECUTE'),
  'client cannot invoke application RPC');
select ok(not has_function_privilege('authenticated',
  'public.update_my_doctor_profile(text,text,text,text,text,text)', 'EXECUTE'),
  'client cannot invoke profile-edit RPC');
select ok(not has_table_privilege('authenticated', 'public.profiles', 'UPDATE'),
  'client cannot assign its own Admin role');
select set_config('request.jwt.claims',
  '{"sub":"user_onboardtest","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.doctor_profiles$$,
  array[1::bigint], 'Doctor reads own professional record');
select set_config('request.jwt.claims',
  '{"sub":"user_unrelatedtest","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.doctor_profiles$$,
  array[0::bigint], 'other user cannot read applicant record');

set local role service_role;
select public.set_doctor_verification('user_onboardtest', 'verified',
  'development-operator');
select is((select verification_state from public.doctor_profiles
  where clerk_user_id = 'user_onboardtest'), 'verified'::text,
  'trusted operator can verify applicant');
select public.update_my_doctor_profile(
  'user_onboardtest', 'Synthetic Doctor', 'Oral medicine',
  'Synthetic degree', 'TEST-ONBOARD', 'Changed institution');
select is((select verification_state from public.doctor_profiles
  where clerk_user_id = 'user_onboardtest'), 'pending'::text,
  'professional edit requires re-verification');
select ok((select verified_at is null and verified_by is null
  from public.doctor_profiles where clerk_user_id = 'user_onboardtest'),
  'credential edit clears prior verification metadata');

select * from finish();
rollback;
