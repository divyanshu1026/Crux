-- ----------------------------------------------------------------------------
-- Workout backup — give locally-created rows a stable identity.
--
-- The app creates workouts offline, long before it has ever spoken to the
-- server, and identifies them with its own ids ("session_1754210000000"). The
-- server's `id` is a generated uuid, so without a second key there is no way
-- to tell "this workout again" from "a new workout" — and a backup that runs
-- every week would insert duplicates every week.
--
-- `client_id` is that key: assigned on the device, unique per user, and what
-- the sync upserts conflict on. Nullable so existing rows stay valid.
-- ----------------------------------------------------------------------------

alter table public.workouts
  add column if not exists client_id text;

alter table public.set_logs
  add column if not exists client_id text;

-- Partial indexes: only rows that came from a device carry a client_id, and
-- NULLs are excluded so server-created rows don't collide with each other.
create unique index if not exists workouts_user_client_id_key
  on public.workouts (user_id, client_id)
  where client_id is not null;

create unique index if not exists set_logs_user_client_id_key
  on public.set_logs (user_id, client_id)
  where client_id is not null;
