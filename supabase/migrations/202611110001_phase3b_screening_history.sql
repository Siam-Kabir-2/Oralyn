-- Oralyn Phase 3B: private, Clerk-owned screening history.
-- Apply only after Clerk is enabled under Supabase Third-Party Auth.

create extension if not exists pgcrypto;

create table public.profiles (
  clerk_user_id text primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_clerk_id check (clerk_user_id ~ '^user_[A-Za-z0-9]+$')
);

create table public.screenings (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.profiles(clerk_user_id) on delete restrict,
  idempotency_key text not null,
  lifecycle_state text not null default 'saved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint screenings_idempotency_length check (
    char_length(idempotency_key) between 16 and 128
  ),
  constraint screenings_lifecycle check (
    lifecycle_state in ('saved', 'deleting')
  ),
  constraint screenings_owner_idempotency unique (patient_id, idempotency_key),
  constraint screenings_id_owner unique (id, patient_id)
);

create table public.screening_results (
  screening_id uuid primary key references public.screenings(id) on delete cascade,
  primary_prediction text not null,
  primary_score double precision not null,
  primary_predictions jsonb not null,
  cancer_verification jsonb not null,
  screening_status text not null,
  primary_model text not null,
  verification_model text not null,
  gradcam_available boolean not null,
  gradcam_label text,
  disclaimer text not null,
  created_at timestamptz not null default now(),
  constraint screening_results_primary_class check (
    primary_prediction in ('Normal', 'Variation_from_Normal', 'OPMD', 'Oral_Cancer')
  ),
  constraint screening_results_primary_score check (
    primary_score between 0 and 1
  ),
  constraint screening_results_status check (
    screening_status in (
      'Low Concern',
      'Review Recommended',
      'Professional Review Recommended',
      'Prompt Specialist Review'
    )
  ),
  constraint screening_results_predictions_array check (
    jsonb_typeof(primary_predictions) = 'array'
  ),
  constraint screening_results_verification_object check (
    jsonb_typeof(cancer_verification) = 'object'
  ),
  constraint screening_results_gradcam_label check (
    not gradcam_available or nullif(gradcam_label, '') is not null
  )
);

create table public.image_assets (
  id uuid primary key default gen_random_uuid(),
  screening_id uuid not null,
  owner_id text not null,
  asset_kind text not null,
  bucket_id text not null default 'screening-images',
  object_path text not null unique,
  content_type text not null,
  byte_size bigint not null,
  sha256 text not null,
  created_at timestamptz not null default now(),
  constraint image_assets_screening_owner foreign key (screening_id, owner_id)
    references public.screenings(id, patient_id) on delete cascade,
  constraint image_assets_kind check (asset_kind in ('original', 'gradcam')),
  constraint image_assets_type check (
    content_type in ('image/jpeg', 'image/png', 'image/webp', 'image/bmp')
  ),
  constraint image_assets_size check (byte_size between 1 and 10485760),
  constraint image_assets_sha256 check (sha256 ~ '^[a-f0-9]{64}$'),
  constraint image_assets_one_kind unique (screening_id, asset_kind)
);

create index screenings_patient_created_idx
  on public.screenings(patient_id, created_at desc);
create index image_assets_screening_idx on public.image_assets(screening_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger screenings_set_updated_at
before update on public.screenings
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.screenings enable row level security;
alter table public.screening_results enable row level security;
alter table public.image_assets enable row level security;

create policy profiles_select_own
on public.profiles for select to authenticated
using ((select auth.jwt()->>'sub') = clerk_user_id);

create policy screenings_select_own_saved
on public.screenings for select to authenticated
using (
  (select auth.jwt()->>'sub') = patient_id
  and lifecycle_state = 'saved'
);

create policy screening_results_select_own
on public.screening_results for select to authenticated
using (
  exists (
    select 1 from public.screenings s
    where s.id = screening_results.screening_id
      and s.patient_id = (select auth.jwt()->>'sub')
      and s.lifecycle_state = 'saved'
  )
);

create policy image_assets_select_own
on public.image_assets for select to authenticated
using (
  owner_id = (select auth.jwt()->>'sub')
  and exists (
    select 1 from public.screenings s
    where s.id = image_assets.screening_id
      and s.patient_id = (select auth.jwt()->>'sub')
      and s.lifecycle_state = 'saved'
  )
);

-- Authenticated clients can read only. Trusted inference output is written by
-- FastAPI with the server-only Supabase secret key.
revoke all on public.profiles from anon, authenticated;
revoke all on public.screenings from anon, authenticated;
revoke all on public.screening_results from anon, authenticated;
revoke all on public.image_assets from anon, authenticated;
grant select on public.profiles to authenticated;
grant select on public.screenings to authenticated;
grant select on public.screening_results to authenticated;
grant select on public.image_assets to authenticated;

create or replace function public.save_screening(
  p_screening_id uuid,
  p_owner_id text,
  p_idempotency_key text,
  p_result jsonb,
  p_assets jsonb
)
returns table(screening_id uuid, created boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted uuid;
begin
  if p_owner_id !~ '^user_[A-Za-z0-9]+$' then
    raise exception 'invalid owner';
  end if;
  if jsonb_typeof(p_assets) <> 'array' then
    raise exception 'assets must be an array';
  end if;

  insert into public.profiles(clerk_user_id)
  values (p_owner_id)
  on conflict (clerk_user_id) do nothing;

  insert into public.screenings(id, patient_id, idempotency_key)
  values (p_screening_id, p_owner_id, p_idempotency_key)
  on conflict (patient_id, idempotency_key) do nothing
  returning id into v_inserted;

  if v_inserted is null then
    return query
      select s.id, false
      from public.screenings s
      where s.patient_id = p_owner_id
        and s.idempotency_key = p_idempotency_key;
    return;
  end if;

  insert into public.screening_results(
    screening_id,
    primary_prediction,
    primary_score,
    primary_predictions,
    cancer_verification,
    screening_status,
    primary_model,
    verification_model,
    gradcam_available,
    gradcam_label,
    disclaimer
  ) values (
    p_screening_id,
    p_result->>'primary_prediction',
    (p_result->>'primary_score')::double precision,
    p_result->'primary_predictions',
    p_result->'cancer_verification',
    p_result->>'screening_status',
    p_result->'model'->>'primary',
    p_result->'model'->>'verification',
    coalesce((p_result->'gradcam'->>'available')::boolean, false),
    p_result->'gradcam'->>'label',
    p_result->>'disclaimer'
  );

  insert into public.image_assets(
    screening_id, owner_id, asset_kind, bucket_id, object_path,
    content_type, byte_size, sha256
  )
  select
    p_screening_id,
    p_owner_id,
    asset_kind,
    bucket_id,
    object_path,
    content_type,
    byte_size,
    sha256
  from jsonb_to_recordset(p_assets) as asset(
    asset_kind text,
    bucket_id text,
    object_path text,
    content_type text,
    byte_size bigint,
    sha256 text
  );

  return query select p_screening_id, true;
end;
$$;

create or replace function public.begin_screening_delete(
  p_screening_id uuid,
  p_owner_id text
)
returns table(bucket_id text, object_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.screenings
  set lifecycle_state = 'deleting'
  where id = p_screening_id
    and patient_id = p_owner_id
    and lifecycle_state = 'saved';
  return query
    select a.bucket_id, a.object_path
    from public.image_assets a
    join public.screenings s on s.id = a.screening_id
    where a.screening_id = p_screening_id
      and a.owner_id = p_owner_id
      and s.patient_id = p_owner_id
      and s.lifecycle_state = 'deleting';
end;
$$;

create or replace function public.finalize_screening_delete(
  p_screening_id uuid,
  p_owner_id text
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.screenings
  where id = p_screening_id
    and patient_id = p_owner_id
    and lifecycle_state = 'deleting';
$$;

revoke all on function public.save_screening(uuid, text, text, jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.begin_screening_delete(uuid, text)
  from public, anon, authenticated;
revoke all on function public.finalize_screening_delete(uuid, text)
  from public, anon, authenticated;
grant execute on function public.save_screening(uuid, text, text, jsonb, jsonb)
  to service_role;
grant execute on function public.begin_screening_delete(uuid, text)
  to service_role;
grant execute on function public.finalize_screening_delete(uuid, text)
  to service_role;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'screening-images',
  'screening-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/bmp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy screening_images_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'screening-images'
  and (storage.foldername(name))[1] = (select auth.jwt()->>'sub')
);

-- No authenticated INSERT/UPDATE/DELETE policies are intentional. Image
-- writes and deletion happen only after FastAPI has run authoritative model
-- inference and verified ownership.
