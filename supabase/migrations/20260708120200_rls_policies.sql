-- ============================================================================
-- Crux — 0003: Row Level Security
-- ----------------------------------------------------------------------------
-- Hard rule (plan §10/§12): own-rows-only. Every user-owned table restricts
-- read/write to auth.uid() = user_id. `exercises` is public read-only.
-- `chat_messages` and `billing_events` are written only by Edge Functions
-- (service role, which bypasses RLS) — clients get read-only / no access.
-- ============================================================================

-- Enable RLS on everything.
alter table public.profiles      enable row level security;
alter table public.exercises     enable row level security;
alter table public.programs      enable row level security;
alter table public.workouts      enable row level security;
alter table public.set_logs      enable row level security;
alter table public.body_logs     enable row level security;
alter table public.prs           enable row level security;
alter table public.quests        enable row level security;
alter table public.xp_events     enable row level security;
alter table public.rank_signals  enable row level security;
alter table public.promotions    enable row level security;
alter table public.protein_logs  enable row level security;
alter table public.friendships   enable row level security;
alter table public.chat_messages enable row level security;
alter table public.billing_events enable row level security;

-- ----------------------------------------------------------------------------
-- profiles — a user manages exactly their own profile row.
-- ----------------------------------------------------------------------------
create policy "profiles: read own"   on public.profiles for select using (auth.uid() = id);
create policy "profiles: insert own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles: update own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles: delete own" on public.profiles for delete using (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- exercises — reference data. Any signed-in (incl. anonymous) user can read;
-- nobody can write from the client (seeded via migration/service role).
-- ----------------------------------------------------------------------------
create policy "exercises: read all" on public.exercises for select using (true);

-- ----------------------------------------------------------------------------
-- Helper macro pattern applied per user-owned table below.
-- Each gets the same four own-row policies.
-- ----------------------------------------------------------------------------

-- programs
create policy "programs: read own"   on public.programs for select using (auth.uid() = user_id);
create policy "programs: insert own" on public.programs for insert with check (auth.uid() = user_id);
create policy "programs: update own" on public.programs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "programs: delete own" on public.programs for delete using (auth.uid() = user_id);

-- workouts
create policy "workouts: read own"   on public.workouts for select using (auth.uid() = user_id);
create policy "workouts: insert own" on public.workouts for insert with check (auth.uid() = user_id);
create policy "workouts: update own" on public.workouts for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "workouts: delete own" on public.workouts for delete using (auth.uid() = user_id);

-- set_logs
create policy "set_logs: read own"   on public.set_logs for select using (auth.uid() = user_id);
create policy "set_logs: insert own" on public.set_logs for insert with check (auth.uid() = user_id);
create policy "set_logs: update own" on public.set_logs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "set_logs: delete own" on public.set_logs for delete using (auth.uid() = user_id);

-- body_logs
create policy "body_logs: read own"   on public.body_logs for select using (auth.uid() = user_id);
create policy "body_logs: insert own" on public.body_logs for insert with check (auth.uid() = user_id);
create policy "body_logs: update own" on public.body_logs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "body_logs: delete own" on public.body_logs for delete using (auth.uid() = user_id);

-- prs
create policy "prs: read own"   on public.prs for select using (auth.uid() = user_id);
create policy "prs: insert own" on public.prs for insert with check (auth.uid() = user_id);
create policy "prs: update own" on public.prs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "prs: delete own" on public.prs for delete using (auth.uid() = user_id);

-- quests
create policy "quests: read own"   on public.quests for select using (auth.uid() = user_id);
create policy "quests: insert own" on public.quests for insert with check (auth.uid() = user_id);
create policy "quests: update own" on public.quests for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "quests: delete own" on public.quests for delete using (auth.uid() = user_id);

-- xp_events (append-only from the client's perspective: no update/delete policy)
create policy "xp_events: read own"   on public.xp_events for select using (auth.uid() = user_id);
create policy "xp_events: insert own" on public.xp_events for insert with check (auth.uid() = user_id);

-- rank_signals
create policy "rank_signals: read own"   on public.rank_signals for select using (auth.uid() = user_id);
create policy "rank_signals: insert own" on public.rank_signals for insert with check (auth.uid() = user_id);

-- promotions
create policy "promotions: read own"   on public.promotions for select using (auth.uid() = user_id);
create policy "promotions: insert own" on public.promotions for insert with check (auth.uid() = user_id);
create policy "promotions: update own" on public.promotions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "promotions: delete own" on public.promotions for delete using (auth.uid() = user_id);

-- protein_logs
create policy "protein_logs: read own"   on public.protein_logs for select using (auth.uid() = user_id);
create policy "protein_logs: insert own" on public.protein_logs for insert with check (auth.uid() = user_id);
create policy "protein_logs: update own" on public.protein_logs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "protein_logs: delete own" on public.protein_logs for delete using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- friendships — a user can see rows where they are either side, but only
-- create/modify rows they own (user_id side). Accepting an incoming request
-- is handled server-side or via a row the friend owns.
-- ----------------------------------------------------------------------------
create policy "friendships: read involving me" on public.friendships
  for select using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friendships: insert own" on public.friendships
  for insert with check (auth.uid() = user_id);
create policy "friendships: update own side" on public.friendships
  for update using (auth.uid() = user_id or auth.uid() = friend_id)
  with check (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friendships: delete own" on public.friendships
  for delete using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- chat_messages — read own transcript only. No client writes (the coach
-- Edge Function inserts via the service role, which bypasses RLS).
-- ----------------------------------------------------------------------------
create policy "chat_messages: read own" on public.chat_messages
  for select using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- billing_events — no client access at all. Service role only.
-- (RLS enabled + no policies == deny to anon/authenticated.)
-- ----------------------------------------------------------------------------
