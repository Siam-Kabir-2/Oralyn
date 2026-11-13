-- Apply after Phase 3C. This migration does not grant client-side role writes.
begin;
alter table public.profiles drop constraint profiles_application_role;
alter table public.profiles add constraint profiles_application_role
  check (application_role in ('patient', 'doctor', 'admin'));

alter table public.doctor_profiles add column workplace text;
alter table public.doctor_profiles add constraint doctor_workplace_length
  check (workplace is null or char_length(trim(workplace)) between 2 and 160);

create function public.apply_doctor_candidate(
  p_doctor_id text, p_name text, p_specialization text,
  p_qualification text, p_registration text, p_workplace text
) returns void language plpgsql security definer set search_path = '' as $$
declare v_role text;
begin
  if p_doctor_id !~ '^user_[A-Za-z0-9]+$' then
    raise exception 'invalid Clerk subject' using errcode = '22023';
  end if;
  select application_role into v_role from public.profiles
    where clerk_user_id = p_doctor_id for update;
  if v_role is null or v_role <> 'patient' then
    raise exception 'account is not eligible for a new application'
      using errcode = '42501';
  end if;
  insert into public.doctor_profiles(
    clerk_user_id, display_name, specialization, qualification,
    registration_reference, workplace
  ) values (
    p_doctor_id, trim(p_name), trim(p_specialization), trim(p_qualification),
    trim(p_registration), trim(p_workplace)
  );
  update public.profiles set application_role = 'doctor'
    where clerk_user_id = p_doctor_id;
end;
$$;
revoke all on function public.apply_doctor_candidate(text,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.apply_doctor_candidate(text,text,text,text,text,text)
  to service_role;

create function public.update_my_doctor_profile(
  p_doctor_id text, p_name text, p_specialization text,
  p_qualification text, p_registration text, p_workplace text
) returns text language plpgsql security definer set search_path = '' as $$
declare v_state text;
begin
  if not exists (select 1 from public.profiles
    where clerk_user_id = p_doctor_id and application_role = 'doctor') then
    raise exception 'Doctor account required' using errcode = '42501';
  end if;
  update public.doctor_profiles
  set display_name = trim(p_name), specialization = trim(p_specialization),
      qualification = trim(p_qualification),
      registration_reference = trim(p_registration), workplace = trim(p_workplace),
      verification_state = case
        when verification_state = 'verified' and (
          display_name is distinct from trim(p_name) or
          specialization is distinct from trim(p_specialization) or
          qualification is distinct from trim(p_qualification) or
          registration_reference is distinct from trim(p_registration) or
          workplace is distinct from trim(p_workplace)
        ) then 'pending' else verification_state end,
      verified_at = case when verification_state = 'verified' and (
          display_name is distinct from trim(p_name) or
          specialization is distinct from trim(p_specialization) or
          qualification is distinct from trim(p_qualification) or
          registration_reference is distinct from trim(p_registration) or
          workplace is distinct from trim(p_workplace)
        ) then null else verified_at end,
      verified_by = case when verification_state = 'verified' and (
          display_name is distinct from trim(p_name) or
          specialization is distinct from trim(p_specialization) or
          qualification is distinct from trim(p_qualification) or
          registration_reference is distinct from trim(p_registration) or
          workplace is distinct from trim(p_workplace)
        ) then null else verified_by end
  where clerk_user_id = p_doctor_id
    and verification_state in ('pending', 'verified')
  returning verification_state into v_state;
  if not found then
    raise exception 'Doctor profile cannot be edited' using errcode = '42501';
  end if;
  return v_state;
end;
$$;
revoke all on function public.update_my_doctor_profile(text,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.update_my_doctor_profile(text,text,text,text,text,text)
  to service_role;

commit;
