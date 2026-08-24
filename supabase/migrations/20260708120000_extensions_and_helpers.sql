-- ============================================================================
-- Crux — 0001: Extensions & shared helper functions
-- ----------------------------------------------------------------------------
-- Runs first. Everything here is referenced by later migrations (triggers,
-- RLS helpers, the e1RM calculation used by the overload/PR engines).
-- ============================================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- ----------------------------------------------------------------------------
-- set_updated_at(): stamp updated_at on every UPDATE. Used by the sync layer
-- for last-write-wins conflict resolution (newer updated_at wins).
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- epley_e1rm(): the single source of truth for estimated 1-rep-max.
-- Mirrors the Flutter engine exactly: weight * (1 + reps/30).
-- Warmup sets and 0-weight sets return 0 so they never register a PR.
-- ----------------------------------------------------------------------------
create or replace function public.epley_e1rm(weight_kg numeric, reps int)
returns numeric
language sql
immutable
as $$
  select case
    when weight_kg is null or reps is null or weight_kg <= 0 or reps <= 0 then 0
    else round((weight_kg * (1 + reps / 30.0))::numeric, 2)
  end;
$$;

-- ----------------------------------------------------------------------------
-- handle_new_user(): auto-create a profile row when an auth user (including
-- anonymous sign-ins) is created. Keeps profiles.id == auth.users.id so RLS
-- can key off auth.uid() everywhere. Metadata passed at sign-up
-- (raw_user_meta_data) seeds the display name; the rest is filled by the app
-- during onboarding sync.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
