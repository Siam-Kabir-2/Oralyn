-- Patient identity cache sourced only from Clerk by the FastAPI server.
-- Apply after 202611130001_doctor_onboarding.sql in the Oralyn development project.
begin;

create table public.patient_profiles (
  clerk_user_id text primary key
    references public.profiles(clerk_user_id) on delete restrict,
  display_name text,
  verified_email text,
  clerk_created_at timestamptz,
  synced_at timestamptz,
  constraint patient_display_name_length check (
    display_name is null or char_length(display_name) between 2 and 160
  ),
  constraint patient_verified_email_length check (
    verified_email is null or char_length(verified_email) between 3 and 320
  )
);

-- Preserve existing Patient rows. Identity fields remain null until trusted
-- Clerk synchronization runs; no values are guessed from a screening.
insert into public.patient_profiles(clerk_user_id)
select clerk_user_id from public.profiles where application_role = 'patient'
on conflict (clerk_user_id) do nothing;

alter table public.patient_profiles enable row level security;

create policy patient_profiles_select_self on public.patient_profiles
  for select to authenticated
  using (
    clerk_user_id = (select auth.jwt()->>'sub')
    and exists (
      select 1 from public.profiles p
      where p.clerk_user_id = patient_profiles.clerk_user_id
        and p.application_role = 'patient'
    )
  );

revoke all on public.patient_profiles from public, anon, authenticated;
grant select on public.patient_profiles to authenticated;
grant all on public.patient_profiles to service_role;

-- New profiles created after this migration are provisioned by the same
-- server-only sync path. No mobile client can insert or edit identity fields.
commit;
