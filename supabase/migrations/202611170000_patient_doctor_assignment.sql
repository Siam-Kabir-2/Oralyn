-- A Patient may directly assign one saved screening to a verified Doctor.
-- The verified Clerk subject and Doctor directory UUID are checked in SQL.
begin;

alter table public.case_audit_events
  drop constraint case_audit_event_kind;
alter table public.case_audit_events
  add constraint case_audit_event_kind check (
    event_kind in ('case_opened', 'draft_saved', 'review_submitted', 'patient_assigned')
  );

create function public.request_and_assign_doctor(
  p_screening_id uuid, p_doctor_directory_id uuid
) returns table (
  id uuid, status text, preferred_doctor_directory_id uuid, assignment_id uuid
) language plpgsql security definer set search_path = '' as $$
declare
  v_patient_id text := (select auth.jwt()->>'sub');
  v_doctor_id text;
  v_request_id uuid;
  v_request_status text;
  v_preferred_id uuid;
  v_assignment_id uuid;
begin
  if v_patient_id is null or p_doctor_directory_id is null then
    raise exception 'case is not eligible' using errcode = '42501';
  end if;
  perform 1 from public.screenings s
    join public.profiles p on p.clerk_user_id = s.patient_id
    where s.id = p_screening_id and s.patient_id = v_patient_id
      and s.lifecycle_state = 'saved' and p.application_role = 'patient'
    for share of s;
  if not found then
    raise exception 'case is not eligible' using errcode = '42501';
  end if;
  select dp.clerk_user_id into v_doctor_id
    from public.doctor_profiles dp
    join public.profiles p on p.clerk_user_id = dp.clerk_user_id
    where dp.directory_id = p_doctor_directory_id
      and dp.verification_state = 'verified'
      and p.application_role = 'doctor'
    for share of dp;
  if v_doctor_id is null then
    raise exception 'Doctor is not eligible' using errcode = '42501';
  end if;

  insert into public.review_requests(
    screening_id, patient_id, preferred_doctor_directory_id
  ) values (p_screening_id, v_patient_id, p_doctor_directory_id)
  on conflict (screening_id) do nothing;
  select rr.id, rr.status, rr.preferred_doctor_directory_id
    into v_request_id, v_request_status, v_preferred_id
    from public.review_requests rr where rr.screening_id = p_screening_id
    for update;
  if v_request_id is null then
    raise exception 'case is not eligible' using errcode = '42501';
  end if;
  if exists (select 1 from public.case_assignments ca
      where ca.review_request_id = v_request_id and ca.revoked_at is not null) then
    raise exception 'revoked case requires operator review'
      using errcode = '42501';
  end if;
  if v_preferred_id is distinct from p_doctor_directory_id then
    if v_preferred_id is null and v_request_status = 'pending_assignment' then
      update public.review_requests rr
        set preferred_doctor_directory_id = p_doctor_directory_id
        where rr.id = v_request_id;
    else
      raise exception 'case already selected for another Doctor'
        using errcode = '23505';
    end if;
  end if;

  if v_request_status = 'pending_assignment' then
    insert into public.case_assignments as ca(
      review_request_id, doctor_id, assigned_by
    ) values (v_request_id, v_doctor_id, 'patient-consent:' || v_patient_id)
    returning ca.id into v_assignment_id;
    update public.review_requests rr set status = 'assigned'
      where rr.id = v_request_id;
    insert into public.case_audit_events(
      assignment_id, actor_id, event_kind
    ) values (v_assignment_id, v_patient_id, 'patient_assigned');
    v_request_status := 'assigned';
  elsif v_request_status in ('assigned', 'in_review', 'reviewed') then
    select ca.id into v_assignment_id from public.case_assignments ca
      where ca.review_request_id = v_request_id
        and ca.doctor_id = v_doctor_id and ca.revoked_at is null;
    if v_assignment_id is null then
      raise exception 'case assignment is not available'
        using errcode = '23505';
    end if;
  else
    raise exception 'case is not assignable' using errcode = '23505';
  end if;
  return query select v_request_id, v_request_status,
    p_doctor_directory_id, v_assignment_id;
end;
$$;
revoke all on function public.request_and_assign_doctor(uuid,uuid)
  from public, anon;
grant execute on function public.request_and_assign_doctor(uuid,uuid)
  to authenticated;

commit;
