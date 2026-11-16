-- Private, case-scoped text messaging. Apply after Phase 3C and Doctor preference.
begin;

create schema if not exists oralyn_private;
revoke all on schema oralyn_private from public, anon, authenticated;

create table oralyn_private.case_messages (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.case_assignments(id) on delete restrict,
  sender_id text not null references public.profiles(clerk_user_id) on delete restrict,
  client_message_id uuid not null,
  body text not null,
  created_at timestamptz not null default now(),
  constraint case_message_body_length check (char_length(trim(body)) between 1 and 2000),
  constraint case_message_retry unique (assignment_id, sender_id, client_message_id)
);
create index case_messages_page
  on oralyn_private.case_messages(assignment_id, created_at desc, id desc);
create index case_messages_sender
  on oralyn_private.case_messages(sender_id);
alter table oralyn_private.case_messages enable row level security;
revoke all on oralyn_private.case_messages from public, anon, authenticated;
grant usage on schema oralyn_private to service_role;
grant select on oralyn_private.case_messages to service_role;

-- Patients retain their own message history after revocation. A Doctor loses
-- access immediately when the assignment is revoked or verification changes.
create function oralyn_private.can_read_case_messages(p_assignment_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.case_assignments ca
    join public.review_requests rr on rr.id = ca.review_request_id
    join public.screenings s on s.id = rr.screening_id
    join public.profiles patient on patient.clerk_user_id = rr.patient_id
    join public.doctor_profiles dp on dp.clerk_user_id = ca.doctor_id
    join public.profiles doctor on doctor.clerk_user_id = ca.doctor_id
    where ca.id = p_assignment_id and s.lifecycle_state = 'saved'
      and (
        (rr.patient_id = (select auth.jwt()->>'sub')
          and patient.application_role = 'patient')
        or (ca.doctor_id = (select auth.jwt()->>'sub')
          and ca.revoked_at is null and dp.verification_state = 'verified'
          and doctor.application_role = 'doctor')
      )
  );
$$;
revoke all on function oralyn_private.can_read_case_messages(uuid)
  from public, anon, authenticated;

create function public.my_case_conversations()
returns table (
  assignment_id uuid, screening_id uuid, doctor_name text, status text,
  assigned_at timestamptz, is_active boolean, last_message_at timestamptz,
  last_message_preview text
) language sql stable security definer set search_path = '' as $$
  select ca.id, rr.screening_id, dp.display_name, rr.status, ca.assigned_at,
    ca.revoked_at is null, latest.created_at, latest.body
  from public.case_assignments ca
  join public.review_requests rr on rr.id = ca.review_request_id
  join public.doctor_profiles dp on dp.clerk_user_id = ca.doctor_id
  left join lateral (
    select m.created_at, m.body from oralyn_private.case_messages m
    where m.assignment_id = ca.id
    order by m.created_at desc, m.id desc limit 1
  ) latest on true
  where oralyn_private.can_read_case_messages(ca.id)
  order by coalesce(latest.created_at, ca.assigned_at) desc, ca.id desc
  limit 100;
$$;
revoke all on function public.my_case_conversations() from public, anon;
grant execute on function public.my_case_conversations() to authenticated;

create function public.case_messages_page(
  p_assignment_id uuid, p_before_created_at timestamptz default null,
  p_before_id uuid default null, p_limit integer default 50
) returns table (
  id uuid, body text, sender_is_self boolean, created_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not oralyn_private.can_read_case_messages(p_assignment_id) then
    raise exception 'case is not available' using errcode = '42501';
  end if;
  if (p_before_created_at is null) <> (p_before_id is null)
     or p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid page request' using errcode = '22023';
  end if;
  return query
    select m.id, m.body, m.sender_id = (select auth.jwt()->>'sub'), m.created_at
    from oralyn_private.case_messages m
    where m.assignment_id = p_assignment_id
      and (p_before_created_at is null
        or (m.created_at, m.id) < (p_before_created_at, p_before_id))
    order by m.created_at desc, m.id desc limit p_limit;
end;
$$;
revoke all on function public.case_messages_page(uuid,timestamptz,uuid,integer)
  from public, anon;
grant execute on function public.case_messages_page(uuid,timestamptz,uuid,integer)
  to authenticated;

create function public.send_case_message(
  p_assignment_id uuid, p_client_message_id uuid, p_body text
) returns table (
  id uuid, body text, sender_is_self boolean, created_at timestamptz
) language plpgsql security definer set search_path = '' as $$
declare v_message oralyn_private.case_messages%rowtype;
declare v_sender text := (select auth.jwt()->>'sub');
begin
  if p_client_message_id is null or p_body is null
     or char_length(trim(p_body)) not between 1 and 2000 then
    raise exception 'invalid message' using errcode = '22023';
  end if;
  -- This row lock serializes message creation with assignment revocation.
  perform 1 from public.case_assignments ca
    join public.review_requests rr on rr.id = ca.review_request_id
    join public.doctor_profiles dp on dp.clerk_user_id = ca.doctor_id
    join public.profiles doctor on doctor.clerk_user_id = ca.doctor_id
    where ca.id = p_assignment_id and ca.revoked_at is null
      and rr.status in ('assigned', 'in_review', 'reviewed')
      and dp.verification_state = 'verified'
      and doctor.application_role = 'doctor'
    for share of ca;
  if not found or not oralyn_private.can_read_case_messages(p_assignment_id) then
    raise exception 'case is not available' using errcode = '42501';
  end if;
  insert into oralyn_private.case_messages(
    assignment_id, sender_id, client_message_id, body
  ) values (p_assignment_id, v_sender, p_client_message_id, trim(p_body))
  on conflict (assignment_id, sender_id, client_message_id) do nothing
  returning * into v_message;
  if v_message.id is null then
    select * into v_message from oralyn_private.case_messages m
      where m.assignment_id = p_assignment_id and m.sender_id = v_sender
        and m.client_message_id = p_client_message_id;
    if v_message.body is distinct from trim(p_body) then
      raise exception 'message retry conflict' using errcode = '23505';
    end if;
  end if;
  return query select v_message.id, v_message.body, true, v_message.created_at;
end;
$$;
revoke all on function public.send_case_message(uuid,uuid,text) from public, anon;
grant execute on function public.send_case_message(uuid,uuid,text)
  to authenticated;

commit;
