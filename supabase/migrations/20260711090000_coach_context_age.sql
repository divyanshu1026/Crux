-- ============================================================================
-- Crux — 0005: coach_context gains age (from dob)
-- ----------------------------------------------------------------------------
-- The upgraded coach prompt computes nutrition (Mifflin-St Jeor) which needs
-- the user's age. Re-creates coach_context() with dob/age in the profile
-- block for projects that already applied 0004. (Fresh installs get the same
-- definition from 0004 — CREATE OR REPLACE makes re-running harmless.)
-- ============================================================================

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
