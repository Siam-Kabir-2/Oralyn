-- Development-only; all synthetic rows and pgtap setup roll back.
-- Run after 202611190001_patient_profiles.sql.
begin;
create extension if not exists pgtap;
select plan(12);

select has_table('public', 'patient_profiles',
  'Patient identity cache exists');
select has_column('public', 'patient_profiles', 'display_name',
  'display name has its own field');
select has_column('public', 'patient_profiles', 'verified_email',
  'only verified primary email is cached');
select has_column('public', 'patient_profiles', 'clerk_created_at',
  'Clerk account creation time is distinct from Supabase provisioning');
select ok(has_table_privilege('authenticated', 'public.patient_profiles', 'SELECT'),
  'authenticated Patient may select an authorized profile');
select ok(not has_table_privilege('authenticated', 'public.patient_profiles', 'INSERT'),
  'mobile client cannot insert identity fields');
select ok(not has_table_privilege('authenticated', 'public.patient_profiles', 'UPDATE'),
  'mobile client cannot edit verified identity fields');
select ok(not has_table_privilege('anon', 'public.patient_profiles', 'SELECT'),
  'anonymous client cannot read Patient profiles');

set local role service_role;
insert into public.profiles(clerk_user_id, application_role) values
  ('user_profiletesta', 'patient'), ('user_profiletestb', 'patient'),
  ('user_profiletestadmin', 'admin');
insert into public.patient_profiles(
  clerk_user_id, display_name, verified_email, clerk_created_at, synced_at
) values
  ('user_profiletesta', 'Synthetic Patient A', 'a@example.test', now(), now()),
  ('user_profiletestb', 'Synthetic Patient B', 'b@example.test', now(), now());

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_profiletesta","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.patient_profiles$$,
  array[1::bigint], 'Patient sees only their own profile');
select set_config('request.jwt.claims',
  '{"sub":"user_unrelatedtest","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.patient_profiles$$,
  array[0::bigint], 'unrelated account sees no Patient profile');
select set_config('request.jwt.claims',
  '{"sub":"user_profiletestadmin","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.patient_profiles$$,
  array[0::bigint], 'Admin cannot bypass RLS from the mobile client');

set local role service_role;
update public.profiles set application_role = 'doctor'
  where clerk_user_id = 'user_profiletesta';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"user_profiletesta","role":"authenticated"}', true);
select results_eq($$select count(*)::bigint from public.patient_profiles$$,
  array[0::bigint], 'Doctor transition removes Patient-profile read access');

select * from finish(true);
select '12 pgTAP assertions passed' as test_result;
rollback;
