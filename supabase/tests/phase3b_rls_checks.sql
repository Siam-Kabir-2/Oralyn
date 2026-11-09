-- Run in a non-production Supabase database after applying migrations.
-- These assertions use transaction-local JWT claims and roll back all data.
begin;

create extension if not exists pgtap;
select plan(8);

set local role service_role;
insert into public.profiles(clerk_user_id)
values ('user_rls_a'), ('user_rls_b');
insert into public.screenings(id, patient_id, idempotency_key)
values
  ('00000000-0000-4000-8000-000000000001', 'user_rls_a', 'rls-check-owner-a'),
  ('00000000-0000-4000-8000-000000000002', 'user_rls_b', 'rls-check-owner-b');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"user_rls_a","role":"authenticated"}',
  true
);

select results_eq(
  'select count(*)::bigint from public.screenings',
  array[1::bigint],
  'owner sees only their screening'
);
select results_eq(
  $$select patient_id from public.screenings$$,
  array['user_rls_a'::text],
  'owner identity is derived from Clerk sub'
);
select is_empty(
  $$select * from public.screenings where patient_id = 'user_rls_b'$$,
  'cross-user screening access is denied'
);
select is_empty(
  $$select * from public.image_assets where owner_id = 'user_rls_b'$$,
  'cross-user asset metadata access is denied'
);
select throws_ok(
  $$insert into public.screenings(patient_id, idempotency_key)
    values ('user_rls_a', 'unauthorized-write')$$,
  '42501',
  null,
  'authenticated users cannot forge screenings'
);
select throws_ok(
  $$delete from public.screenings where patient_id = 'user_rls_a'$$,
  '42501',
  null,
  'authenticated users cannot directly delete screenings'
);
set local role service_role;
select is(
  (select count(*) from storage.buckets where id = 'screening-images' and not public),
  1::bigint,
  'screening bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'screening-images'),
  10485760::bigint,
  'storage bucket enforces ten megabytes'
);

select * from finish();
rollback;
