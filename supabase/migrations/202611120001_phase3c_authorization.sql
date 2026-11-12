-- Phase 3C foundation. Apply after 202611110001. Existing screenings are retained.
-- Administrative functions are executable only with the server role. The
-- operator must authenticate separately before invoking them; never expose
-- the service key or these functions to mobile clients.

alter table public.profiles
  add column application_role text not null default 'patient',
  add constraint profiles_application_role check (application_role in ('patient', 'doctor'));

create table public.doctor_profiles (
  clerk_user_id text primary key references public.profiles(clerk_user_id) on delete restrict,
  display_name text not null,
  specialization text not null,
  qualification text not null,
  registration_reference text not null,
  verification_state text not null default 'pending',
  verified_at timestamptz,
  verified_by text,
  updated_at timestamptz not null default now(),
  constraint doctor_display_name check (char_length(trim(display_name)) between 2 and 160),
  constraint doctor_specialization check (char_length(trim(specialization)) between 2 and 160),
  constraint doctor_qualification check (char_length(trim(qualification)) between 2 and 160),
  constraint doctor_registration check (char_length(trim(registration_reference)) between 3 and 160),
  constraint doctor_verification_state check (
    verification_state in ('pending', 'verified', 'suspended', 'rejected')
  ),
  constraint doctor_verified_metadata check (
    verification_state <> 'verified' or (verified_at is not null and verified_by is not null)
  )
);

create table public.review_requests (
  id uuid primary key default gen_random_uuid(),
  screening_id uuid not null references public.screenings(id) on delete restrict,
  patient_id text not null references public.profiles(clerk_user_id) on delete restrict,
  status text not null default 'pending_assignment',
  consent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint review_request_owner foreign key (screening_id, patient_id)
    references public.screenings(id, patient_id) on delete restrict,
  constraint review_request_status check (
    status in ('pending_assignment', 'assigned', 'in_review', 'reviewed', 'closed')
  ),
  constraint review_request_one_per_screening unique (screening_id)
);

create table public.case_assignments (
  id uuid primary key default gen_random_uuid(),
  review_request_id uuid not null references public.review_requests(id) on delete restrict,
  doctor_id text not null references public.doctor_profiles(clerk_user_id) on delete restrict,
  assigned_by text not null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by text,
  constraint assignment_authority check (assigned_by <> ''),
  constraint assignment_revocation_pair check ((revoked_at is null) = (revoked_by is null))
);
create unique index case_assignments_one_active
  on public.case_assignments(review_request_id) where revoked_at is null;
create index case_assignments_doctor_active
  on public.case_assignments(doctor_id, assigned_at desc) where revoked_at is null;
create index review_requests_patient_created
  on public.review_requests(patient_id, created_at desc);

create trigger doctor_profiles_set_updated_at
before update on public.doctor_profiles
for each row execute function public.set_updated_at();
create trigger review_requests_set_updated_at
before update on public.review_requests
for each row execute function public.set_updated_at();

-- SECURITY DEFINER uses an empty search path and table-qualified references.
-- Its boolean result reveals only whether the caller has this particular grant.
create function public.can_review_screening(p_screening_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.review_requests rr
    join public.case_assignments ca on ca.review_request_id = rr.id
    join public.doctor_profiles dp on dp.clerk_user_id = ca.doctor_id
    join public.profiles p on p.clerk_user_id = dp.clerk_user_id
    join public.screenings s on s.id = rr.screening_id
    where rr.screening_id = p_screening_id
      and rr.status in ('assigned', 'in_review', 'reviewed')
      and s.lifecycle_state = 'saved'
      and ca.revoked_at is null
      and ca.doctor_id = (select auth.jwt()->>'sub')
      and p.application_role = 'doctor'
      and dp.verification_state = 'verified'
  );
$$;
revoke all on function public.can_review_screening(uuid) from public, anon;
grant execute on function public.can_review_screening(uuid) to authenticated;

alter table public.doctor_profiles enable row level security;
alter table public.review_requests enable row level security;
alter table public.case_assignments enable row level security;

create policy doctor_profiles_select_self on public.doctor_profiles
  for select to authenticated using (clerk_user_id = (select auth.jwt()->>'sub'));
create policy review_requests_select_patient on public.review_requests
  for select to authenticated using (patient_id = (select auth.jwt()->>'sub'));
create policy review_requests_select_assigned_doctor on public.review_requests
  for select to authenticated using (public.can_review_screening(screening_id));
create policy assignments_select_assigned_doctor on public.case_assignments
  for select to authenticated using (
    doctor_id = (select auth.jwt()->>'sub')
    and revoked_at is null
    and exists (
      select 1 from public.review_requests rr
      where rr.id = review_request_id
        and public.can_review_screening(rr.screening_id)
    )
  );

-- Existing patient policies remain. Add narrow doctor SELECT policies.
create policy screenings_select_assigned_doctor on public.screenings
  for select to authenticated using (public.can_review_screening(id));
create policy screening_results_select_assigned_doctor on public.screening_results
  for select to authenticated using (public.can_review_screening(screening_id));
create policy image_assets_select_assigned_doctor on public.image_assets
  for select to authenticated using (public.can_review_screening(screening_id));
create policy screening_images_select_assigned_doctor on storage.objects
  for select to authenticated using (
    bucket_id = 'screening-images'
    and exists (
      select 1 from public.image_assets a
      where a.object_path = storage.objects.name
        and a.bucket_id = storage.objects.bucket_id
        and public.can_review_screening(a.screening_id)
    )
  );

revoke all on public.doctor_profiles, public.review_requests, public.case_assignments
  from anon, authenticated;
grant select on public.doctor_profiles, public.review_requests, public.case_assignments
  to authenticated;

-- Called only after FastAPI has verified the Clerk JWT. Conflict handling
-- never changes an existing role, including a previously verified Doctor.
create function public.ensure_patient_profile(p_user_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id !~ '^user_[A-Za-z0-9]+$' then
    raise exception 'invalid Clerk subject';
  end if;
  insert into public.profiles(clerk_user_id) values (p_user_id)
    on conflict (clerk_user_id) do nothing;
end;
$$;
revoke all on function public.ensure_patient_profile(text)
  from public, anon, authenticated;
grant execute on function public.ensure_patient_profile(text) to service_role;

-- Patient consent is checked against the verified Clerk subject at the SQL
-- boundary. A single request per screening prevents repeated active cases.
create function public.request_screening_review(p_screening_id uuid)
returns table(id uuid, status text)
language plpgsql security definer set search_path = '' as $$
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
  insert into public.review_requests(screening_id, patient_id)
  values (p_screening_id, (select auth.jwt()->>'sub'))
  on conflict (screening_id) do nothing;
  return query select rr.id, rr.status from public.review_requests rr
    where rr.screening_id = p_screening_id
      and rr.patient_id = (select auth.jwt()->>'sub');
end;
$$;
revoke all on function public.request_screening_review(uuid) from public, anon;
grant execute on function public.request_screening_review(uuid) to authenticated;

-- Administrative operations must be invoked by a trusted operator with the
-- service role. Public callers cannot provide an administrator identity.
create function public.set_doctor_verification(
  p_doctor_id text, p_state text, p_operator text
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_state not in ('verified', 'suspended', 'rejected')
     or nullif(trim(p_operator), '') is null then
    raise exception 'invalid verification transition';
  end if;
  update public.doctor_profiles
  set verification_state = p_state,
      verified_at = case when p_state = 'verified' then now() else verified_at end,
      verified_by = case when p_state = 'verified' then p_operator else verified_by end
  where clerk_user_id = p_doctor_id;
  if not found then raise exception 'doctor profile not found'; end if;
end;
$$;
revoke all on function public.set_doctor_verification(text,text,text)
  from public, anon, authenticated;
grant execute on function public.set_doctor_verification(text,text,text) to service_role;

create function public.enroll_doctor_candidate(
  p_doctor_id text, p_name text, p_specialization text,
  p_qualification text, p_registration text, p_operator text
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_doctor_id !~ '^user_[A-Za-z0-9]+$'
     or nullif(trim(p_operator), '') is null then
    raise exception 'invalid enrollment';
  end if;
  insert into public.profiles(clerk_user_id) values (p_doctor_id)
    on conflict (clerk_user_id) do nothing;
  update public.profiles set application_role = 'doctor'
    where clerk_user_id = p_doctor_id and application_role = 'patient';
  insert into public.doctor_profiles(
    clerk_user_id, display_name, specialization, qualification,
    registration_reference
  ) values (
    p_doctor_id, p_name, p_specialization, p_qualification, p_registration
  );
end;
$$;
revoke all on function public.enroll_doctor_candidate(text,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.enroll_doctor_candidate(text,text,text,text,text,text)
  to service_role;

create function public.assign_review_case(
  p_request_id uuid, p_doctor_id text, p_operator text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if nullif(trim(p_operator), '') is null then raise exception 'operator required'; end if;
  perform 1 from public.review_requests where id = p_request_id
    and status = 'pending_assignment' for update;
  if not found then raise exception 'request is not assignable'; end if;
  if not exists (
    select 1 from public.doctor_profiles dp
    join public.profiles p on p.clerk_user_id = dp.clerk_user_id
    where dp.clerk_user_id = p_doctor_id
      and dp.verification_state = 'verified' and p.application_role = 'doctor'
  ) then raise exception 'doctor is not verified'; end if;
  insert into public.case_assignments(review_request_id, doctor_id, assigned_by)
  values (p_request_id, p_doctor_id, p_operator) returning id into v_id;
  update public.review_requests set status = 'assigned' where id = p_request_id;
  return v_id;
end;
$$;
revoke all on function public.assign_review_case(uuid,text,text)
  from public, anon, authenticated;
grant execute on function public.assign_review_case(uuid,text,text) to service_role;

create function public.revoke_review_assignment(
  p_assignment_id uuid, p_operator text
) returns void language plpgsql security definer set search_path = '' as $$
declare v_request_id uuid;
begin
  if nullif(trim(p_operator), '') is null then raise exception 'operator required'; end if;
  select review_request_id into v_request_id from public.case_assignments
    where id = p_assignment_id and revoked_at is null for update;
  if v_request_id is null then raise exception 'active assignment not found'; end if;
  update public.case_assignments set revoked_at = now(), revoked_by = p_operator
    where id = p_assignment_id;
  update public.review_requests set status = 'pending_assignment'
    where id = v_request_id and status in ('assigned', 'in_review');
end;
$$;
revoke all on function public.revoke_review_assignment(uuid,text)
  from public, anon, authenticated;
grant execute on function public.revoke_review_assignment(uuid,text) to service_role;

create table public.doctor_reviews (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null unique references public.case_assignments(id) on delete restrict,
  observations text not null,
  recommendations text not null,
  follow_up text not null,
  state text not null default 'draft',
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz,
  constraint doctor_review_state check (state in ('draft', 'submitted')),
  constraint doctor_review_version check (version > 0),
  constraint doctor_review_submission check ((state = 'submitted') = (submitted_at is not null)),
  constraint doctor_review_observations check (char_length(trim(observations)) between 1 and 4000),
  constraint doctor_review_recommendations check (char_length(trim(recommendations)) between 1 and 4000),
  constraint doctor_review_follow_up check (char_length(trim(follow_up)) between 1 and 2000)
);
create trigger doctor_reviews_set_updated_at
before update on public.doctor_reviews
for each row execute function public.set_updated_at();
alter table public.doctor_reviews enable row level security;
revoke all on public.doctor_reviews from anon, authenticated;
grant select on public.doctor_reviews to authenticated;

create policy doctor_reviews_select_doctor on public.doctor_reviews
  for select to authenticated using (
    exists (
      select 1 from public.case_assignments ca
      join public.review_requests rr on rr.id = ca.review_request_id
      where ca.id = assignment_id and ca.revoked_at is null
        and public.can_review_screening(rr.screening_id)
    )
  );
create function public.is_review_patient(p_assignment_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.case_assignments ca
    join public.review_requests rr on rr.id = ca.review_request_id
    where ca.id = p_assignment_id
      and rr.patient_id = (select auth.jwt()->>'sub')
  );
$$;
revoke all on function public.is_review_patient(uuid) from public, anon;
grant execute on function public.is_review_patient(uuid) to authenticated;
create policy doctor_reviews_select_patient on public.doctor_reviews
  for select to authenticated using (
    state = 'submitted' and public.is_review_patient(assignment_id)
  );

create table public.case_audit_events (
  id bigint generated always as identity primary key,
  assignment_id uuid not null references public.case_assignments(id) on delete restrict,
  actor_id text not null,
  event_kind text not null,
  happened_at timestamptz not null default now(),
  constraint case_audit_event_kind check (event_kind in ('case_opened', 'draft_saved', 'review_submitted'))
);
alter table public.case_audit_events enable row level security;
revoke all on public.case_audit_events from public, anon, authenticated;

create function public.record_case_access(p_assignment_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_screening_id uuid;
begin
  select rr.screening_id into v_screening_id
  from public.case_assignments ca
  join public.review_requests rr on rr.id = ca.review_request_id
  where ca.id = p_assignment_id and ca.revoked_at is null
    and ca.doctor_id = (select auth.jwt()->>'sub');
  if v_screening_id is null or not public.can_review_screening(v_screening_id) then
    raise exception 'case is not available' using errcode = '42501';
  end if;
  insert into public.case_audit_events(assignment_id, actor_id, event_kind)
  values (p_assignment_id, (select auth.jwt()->>'sub'), 'case_opened');
end;
$$;
revoke all on function public.record_case_access(uuid) from public, anon;
grant execute on function public.record_case_access(uuid) to authenticated;

create function public.save_doctor_review(
  p_assignment_id uuid,
  p_expected_version integer,
  p_observations text,
  p_recommendations text,
  p_follow_up text,
  p_submit boolean
) returns table(review_id uuid, review_version integer, review_state text)
language plpgsql security definer set search_path = '' as $$
declare
  v_request_id uuid;
  v_screening_id uuid;
  v_review public.doctor_reviews%rowtype;
begin
  select rr.id, rr.screening_id into v_request_id, v_screening_id
  from public.case_assignments ca
  join public.review_requests rr on rr.id = ca.review_request_id
  where ca.id = p_assignment_id and ca.revoked_at is null
    and ca.doctor_id = (select auth.jwt()->>'sub')
    and rr.status in ('assigned', 'in_review')
  for update of rr;
  if v_request_id is null or not public.can_review_screening(v_screening_id) then
    raise exception 'case is not available' using errcode = '42501';
  end if;
  if p_expected_version < 0 or p_expected_version is null
    or nullif(trim(p_observations), '') is null
    or nullif(trim(p_recommendations), '') is null
    or nullif(trim(p_follow_up), '') is null then
    raise exception 'invalid review content' using errcode = '22023';
  end if;
  select * into v_review from public.doctor_reviews
  where assignment_id = p_assignment_id for update;
  if v_review.id is null then
    if p_expected_version <> 0 then
      raise exception 'review version conflict' using errcode = '23505';
    end if;
    insert into public.doctor_reviews(
      assignment_id, observations, recommendations, follow_up,
      state, submitted_at
    ) values (
      p_assignment_id, p_observations, p_recommendations, p_follow_up,
      case when p_submit then 'submitted' else 'draft' end,
      case when p_submit then now() else null end
    ) returning * into v_review;
  else
    if v_review.state = 'submitted' or v_review.version <> p_expected_version then
      raise exception 'review version conflict' using errcode = '23505';
    end if;
    update public.doctor_reviews set
      observations = p_observations,
      recommendations = p_recommendations,
      follow_up = p_follow_up,
      state = case when p_submit then 'submitted' else 'draft' end,
      submitted_at = case when p_submit then now() else null end,
      version = version + 1
    where id = v_review.id returning * into v_review;
  end if;
  update public.review_requests set
    status = case when p_submit then 'reviewed' else 'in_review' end
  where id = v_request_id;
  insert into public.case_audit_events(assignment_id, actor_id, event_kind)
  values (p_assignment_id, (select auth.jwt()->>'sub'),
    case when p_submit then 'review_submitted' else 'draft_saved' end);
  return query select v_review.id, v_review.version, v_review.state;
end;
$$;
revoke all on function public.save_doctor_review(uuid,integer,text,text,text,boolean)
  from public, anon;
grant execute on function public.save_doctor_review(uuid,integer,text,text,text,boolean)
  to authenticated;

create function public.my_doctor_feedback()
returns table(
  screening_id uuid, review_id uuid, doctor_name text,
  specialization text, observations text, recommendations text,
  follow_up text, submitted_at timestamptz
) language sql stable security definer set search_path = '' as $$
  select rr.screening_id, dr.id, dp.display_name, dp.specialization,
    dr.observations, dr.recommendations, dr.follow_up, dr.submitted_at
  from public.doctor_reviews dr
  join public.case_assignments ca on ca.id = dr.assignment_id
  join public.review_requests rr on rr.id = ca.review_request_id
  join public.doctor_profiles dp on dp.clerk_user_id = ca.doctor_id
  where rr.patient_id = (select auth.jwt()->>'sub')
    and dr.state = 'submitted'
  order by dr.submitted_at desc;
$$;
revoke all on function public.my_doctor_feedback() from public, anon;
grant execute on function public.my_doctor_feedback() to authenticated;

-- A consented case is retained until a formal retention rule is approved.
-- Reject deletion before hiding the screening or touching Storage.
create or replace function public.begin_screening_delete(
  p_screening_id uuid, p_owner_id text
) returns table(bucket_id text, object_path text)
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.review_requests rr
    where rr.screening_id = p_screening_id and rr.patient_id = p_owner_id) then
    raise exception 'screening has a review request' using errcode = '23503';
  end if;
  update public.screenings
  set lifecycle_state = 'deleting'
  where id = p_screening_id and patient_id = p_owner_id
    and lifecycle_state = 'saved';
  return query select a.bucket_id, a.object_path
    from public.image_assets a
    join public.screenings s on s.id = a.screening_id
    where a.screening_id = p_screening_id and a.owner_id = p_owner_id
      and s.patient_id = p_owner_id and s.lifecycle_state = 'deleting';
end;
$$;
