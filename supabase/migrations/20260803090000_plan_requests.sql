-- ----------------------------------------------------------------------------
-- plan_requests — audit + rate-limit ledger for the `plan` Edge Function.
--
-- AI program generation and AI schedule edits are far more expensive per call
-- than a chat message (large JSON output), so they get their own budget rather
-- than sharing the coach's. Rows are written server-side with the service role
-- only; the client can read its own history but can never insert, so the limit
-- cannot be bypassed by a modified app.
-- ----------------------------------------------------------------------------

create table if not exists public.plan_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  action     text not null check (action in ('generate', 'edit')),
  -- What the user asked for (edits only); null for a first-time generate.
  prompt     text,
  -- Which provider actually answered, for cost attribution. Null when the
  -- request failed before reaching a model.
  provider   text,
  ok         boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists plan_requests_user_created_idx
  on public.plan_requests (user_id, created_at desc);

alter table public.plan_requests enable row level security;

-- Read-only for the owner. No insert/update/delete policies exist, so only the
-- service role (the Edge Function) can write — that is the point.
drop policy if exists "plan_requests_select_own" on public.plan_requests;
create policy "plan_requests_select_own"
  on public.plan_requests for select
  using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- plan_daily_usage — successful plan calls by this user since UTC midnight.
-- Only successful calls count, so a provider outage never eats someone's quota.
-- ----------------------------------------------------------------------------
create or replace function public.plan_daily_usage(p_user uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::int
  from public.plan_requests
  where user_id = p_user
    and ok = true
    and created_at >= date_trunc('day', now() at time zone 'utc');
$$;

grant execute on function public.plan_daily_usage(uuid) to authenticated, service_role;
