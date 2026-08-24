-- ============================================================================
-- Crux — seed data (runs on `supabase db reset`)
-- ----------------------------------------------------------------------------
-- Reference exercise library. Deliberately strong on glute/lower-body work
-- (hip thrust, RDL variants, abduction, split squats) — not just bro-split
-- staples (plan §3 cross-gender requirement, Phase 1). Idempotent via slug.
-- The full 180+ library ships as a client JSON asset; this covers the core
-- set the generator + demos reference server-side.
-- ============================================================================

insert into public.exercises (slug, name, muscle_group, secondary_muscles, equipment, is_compound, form_cue, l10n_key) values
-- Chest
('barbell-bench-press',   'Barbell Bench Press',   'Chest', array['Triceps','Shoulders'], 'barbell',   true,  'Retract shoulder blades; bar to mid-chest; drive through your feet.', 'ex.barbell_bench_press'),
('incline-db-press',      'Incline Dumbbell Press','Chest', array['Shoulders','Triceps'],  'dumbbell',  true,  'Bench at ~30°; press up and slightly in without flaring elbows.',    'ex.incline_db_press'),
('dumbbell-bench-press',  'Dumbbell Bench Press',  'Chest', array['Triceps','Shoulders'], 'dumbbell',  true,  'Control the stretch; press to lockout over your chest.',             'ex.dumbbell_bench_press'),
('chest-fly',             'Cable Chest Fly',       'Chest', array['Shoulders'],            'cable',     false, 'Slight elbow bend; hug an imaginary barrel; squeeze at the middle.', 'ex.chest_fly'),
('push-up',               'Push-up',               'Chest', array['Triceps','Core'],       'bodyweight',true,  'Body in one line; elbows ~45°; full range each rep.',                'ex.push_up'),
-- Back
('barbell-deadlift',      'Barbell Deadlift',      'Back',  array['Glutes','Hamstrings','Core'], 'barbell', true, 'Neutral spine; push the floor away; bar stays close to your legs.', 'ex.barbell_deadlift'),
('bent-over-row',         'Bent-Over Barbell Row', 'Back',  array['Biceps','Rear Delts'],  'barbell',   true,  'Hinge to ~45°; row to your lower ribs; control the descent.',        'ex.bent_over_row'),
('dumbbell-row',          'One-Arm Dumbbell Row',  'Back',  array['Biceps','Rear Delts'],  'dumbbell',  true,  'Flat back; drive elbow to hip; no torso twisting.',                  'ex.dumbbell_row'),
('lat-pulldown',          'Lat Pulldown',          'Back',  array['Biceps'],               'cable',     true,  'Pull the bar to your collarbone; lead with the elbows.',             'ex.lat_pulldown'),
('pull-up',               'Pull-up',               'Back',  array['Biceps','Core'],        'bodyweight',true,  'Full hang to chin over bar; avoid swinging.',                        'ex.pull_up'),
('seated-cable-row',      'Seated Cable Row',      'Back',  array['Biceps','Rear Delts'],  'cable',     true,  'Tall chest; row to your navel; squeeze the shoulder blades.',        'ex.seated_cable_row'),
('face-pull',             'Face Pull',             'Back',  array['Rear Delts'],           'cable',     false, 'Pull rope to your forehead; externally rotate at the end.',          'ex.face_pull'),
-- Legs (quads)
('barbell-back-squat',    'Barbell Back Squat',    'Legs',  array['Glutes','Core'],        'barbell',   true,  'Brace hard; sit between your hips; knees track over toes.',          'ex.barbell_back_squat'),
('front-squat',           'Front Squat',           'Legs',  array['Glutes','Core'],        'barbell',   true,  'Elbows high; stay upright; drive up out of the hole.',               'ex.front_squat'),
('goblet-squat',          'Goblet Squat',          'Legs',  array['Glutes','Core'],        'dumbbell',  true,  'Hold the bell at your chest; sit down tall between your knees.',     'ex.goblet_squat'),
('leg-press',             'Leg Press',             'Legs',  array['Glutes'],               'machine',   true,  'Feet mid-platform; lower to ~90°; don''t lock the knees hard.',      'ex.leg_press'),
('leg-extension',         'Leg Extension',         'Legs',  array[]::text[],               'machine',   false, 'Control up; pause and squeeze the quad at the top.',                 'ex.leg_extension'),
('walking-lunge',         'Walking Lunge',         'Legs',  array['Glutes','Hamstrings'],  'dumbbell',  true,  'Long step; back knee toward the floor; push through the front heel.','ex.walking_lunge'),
('bulgarian-split-squat', 'Bulgarian Split Squat', 'Legs',  array['Glutes'],               'dumbbell',  true,  'Rear foot elevated; drop straight down; drive through the front heel.','ex.bulgarian_split_squat'),
('bodyweight-squat',      'Bodyweight Squat',      'Legs',  array['Glutes'],               'bodyweight',true,  'Feet shoulder-width; sit back and down; chest proud.',              'ex.bodyweight_squat'),
-- Glutes / posterior chain (first-class citizens)
('barbell-hip-thrust',    'Barbell Hip Thrust',    'Glutes',array['Hamstrings'],           'barbell',   true,  'Chin tucked; drive hips to full lockout; squeeze glutes hard.',      'ex.barbell_hip_thrust'),
('romanian-deadlift',     'Romanian Deadlift',     'Glutes',array['Hamstrings','Back'],    'barbell',   true,  'Soft knees; push hips back; feel the hamstring stretch, then drive.','ex.romanian_deadlift'),
('db-romanian-deadlift',  'Dumbbell RDL',          'Glutes',array['Hamstrings','Back'],    'dumbbell',  true,  'Hinge at the hips; flat back; bells slide down your thighs.',        'ex.db_romanian_deadlift'),
('hip-abduction',         'Hip Abduction',         'Glutes',array[]::text[],               'machine',   false, 'Lean forward slightly; press knees out; control the return.',        'ex.hip_abduction'),
('cable-kickback',        'Cable Glute Kickback',  'Glutes',array['Hamstrings'],           'cable',     false, 'Hinge slightly; drive the heel back; squeeze without arching.',      'ex.cable_kickback'),
('glute-bridge',          'Glute Bridge',          'Glutes',array['Hamstrings'],           'bodyweight',false, 'Heels close; ribs down; bridge to a straight line and squeeze.',     'ex.glute_bridge'),
('hamstring-curl',        'Lying Hamstring Curl',  'Legs',  array['Glutes'],               'machine',   false, 'Curl fully; control the eccentric; keep hips down.',                 'ex.hamstring_curl'),
('standing-calf-raise',   'Standing Calf Raise',   'Legs',  array[]::text[],               'machine',   false, 'Full stretch at the bottom; rise onto the toes; pause up top.',      'ex.standing_calf_raise'),
-- Shoulders
('overhead-press',        'Overhead Barbell Press','Shoulders', array['Triceps','Core'],   'barbell',   true,  'Brace; press the bar overhead; finish with biceps by your ears.',    'ex.overhead_press'),
('db-shoulder-press',     'Dumbbell Shoulder Press','Shoulders',array['Triceps'],          'dumbbell',  true,  'Press up and slightly together; don''t bang the bells.',             'ex.db_shoulder_press'),
('lateral-raise',         'Lateral Raise',         'Shoulders', array[]::text[],            'dumbbell',  false, 'Lead with the elbows; raise to shoulder height; lower slowly.',      'ex.lateral_raise'),
('rear-delt-fly',         'Rear Delt Fly',         'Shoulders', array['Back'],              'dumbbell',  false, 'Hinge over; raise out and back; pinch the shoulder blades.',         'ex.rear_delt_fly'),
('pike-push-up',          'Pike Push-up',          'Shoulders', array['Triceps'],           'bodyweight',true,  'Hips high; lower the crown of your head toward the floor.',          'ex.pike_push_up'),
-- Arms
('barbell-curl',          'Barbell Curl',          'Arms',  array['Forearms'],             'barbell',   false, 'Elbows pinned; curl without swinging; control the way down.',        'ex.barbell_curl'),
('hammer-curl',           'Dumbbell Hammer Curl',  'Arms',  array['Forearms'],             'dumbbell',  false, 'Neutral grip; keep wrists straight; no elbow drift.',               'ex.hammer_curl'),
('incline-db-curl',       'Incline Dumbbell Curl', 'Arms',  array[]::text[],               'dumbbell',  false, 'Arms hang back; curl with a deep stretch; squeeze at the top.',      'ex.incline_db_curl'),
('tricep-pushdown',       'Triceps Pushdown',      'Arms',  array[]::text[],               'cable',     false, 'Elbows tight; extend fully; control the return.',                   'ex.tricep_pushdown'),
('overhead-tricep-ext',   'Overhead Triceps Extension','Arms',array[]::text[],             'dumbbell',  false, 'Elbows by your ears; stretch behind the head; extend to lockout.',   'ex.overhead_tricep_ext'),
('dips',                  'Triceps Dips',          'Arms',  array['Chest','Shoulders'],    'bodyweight',true,  'Stay upright for triceps; lower to ~90°; press to lockout.',         'ex.dips'),
-- Core
('plank',                 'Plank',                 'Core',  array[]::text[],               'bodyweight',false, 'Squeeze glutes and abs; one straight line; breathe.',               'ex.plank'),
('hanging-leg-raise',     'Hanging Leg Raise',     'Core',  array[]::text[],               'bodyweight',false, 'No swing; curl the pelvis up; lower with control.',                  'ex.hanging_leg_raise'),
('cable-crunch',          'Cable Crunch',          'Core',  array[]::text[],               'cable',     false, 'Round the spine down; crunch with the abs, not the hips.',           'ex.cable_crunch'),
('russian-twist',         'Russian Twist',         'Core',  array[]::text[],               'dumbbell',  false, 'Lean back; rotate through the trunk; keep the chest tall.',          'ex.russian_twist'),
('crunch',                'Crunch',                'Core',  array[]::text[],               'bodyweight',false, 'Curl the shoulders up; don''t yank the neck; slow negative.',        'ex.crunch')
on conflict (slug) do update set
  name              = excluded.name,
  muscle_group      = excluded.muscle_group,
  secondary_muscles = excluded.secondary_muscles,
  equipment         = excluded.equipment,
  is_compound       = excluded.is_compound,
  form_cue          = excluded.form_cue,
  l10n_key          = excluded.l10n_key;
