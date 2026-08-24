-- ============================================================================
-- Crux — 0004: Server-side business logic (RPC)
-- ----------------------------------------------------------------------------
-- Functions callable from Edge Functions / the client via PostgREST RPC.
-- All are SECURITY DEFINER but scope every query to the passed/authenticated
-- user so they cannot leak across accounts.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- coach_weekly_usage(): number of user-authored coach messages since the start
-- of the current ISO week (Mon 00:00 UTC). Drives the free-tier 5/week limit
-- (plan §9, Phase 7). Counted from chat_messages so it can't be spoofed by the
-- client.
-- ----------------------------------------------------------------------------
-- assert_self(): guard for SECURITY DEFINER RPCs. The service role (auth.uid()
-- null) may act for any user; a signed-in user may only act on their own id.
-- Without this, `authenticated` could pass another user's id and read/modify
-- their data through these definer functions.
create or replace function public.assert_self(p_user uuid)
returns void
language plpgsql
stable
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not authorized for user %', p_user using errcode = '42501';
  end if;
end;
$$;

create or replace function public.coach_weekly_usage(p_user uuid)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_self(p_user);
  return (
    select count(*)::int
    from public.chat_messages
    where user_id = p_user
      and role = 'user'
      and created_at >= date_trunc('week', now())
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- coach_context(): assembles the exact grounding data the AI Coach is allowed
-- to use (plan §7 dashboard data + Phase 7 context). Returns a single JSON blob
-- the Edge Function drops into the prompt. Never includes another user's data.
--   * profile summary
--   * active program (name, split, why, day names)
--   * last 10 completed workouts (compact)
--   * 30-day bodyweight trend (raw points)
--   * recent PRs
-- ----------------------------------------------------------------------------
create or replace function public.coach_context(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile jsonb;
  v_program jsonb;
  v_workouts jsonb;
  v_bodyweight jsonb;
  v_prs jsonb;
begin
  perform public.assert_self(p_user);

  select to_jsonb(x) into v_profile
  from (
    select name, sex, goal, experience_level, equipment, units, level, xp,
           rank, streak_weeks, is_pro, height_cm, injuries, days_per_week,
           dob,
           case when dob is not null
                then date_part('year', age(dob))::int
           end as age
    from public.profiles where id = p_user
  ) x;

  select to_jsonb(x) into v_program
  from (
    select name, split_type, why_fits, source, rank_level,
           (select jsonb_agg(d ->> 'name') from jsonb_array_elements(days) d) as day_names
    from public.programs
    where user_id = p_user and is_active and deleted_at is null
    order by updated_at desc
    limit 1
  ) x;

  select coalesce(jsonb_agg(w order by w_started_at desc), '[]'::jsonb) into v_workouts
  from (
    select
      wk.workout_day_name,
      wk.started_at as w_started_at,
      wk.duration_seconds,
      wk.total_volume_kg,
      lat.exercises
    from public.workouts wk
    left join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
                'exercise', sl.exercise_name,
                'top_set', jsonb_build_object('weight_kg', sl.weight_kg, 'reps', sl.reps),
                'note', sl.note)), '[]'::jsonb) as exercises
      from (
        select distinct on (s.exercise_name) s.exercise_name, s.weight_kg, s.reps, s.note
        from public.set_logs s
        where s.workout_id = wk.id and s.completed and not s.is_warmup
        order by s.exercise_name, s.weight_kg desc
      ) sl
    ) lat on true
    where wk.user_id = p_user and wk.completed_at is not null and wk.deleted_at is null
    order by wk.started_at desc
    limit 10
  ) w;

  select coalesce(jsonb_agg(jsonb_build_object('date', logged_on, 'weight_kg', weight_kg)
                            order by logged_on), '[]'::jsonb)
    into v_bodyweight
  from public.body_logs
  where user_id = p_user and deleted_at is null and logged_on >= current_date - 30;

  select coalesce(jsonb_agg(jsonb_build_object(
            'exercise', exercise_name, 'type', type, 'value', value, 'at', achieved_at)
          order by achieved_at desc), '[]'::jsonb)
    into v_prs
  from (
    select * from public.prs
    where user_id = p_user and deleted_at is null
    order by achieved_at desc limit 8
  ) p;

  return jsonb_build_object(
    'profile', coalesce(v_profile, '{}'::jsonb),
    'active_program', coalesce(v_program, 'null'::jsonb),
    'recent_workouts', v_workouts,
    'bodyweight_30d', v_bodyweight,
    'recent_prs', v_prs
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- recompute_rank_signals(): Phase 9. Recomputes the silent progression signals
-- for a user and upserts a fresh row per signal_type. Kept deterministic and
-- SQL-only so it can run from a cron job or on-demand after a workout sync.
-- ----------------------------------------------------------------------------
create or replace function public.recompute_rank_signals(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_workouts int;
  v_first_workout  timestamptz;
  v_training_months numeric;
  v_active_weeks   int;
  v_consistency    numeric;
  v_e1rm_squat     numeric;
  v_e1rm_bench     numeric;
  v_e1rm_deadlift  numeric;
  v_stall_freq     numeric;
begin
  perform public.assert_self(p_user);

  select count(*), min(started_at)
    into v_total_workouts, v_first_workout
  from public.workouts
  where user_id = p_user and completed_at is not null and deleted_at is null;

  v_training_months := case
    when v_first_workout is null then 0
    else round(extract(epoch from (now() - v_first_workout)) / (60*60*24*30.4375), 2)
  end;

  -- Consistency: distinct weeks trained in the last 12 / 12 * 100.
  select count(distinct date_trunc('week', started_at))
    into v_active_weeks
  from public.workouts
  where user_id = p_user and completed_at is not null and deleted_at is null
    and started_at >= now() - interval '12 weeks';
  v_consistency := round(least(v_active_weeks, 12) / 12.0 * 100, 1);

  -- Best e1RM for the big three (matches by exercise name, warmups excluded).
  select max(public.epley_e1rm(weight_kg, reps)) into v_e1rm_squat
    from public.set_logs
    where user_id = p_user and completed and not is_warmup and exercise_name ilike '%squat%';
  select max(public.epley_e1rm(weight_kg, reps)) into v_e1rm_bench
    from public.set_logs
    where user_id = p_user and completed and not is_warmup and exercise_name ilike '%bench press%';
  select max(public.epley_e1rm(weight_kg, reps)) into v_e1rm_deadlift
    from public.set_logs
    where user_id = p_user and completed and not is_warmup and exercise_name ilike '%deadlift%';

  -- Stall frequency: share of the last 10 workouts that set no PR (0..1).
  select coalesce(
    avg(case when had_pr then 0 else 1 end), 0)
    into v_stall_freq
  from (
    select wk.id,
           exists(select 1 from public.prs pr
                  where pr.workout_id = wk.id and pr.deleted_at is null) as had_pr
    from public.workouts wk
    where wk.user_id = p_user and wk.completed_at is not null and wk.deleted_at is null
    order by wk.started_at desc
    limit 10
  ) t;

  -- Replace prior signals for this user, insert the fresh snapshot.
  delete from public.rank_signals where user_id = p_user;
  insert into public.rank_signals (user_id, signal_type, value) values
    (p_user, 'total_workouts',   v_total_workouts),
    (p_user, 'training_months',  v_training_months),
    (p_user, 'consistency_pct',  v_consistency),
    (p_user, 'e1rm_squat',       coalesce(v_e1rm_squat, 0)),
    (p_user, 'e1rm_bench',       coalesce(v_e1rm_bench, 0)),
    (p_user, 'e1rm_deadlift',    coalesce(v_e1rm_deadlift, 0)),
    (p_user, 'stall_frequency',  round(v_stall_freq, 3));
end;
$$;

-- Lock down execution: only authenticated users (and the service role) may call.
revoke all on function public.coach_weekly_usage(uuid)     from public;
revoke all on function public.coach_context(uuid)          from public;
revoke all on function public.recompute_rank_signals(uuid) from public;
grant execute on function public.coach_weekly_usage(uuid)     to authenticated, service_role;
grant execute on function public.coach_context(uuid)          to authenticated, service_role;
grant execute on function public.recompute_rank_signals(uuid) to authenticated, service_role;
