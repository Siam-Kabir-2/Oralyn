-- Apply after Doctor onboarding. Selection is a preference, not an assignment.
begin;

alter table public.doctor_profiles
  add column directory_id uuid not null default gen_random_uuid();
create unique index doctor_profiles_directory_id
  on public.doctor_profiles(directory_id);

alter table public.review_requests
  add column preferred_doctor_directory_id uuid
    references public.doctor_profiles(directory_id) on delete restrict;
create index review_requests_preferred_doctor
  on public.review_requests(preferred_doctor_directory_id)
  where preferred_doctor_directory_id is not null;

create function public.request_review_with_preference(
  p_screening_id uuid, p_doctor_directory_id uuid
) returns table(id uuid, status text, preferred_doctor_directory_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_doctor_id text;
begin
  if not exists (
    select 1 from public.screenings s
    join public.profiles p on p.clerk_user_id = s.patient_id
    where s.id = p_screening_id and s.lifecycle_state = 'saved'
      and s.patient_id = (select auth.jwt()->>'sub')
      and p.application_role = 'patient'
  ) then
    raise exception 'screening is not eligible' using errcode = '42501';
  end if;

  select dp.clerk_user_id into v_doctor_id
  from public.doctor_profiles dp
  join public.profiles p on p.clerk_user_id = dp.clerk_user_id
  where dp.directory_id = p_doctor_directory_id
    and dp.verification_state = 'verified'
    and p.application_role = 'doctor'
  for share of dp;
  if v_doctor_id is null then
    raise exception 'doctor is not eligible' using errcode = '42501';
  end if;

  insert into public.review_requests(
    screening_id, patient_id, preferred_doctor_directory_id
  ) values (
    p_screening_id, (select auth.jwt()->>'sub'), p_doctor_directory_id
  ) on conflict (screening_id) do nothing;

  if exists (
    select 1 from public.review_requests rr
    where rr.screening_id = p_screening_id
      and rr.patient_id = (select auth.jwt()->>'sub')
      and rr.preferred_doctor_directory_id is distinct from p_doctor_directory_id
  ) then
    raise exception 'review request already exists for a different Doctor'
      using errcode = '23505';
  end if;

  return query
    select rr.id, rr.status, rr.preferred_doctor_directory_id
    from public.review_requests rr
    where rr.screening_id = p_screening_id
      and rr.patient_id = (select auth.jwt()->>'sub');
end;
$$;
revoke all on function public.request_review_with_preference(uuid,uuid)
  from public, anon;
grant execute on function public.request_review_with_preference(uuid,uuid)
  to authenticated;

commit;
