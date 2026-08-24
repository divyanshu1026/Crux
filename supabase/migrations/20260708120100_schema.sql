-- ============================================================================
-- Crux — 0002: Core schema
-- ----------------------------------------------------------------------------
-- Mirrors the local Drift tables (plan §11) so the queue-based sync layer can
-- push/pull row-for-row. Conventions used everywhere:
--   * Primary keys are UUIDs generated on-device (offline-first), so the
--     column has a default but the client normally supplies the value.
--   * user_id references auth.users so RLS can key off auth.uid().
--   * updated_at is stamped by a trigger and drives last-write-wins sync.
--   * deleted_at is a soft-delete tombstone so deletions propagate on pull
--     instead of silently reappearing from another device.
-- All weights are stored in kg. Display-unit conversion is client-side only.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles — one row per auth user (id == auth.users.id). The "User" entity.
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id                    uuid primary key references auth.users (id) on delete cascade,
  name                  text        not null default '',
  sex                   text        not null default 'prefer_not_to_say'
                          check (sex in ('male', 'female', 'prefer_not_to_say')),
  dob                   date,
  height_cm             numeric(5,1),
  experience_level      text        not null default 'never_trained'
                          check (experience_level in
                            ('never_trained', 'under_6_months', '6_to_24_months', '2_plus_years')),
  goal                  text        not null default 'build_muscle'
                          check (goal in
                            ('build_muscle', 'get_stronger', 'lose_fat_tone', 'general_fitness')),
  days_per_week         text[]      not null default '{}',   -- e.g. {Mon,Wed,Fri}
  equipment             text        not null default 'full_gym'
                          check (equipment in ('full_gym', 'dumbbells_only', 'minimal_home')),
  units                 text        not null default 'metric'
                          check (units in ('metric', 'imperial')),
  locale                text        not null default 'en',
  avatar_id             text        not null default 'yorhart_neutral',
  injuries              text[]      not null default '{}',
  -- Gamification / progression state
  level                 int         not null default 1  check (level >= 1),
  xp                    int         not null default 0  check (xp >= 0),
  rank                  text        not null default 'novice'
                          check (rank in
                            ('novice', 'apprentice', 'iron_1', 'iron_2', 'iron_3', 'steel', 'titan')),
  streak_weeks          int         not null default 0  check (streak_weeks >= 0),
  rest_passes_remaining int         not null default 1  check (rest_passes_remaining >= 0),
  zen_mode              boolean     not null default false,
  is_pro                boolean     not null default false,
  notification_opt_in   boolean     not null default false,
  onboarding_complete   boolean     not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);

-- ----------------------------------------------------------------------------
-- exercises — global read-only reference library (no user_id). Seeded from
-- assets. The demo library, muscle mapping, and equipment filter all read this.
-- ----------------------------------------------------------------------------
create table if not exists public.exercises (
  id                 uuid primary key default gen_random_uuid(),
  slug               text unique not null,           -- stable key, e.g. 'barbell-bench-press'
  name               text not null,
  muscle_group       text not null,
  secondary_muscles  text[] not null default '{}',
  equipment          text not null
                       check (equipment in
                         ('barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'band')),
  is_compound        boolean not null default false,
  demo_url           text,
  form_cue           text,                            -- one-line instruction
  l10n_key           text,
  created_at         timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- programs — a user's training plan. `days` holds the full day/exercise
-- structure as JSON (matches the client Program model), so the whole plan
-- syncs as one row and stays editable offline.
-- ----------------------------------------------------------------------------
create table if not exists public.programs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  name             text not null,
  description      text not null default '',
  split_type       text not null default 'full_body',
  days             jsonb not null default '[]'::jsonb,
  why_fits         text not null default '',          -- generated "why this fits you"
  is_active        boolean not null default true,
  source           text not null default 'ai'
                     check (source in ('ai', 'template', 'custom')),
  block_started_at timestamptz not null default now(),
  rank_level       text not null default 'novice',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

-- ----------------------------------------------------------------------------
-- workouts — one logged session.
-- ----------------------------------------------------------------------------
create table if not exists public.workouts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  program_id        uuid references public.programs (id) on delete set null,
  program_day_ref   text,                              -- day id/name within the program
  workout_day_name  text not null default '',
  started_at        timestamptz not null default now(),
  completed_at      timestamptz,
  duration_seconds  int not null default 0,
  total_volume_kg   numeric(10,2) not null default 0,
  xp_earned         int not null default 0,
  notes             text,
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);

-- ----------------------------------------------------------------------------
-- set_logs — individual sets within a workout.
-- ----------------------------------------------------------------------------
create table if not exists public.set_logs (
  id           uuid primary key default gen_random_uuid(),
  workout_id   uuid not null references public.workouts (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  exercise_id  uuid references public.exercises (id) on delete set null,
  exercise_name text not null default '',             -- denormalized for offline resilience
  muscle_group text not null default '',
  set_number   int not null default 1,
  weight_kg    numeric(7,2) not null default 0,
  reps         int not null default 0,
  rpe          numeric(3,1),                           -- unlocked at Iron rank
  note         text,                                   -- per-set note ("felt heavy")
  is_pr        boolean not null default false,
  is_e1rm_pr   boolean not null default false,
  is_warmup    boolean not null default false,
  completed    boolean not null default false,
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

-- ----------------------------------------------------------------------------
-- body_logs — daily weigh-ins + optional measurements. Photos stay local by
-- default; photo_path is a client path unless the user opts into cloud backup.
-- ----------------------------------------------------------------------------
create table if not exists public.body_logs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  logged_on    date not null default current_date,
  weight_kg    numeric(6,2) not null,
  measurements jsonb,
  photo_path   text,
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  unique (user_id, logged_on)
);

-- ----------------------------------------------------------------------------
-- prs — personal records (weight / e1rm / reps / volume).
-- ----------------------------------------------------------------------------
create table if not exists public.prs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  exercise_id  uuid references public.exercises (id) on delete set null,
  exercise_name text not null default '',
  type         text not null check (type in ('weight', 'e1rm', 'reps', 'volume')),
  value        numeric(10,2) not null,
  achieved_at  timestamptz not null default now(),
  workout_id   uuid references public.workouts (id) on delete set null,
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

-- ----------------------------------------------------------------------------
-- quests — weekly + milestone quests. Progress is event-sourced client-side
-- and synced here for cross-device continuity.
-- ----------------------------------------------------------------------------
create table if not exists public.quests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  template_id  text not null,                          -- e.g. 'log_workout_weekly'
  title        text not null default '',
  description  text not null default '',
  progress     int not null default 0,
  target       int not null default 1,
  xp_reward    int not null default 0,
  is_milestone boolean not null default false,
  status       text not null default 'active'
                 check (status in ('active', 'completed', 'claimed', 'expired')),
  expires_at   timestamptz,
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

-- ----------------------------------------------------------------------------
-- xp_events — append-only XP ledger (event-sourced). The profile's xp/level
-- are a fold over this; the ledger is the audit trail.
-- ----------------------------------------------------------------------------
create table if not exists public.xp_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  type       text not null,                            -- workout | all_sets | pr | weigh_in | quest | bonus
  amount     int not null,
  ref_id     text,                                     -- workout/quest id it came from
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ----------------------------------------------------------------------------
-- rank_signals — the silently-tracked inputs to the Progression System.
-- Recomputed periodically (Phase 9); latest row per signal_type is current.
-- ----------------------------------------------------------------------------
create table if not exists public.rank_signals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  signal_type text not null,   -- total_workouts | training_months | consistency_pct |
                               -- e1rm_squat | e1rm_bench | e1rm_deadlift | stall_frequency ...
  value       numeric(12,3) not null,
  computed_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- promotions — rank-up offers (never automatic; user confirms).
-- ----------------------------------------------------------------------------
create table if not exists public.promotions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  from_rank  text not null,
  to_rank    text not null,
  evidence   jsonb not null default '{}'::jsonb,
  status     text not null default 'available'
               check (status in ('available', 'accepted', 'deferred')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ----------------------------------------------------------------------------
-- protein_logs (Tier 3) — daily protein grams toward a computed goal.
-- ----------------------------------------------------------------------------
create table if not exists public.protein_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  logged_on  date not null default current_date,
  grams      int not null default 0 check (grams >= 0),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, logged_on)
);

-- ----------------------------------------------------------------------------
-- friendships (Tier 2) — opt-in social graph for leaderboards/reactions.
-- ----------------------------------------------------------------------------
create table if not exists public.friendships (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  friend_id  uuid not null references auth.users (id) on delete cascade,
  status     text not null default 'pending'
               check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, friend_id),
  check (user_id <> friend_id)
);

-- ----------------------------------------------------------------------------
-- chat_messages — AI Coach transcript. SERVER-SIDE ONLY: written by the coach
-- Edge Function; the client reads its own rows for history. Kept for safety
-- auditing per plan §12 (logged conversations) and rate-limit accounting.
-- ----------------------------------------------------------------------------
create table if not exists public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        text not null check (role in ('user', 'assistant')),
  content     text not null,
  token_usage jsonb,                                   -- {input, output} for cost tracking
  created_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- billing_events — raw provider webhook log (Razorpay). is_pro on the profile
-- is the derived flag the app reads; this is the audit trail behind it.
-- ----------------------------------------------------------------------------
create table if not exists public.billing_events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users (id) on delete set null,
  provider     text not null default 'razorpay',
  event_type   text not null,
  external_id  text,                                   -- razorpay payment/subscription id
  payload      jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now()
);

-- ============================================================================
-- Indexes — sync pulls filter by user_id + updated_at; analytics filter by
-- time. These cover the hot paths.
-- ============================================================================
create index if not exists idx_programs_user        on public.programs (user_id, updated_at);
create index if not exists idx_programs_active       on public.programs (user_id) where is_active and deleted_at is null;
create index if not exists idx_workouts_user         on public.workouts (user_id, started_at desc);
create index if not exists idx_workouts_user_updated on public.workouts (user_id, updated_at);
create index if not exists idx_set_logs_workout      on public.set_logs (workout_id);
create index if not exists idx_set_logs_user_updated on public.set_logs (user_id, updated_at);
create index if not exists idx_body_logs_user        on public.body_logs (user_id, logged_on desc);
create index if not exists idx_prs_user              on public.prs (user_id, achieved_at desc);
create index if not exists idx_quests_user           on public.quests (user_id, updated_at);
create index if not exists idx_xp_events_user        on public.xp_events (user_id, created_at desc);
create index if not exists idx_rank_signals_user     on public.rank_signals (user_id, signal_type, computed_at desc);
create index if not exists idx_promotions_user       on public.promotions (user_id, status);
create index if not exists idx_protein_logs_user     on public.protein_logs (user_id, logged_on desc);
create index if not exists idx_friendships_friend    on public.friendships (friend_id);
create index if not exists idx_chat_messages_user    on public.chat_messages (user_id, created_at desc);
create index if not exists idx_exercises_muscle      on public.exercises (muscle_group);

-- ============================================================================
-- updated_at triggers (sync ordering)
-- ============================================================================
create trigger trg_profiles_updated   before update on public.profiles   for each row execute function public.set_updated_at();
create trigger trg_programs_updated    before update on public.programs    for each row execute function public.set_updated_at();
create trigger trg_workouts_updated    before update on public.workouts    for each row execute function public.set_updated_at();
create trigger trg_set_logs_updated    before update on public.set_logs    for each row execute function public.set_updated_at();
create trigger trg_body_logs_updated   before update on public.body_logs   for each row execute function public.set_updated_at();
create trigger trg_prs_updated         before update on public.prs         for each row execute function public.set_updated_at();
create trigger trg_quests_updated      before update on public.quests      for each row execute function public.set_updated_at();
create trigger trg_promotions_updated  before update on public.promotions  for each row execute function public.set_updated_at();
create trigger trg_protein_logs_updated before update on public.protein_logs for each row execute function public.set_updated_at();
create trigger trg_friendships_updated before update on public.friendships for each row execute function public.set_updated_at();

-- ============================================================================
-- New-user trigger: create a profile whenever an auth user is created.
-- ============================================================================
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
