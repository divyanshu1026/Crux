-- ============================================================================
-- Crux — real subscriptions (Google Play Billing)
--
-- `profiles.is_pro` on its own cannot express a subscription: it has no expiry,
-- so a single purchase grants Pro forever, and nothing records *which*
-- purchase granted it. This adds the state a real entitlement needs and an
-- audit row per purchase token.
--
-- Everything here is written by Edge Functions (service role). Clients read
-- their own rows and never write them — see the guard trigger at the bottom.
-- ============================================================================

-- --- Entitlement on the profile ---------------------------------------------
alter table public.profiles
  add column if not exists pro_expires_at          timestamptz,
  add column if not exists billing_provider        text,
  add column if not exists billing_subscription_id text;

comment on column public.profiles.pro_expires_at is
  'When the current Pro period ends (renewals push it forward). Null with '
  'is_pro = true means a non-expiring grant (comp account).';

-- --- One row per purchase token ---------------------------------------------
create table if not exists public.subscription_purchases (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  provider       text not null default 'google_play',
  product_id     text not null,
  purchase_token text not null,
  -- Mirrors Google's SubscriptionState, lowercased and trimmed of its prefix.
  status         text not null,
  expires_at     timestamptz,
  auto_renewing  boolean not null default false,
  -- The provider's own payload, for reconciling a dispute later.
  raw            jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- A purchase token belongs to exactly one account, forever. Without this, the
-- same receipt could be replayed against a second account to mint free Pro —
-- the single most common way store-billing entitlements get abused.
create unique index if not exists subscription_purchases_token_key
  on public.subscription_purchases (provider, purchase_token);

create index if not exists subscription_purchases_user_idx
  on public.subscription_purchases (user_id, updated_at desc);

alter table public.subscription_purchases enable row level security;

-- Read-only for the owner; all writes come from the service role, which
-- bypasses RLS. No insert/update/delete policy exists on purpose.
drop policy if exists "subscription_purchases: read own"
  on public.subscription_purchases;
create policy "subscription_purchases: read own"
  on public.subscription_purchases
  for select using (auth.uid() = user_id);

-- --- Keep the whole entitlement out of the client's hands -------------------
-- The existing trigger guarded is_pro only. An expiry the client can set is
-- just as good as is_pro for stealing Pro, so guard the lot.
create or replace function public.guard_is_pro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role'
     and (new.is_pro                  is distinct from old.is_pro
       or new.pro_expires_at          is distinct from old.pro_expires_at
       or new.billing_provider        is distinct from old.billing_provider
       or new.billing_subscription_id is distinct from old.billing_subscription_id)
  then
    raise exception 'Pro entitlement is set by billing, not by the client'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

comment on function public.guard_is_pro() is
  'Blocks client-side changes to any Pro entitlement column; only billing '
  'Edge Functions (service role) may grant or revoke Pro.';
