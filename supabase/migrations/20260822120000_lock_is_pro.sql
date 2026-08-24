-- ============================================================================
-- is_pro is a billing fact, not a user preference.
--
-- The `profiles: update own` policy is row-level with no column restriction,
-- so any signed-in user could PATCH their own row and grant themselves Pro:
--
--   PATCH /rest/v1/profiles?id=eq.<their uid>   {"is_pro": true}
--
-- That is the entire paywall, bypassable from a browser console with the
-- publishable key. Only the Razorpay webhook (service role) may set it.
--
-- Implemented as a trigger rather than a column grant because the client sends
-- whole-row updates: a column-level GRANT would reject every profile save that
-- happens to include the column, while this only rejects actual *changes* to
-- it, and only from non-service-role callers.
-- ============================================================================

create or replace function public.guard_is_pro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The service role (webhook, edge functions with the service key) bypasses
  -- RLS and reports role 'service_role'; everyone else must leave it alone.
  if new.is_pro is distinct from old.is_pro
     and coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'is_pro is set by billing, not by the client'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_is_pro on public.profiles;

create trigger guard_is_pro
  before update on public.profiles
  for each row
  execute function public.guard_is_pro();

comment on function public.guard_is_pro() is
  'Blocks client-side changes to profiles.is_pro; only the billing webhook '
  '(service role) may grant or revoke Pro.';
