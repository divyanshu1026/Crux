/// Exercise how-to guides — the "nobody explains" gap (plan §2, P1 persona).
///
/// Offline, deterministic content: setup steps, form cues, and common mistakes
/// per exercise. Lookup is keyword-based so name variants ("Incline DB Press",
/// "Incline Dumbbell Bench Press") resolve to the same guide, with a safe
/// generic fallback so the sheet never comes up empty.
library;

class ExerciseGuide {
  final String title;

  /// One-line summary of what the movement trains and why it's worth doing.
  final String why;

  /// Numbered how-to steps, in order.
  final List<String> steps;

  /// Short form cues to think about mid-set.
  final List<String> cues;

  /// Mistakes beginners actually make, with the fix baked into the phrasing.
  final List<String> mistakes;

  /// One breathing tip.
  final String breathing;

  const ExerciseGuide({
    required this.title,
    required this.why,
    required this.steps,
    required this.cues,
    required this.mistakes,
    required this.breathing,
  });
}

abstract final class ExerciseGuideLibrary {
  /// Finds the best guide for an exercise name. Never returns null — falls
  /// back to a sensible generic guide keyed off the muscle group.
  static ExerciseGuide find(String exerciseName, {String muscleGroup = ''}) {
    final name = exerciseName.toLowerCase();
    for (final entry in _keyed) {
      if (entry.$1.any(name.contains)) return entry.$2;
    }
    return _generic(exerciseName, muscleGroup);
  }

  /// Ordered (keywords → guide). More specific keys come first so
  /// "goblet squat" doesn't fall through to the barbell squat guide.
  static final List<(List<String>, ExerciseGuide)> _keyed = [
    // ----- Legs / glutes ---------------------------------------------------
    (
      ['goblet squat'],
      const ExerciseGuide(
        title: 'Goblet Squat',
        why: 'A beginner-friendly squat that teaches upright posture — the weight in front balances you naturally.',
        steps: [
          'Hold one dumbbell vertically against your chest, elbows tucked.',
          'Stand with feet shoulder-width, toes turned out slightly.',
          'Sit down between your knees until your elbows touch your thighs.',
          'Drive through your whole foot to stand back up tall.',
        ],
        cues: ['Chest proud', 'Knees track over toes', 'Sit down, not back'],
        mistakes: [
          'Heels lifting — keep your weight spread over the whole foot.',
          'Collapsing knees inward — push them out over your toes.',
          'Cutting depth — go as low as you can with a flat back.',
        ],
        breathing: 'Big breath at the top, hold on the way down, exhale as you stand.',
      )
    ),
    (
      ['front squat'],
      const ExerciseGuide(
        title: 'Front Squat',
        why: 'Squat variation that keeps your torso extra upright and biases the quads.',
        steps: [
          'Rest the bar on your front shoulders, elbows driven high.',
          'Grip just outside shoulders (fingertips under the bar is fine).',
          'Sit straight down, keeping elbows up the whole time.',
          'Drive up through mid-foot to full standing.',
        ],
        cues: ['Elbows high', 'Stay tall', 'Brace before every rep'],
        mistakes: [
          'Elbows dropping — the bar rolls forward; keep them pointed ahead.',
          'Rushing the descent — control down, explode up.',
        ],
        breathing: 'Inhale and brace at the top, exhale through the sticking point on the way up.',
      )
    ),
    (
      ['squat'],
      const ExerciseGuide(
        title: 'Squat',
        why: 'The king of lower-body lifts — quads, glutes and core in one pattern you use every day.',
        steps: [
          'Set the bar on your upper back (not your neck), grip tight.',
          'Stand with feet shoulder-width, toes slightly out.',
          'Take a big breath, brace your core, and sit down between your hips.',
          'Go to at least parallel (hip crease level with knee).',
          'Drive the floor away to stand, exhaling near the top.',
        ],
        cues: ['Brace hard', 'Knees out over toes', 'Whole foot on the floor'],
        mistakes: [
          'Knees caving in — actively push them outward.',
          'Rising hips-first ("good morning" squat) — chest and hips rise together.',
          'Half reps — depth builds strength; lighten the bar if you must.',
        ],
        breathing: 'Inhale + brace at the top, hold during the rep, exhale as you finish standing.',
      )
    ),
    (
      ['leg press'],
      const ExerciseGuide(
        title: 'Leg Press',
        why: 'Big quad and glute work with your back fully supported — great for adding volume safely.',
        steps: [
          'Sit deep in the pad, feet mid-platform at shoulder width.',
          'Release the safeties and lower the platform under control.',
          'Stop when your knees reach ~90° (before your lower back rolls up).',
          'Press through your whole foot without slamming the knees straight.',
        ],
        cues: ['Lower back stays on the pad', 'Control the descent', 'Don\'t lock out hard'],
        mistakes: [
          'Going so deep your hips lift off the pad — that stresses the spine.',
          'Bouncing at the bottom — smooth reps only.',
        ],
        breathing: 'Inhale down, exhale as you press.',
      )
    ),
    (
      ['lunge', 'split squat'],
      const ExerciseGuide(
        title: 'Lunge / Split Squat',
        why: 'Single-leg strength and balance — hits quads and glutes while ironing out side-to-side gaps.',
        steps: [
          'Take a long step (or set your stance with rear foot elevated).',
          'Drop the back knee straight down toward the floor.',
          'Keep your torso tall and front shin fairly vertical.',
          'Push through the front heel to come back up.',
        ],
        cues: ['Tall torso', 'Front heel does the work', 'Straight down, not forward'],
        mistakes: [
          'Short steps that slam the knee past the toes — lengthen your stride.',
          'Wobbling — slow down; balance is part of the exercise.',
        ],
        breathing: 'Inhale as you lower, exhale as you drive up.',
      )
    ),
    (
      ['hip thrust'],
      const ExerciseGuide(
        title: 'Hip Thrust',
        why: 'The most direct glute builder there is — huge hip strength carryover to squats and sprints.',
        steps: [
          'Sit with your upper back against a bench, bar (or weight) over your hips.',
          'Feet flat, shoulder-width, heels close enough to reach a vertical shin at the top.',
          'Tuck your chin and drive your hips up to a straight line.',
          'Squeeze the glutes hard for a second, lower under control.',
        ],
        cues: ['Chin tucked', 'Ribs down', 'Squeeze at the top'],
        mistakes: [
          'Arching the lower back at the top — the finish is a glute squeeze, not a back bend.',
          'Pushing through toes — drive through your heels.',
        ],
        breathing: 'Exhale as you thrust up, inhale on the way down.',
      )
    ),
    (
      ['glute bridge'],
      const ExerciseGuide(
        title: 'Glute Bridge',
        why: 'Bodyweight glute activator — perfect at home and the foundation for hip thrusts.',
        steps: [
          'Lie on your back, knees bent, heels close to your glutes.',
          'Flatten your lower back into the floor.',
          'Drive hips up until knees–hips–shoulders form a line.',
          'Squeeze glutes for 1–2 seconds, lower slowly.',
        ],
        cues: ['Heels close', 'Ribs down', 'Squeeze, don\'t arch'],
        mistakes: [
          'Overarching the lower back at the top — stop at the straight line.',
          'Rushing reps — the squeeze is the whole point.',
        ],
        breathing: 'Exhale up, inhale down.',
      )
    ),
    (
      ['romanian', 'rdl'],
      const ExerciseGuide(
        title: 'Romanian Deadlift',
        why: 'The hamstring and glute builder — teaches the hip hinge every strong lifter relies on.',
        steps: [
          'Hold the bar/dumbbells at your thighs, soft bend in the knees.',
          'Push your hips straight back, letting the weight slide down your legs.',
          'Stop when you feel a strong hamstring stretch (mid-shin-ish).',
          'Drive hips forward to stand tall — don\'t yank with the back.',
        ],
        cues: ['Hips back, not down', 'Flat back always', 'Weight close to your legs'],
        mistakes: [
          'Rounding the back — brace and keep a proud chest.',
          'Bending the knees too much — it becomes a squat; keep them soft and fixed.',
        ],
        breathing: 'Inhale as you hinge down, exhale as you stand.',
      )
    ),
    (
      ['deadlift'],
      const ExerciseGuide(
        title: 'Deadlift',
        why: 'Total-body strength in one lift — posterior chain, grip and core all at once.',
        steps: [
          'Stand with the bar over mid-foot, shins an inch away.',
          'Hinge down and grip just outside your legs.',
          'Flatten your back, pull the slack out of the bar, brace.',
          'Push the floor away — bar drags up your legs to lockout.',
          'Hips and shoulders rise together; reverse the motion down.',
        ],
        cues: ['Bar stays close', 'Neutral spine', 'Push the floor, don\'t pull the bar'],
        mistakes: [
          'Rounding the lower back — reset and lighten the load.',
          'Jerking the bar off the floor — squeeze it up, then accelerate.',
          'Hips shooting up first — lock your brace before you pull.',
        ],
        breathing: 'Big breath + brace before the pull, exhale at lockout or on the floor.',
      )
    ),
    (
      ['hamstring curl', 'leg curl'],
      const ExerciseGuide(
        title: 'Hamstring Curl',
        why: 'Isolates the hamstrings through knee flexion — the half of hamstring training RDLs miss.',
        steps: [
          'Set the pad just above your heels.',
          'Curl your heels toward your glutes under control.',
          'Pause briefly at full flexion.',
          'Lower slowly — the negative is where the growth is.',
        ],
        cues: ['Hips stay down', 'Slow negatives', 'Full range'],
        mistakes: ['Kicking with momentum — halve the weight and own each rep.'],
        breathing: 'Exhale as you curl, inhale as you lower.',
      )
    ),
    (
      ['calf'],
      const ExerciseGuide(
        title: 'Calf Raise',
        why: 'Direct calf work — ankle strength and lower-leg size respond well to full-range reps.',
        steps: [
          'Stand with the balls of your feet on the edge/platform.',
          'Lower your heels for a deep stretch (2 seconds).',
          'Drive up onto your toes as high as possible.',
          'Pause at the top, then lower slowly.',
        ],
        cues: ['Full stretch at the bottom', 'Pause at the top', 'No bouncing'],
        mistakes: ['Short, bouncy reps — the stretch and pause do the work.'],
        breathing: 'Exhale up, inhale down.',
      )
    ),
    // ----- Chest -----------------------------------------------------------
    (
      ['incline'],
      const ExerciseGuide(
        title: 'Incline Press',
        why: 'Targets the upper chest and front delts — fills out the top of the chest that flat pressing misses.',
        steps: [
          'Set the bench to ~30° incline.',
          'Start with dumbbells (or the bar) over your upper chest.',
          'Lower under control until you feel a chest stretch.',
          'Press up and slightly inward to lockout.',
        ],
        cues: ['Shoulder blades pinched', 'Elbows ~45° from torso', 'Wrists stacked over elbows'],
        mistakes: [
          'Setting the incline too steep — over 45° turns it into a shoulder press.',
          'Flaring elbows to 90° — that grinds the shoulders.',
        ],
        breathing: 'Inhale down, exhale as you press.',
      )
    ),
    (
      ['bench press', 'db press', 'dumbbell press', 'chest press'],
      const ExerciseGuide(
        title: 'Bench Press',
        why: 'The classic chest, shoulder and triceps builder — the upper-body strength benchmark.',
        steps: [
          'Lie with eyes under the bar, feet planted on the floor.',
          'Pinch your shoulder blades together and keep them pinned.',
          'Grip so forearms are vertical at the bottom.',
          'Lower the bar to your mid-chest under control.',
          'Press up and slightly back toward your face to lockout.',
        ],
        cues: ['Shoulder blades pinched', 'Feet drive into the floor', 'Bar touches, never bounces'],
        mistakes: [
          'Bouncing the bar off your chest — pause a beat instead.',
          'Flaring elbows straight out — keep them ~45° from your torso.',
          'Lifting your butt off the bench — keep three points of contact.',
        ],
        breathing: 'Inhale on the way down, exhale as you press.',
      )
    ),
    (
      ['fly'],
      const ExerciseGuide(
        title: 'Chest Fly',
        why: 'Stretches and isolates the chest — great pump work after your presses.',
        steps: [
          'Start with arms above your chest, slight bend in the elbows.',
          'Open your arms in a wide arc until you feel a deep chest stretch.',
          'Keep the same elbow bend the whole time.',
          'Squeeze the weights back together like hugging a barrel.',
        ],
        cues: ['Hug a barrel', 'Elbows locked at one angle', 'Stretch, then squeeze'],
        mistakes: [
          'Turning it into a press by bending the elbows more at the bottom.',
          'Going too heavy — flys are a feel exercise, not an ego lift.',
        ],
        breathing: 'Inhale as you open, exhale as you squeeze together.',
      )
    ),
    (
      ['pike push'],
      const ExerciseGuide(
        title: 'Pike Push-up',
        why: 'A bodyweight shoulder press — builds pressing strength with zero equipment.',
        steps: [
          'From push-up position, walk your feet in so hips point high (an inverted V).',
          'Look between your feet, hands shoulder-width.',
          'Bend your elbows to lower the crown of your head toward the floor.',
          'Press back up to the V.',
        ],
        cues: ['Hips high the whole time', 'Head travels down, not forward', 'Elbows ~45°'],
        mistakes: ['Letting hips sag — that turns it into a bad push-up.'],
        breathing: 'Inhale down, exhale up.',
      )
    ),
    (
      ['push-up', 'push up', 'pushup'],
      const ExerciseGuide(
        title: 'Push-up',
        why: 'The everywhere exercise — chest, triceps and core with nothing but the floor.',
        steps: [
          'Hands slightly wider than shoulders, body in one straight line.',
          'Squeeze glutes and abs before you move.',
          'Lower your chest to just above the floor, elbows ~45°.',
          'Press the floor away to full lockout.',
        ],
        cues: ['One straight line', 'Elbows ~45°, not flared', 'Full range every rep'],
        mistakes: [
          'Sagging hips — brace like a plank.',
          'Half reps — elevate your hands on a bench instead and go full range.',
        ],
        breathing: 'Inhale down, exhale up.',
      )
    ),
    // ----- Back ------------------------------------------------------------
    (
      ['lat pulldown', 'pulldown'],
      const ExerciseGuide(
        title: 'Lat Pulldown',
        why: 'Builds the lats (back width) — and the strength ladder toward your first pull-up.',
        steps: [
          'Grip the bar a bit wider than shoulders, sit with thighs locked under the pad.',
          'Lean back slightly and lift your chest.',
          'Pull the bar to your collarbone, leading with your elbows.',
          'Control it all the way back up to a full stretch.',
        ],
        cues: ['Elbows to your pockets', 'Chest up', 'No swinging'],
        mistakes: [
          'Pulling behind the neck — always to the collarbone.',
          'Using body English — if you rock to move it, drop the weight.',
        ],
        breathing: 'Exhale as you pull down, inhale on the way up.',
      )
    ),
    (
      ['pull-up', 'pull up', 'pullup', 'chin'],
      const ExerciseGuide(
        title: 'Pull-up',
        why: 'The bodyweight back-builder — lats, biceps and grip in the most honest strength test there is.',
        steps: [
          'Hang from the bar, hands just outside shoulders.',
          'Squeeze your shoulder blades down before you bend your arms.',
          'Drive your elbows toward your hips until your chin clears the bar.',
          'Lower all the way to a dead hang under control.',
        ],
        cues: ['Start every rep from a dead hang', 'Chest to the bar', 'No kipping'],
        mistakes: [
          'Half reps at the top or bottom — full range or use assistance.',
          'Swinging — brace your core; slow is strong.',
        ],
        breathing: 'Exhale as you pull, inhale on the way down.',
      )
    ),
    (
      ['doorway row'],
      const ExerciseGuide(
        title: 'Doorway Row',
        why: 'A home-friendly row — trains the same back muscles as cable rows using a doorframe.',
        steps: [
          'Grip both sides of a sturdy doorframe, feet close to the door.',
          'Lean back with arms straight, body in a line.',
          'Pull your chest to the frame, squeezing your shoulder blades.',
          'Lower yourself back with control.',
        ],
        cues: ['Body stays rigid', 'Squeeze the blades together', 'Slow negatives'],
        mistakes: ['Bending at the hips — keep the plank line from head to heels.'],
        breathing: 'Exhale as you pull, inhale as you extend.',
      )
    ),
    (
      ['seated cable row', 'cable row'],
      const ExerciseGuide(
        title: 'Seated Cable Row',
        why: 'Mid-back thickness with constant cable tension — one of the best-feeling rows there is.',
        steps: [
          'Sit tall, knees soft, grab the handle.',
          'Pull the handle to your navel, elbows brushing your sides.',
          'Squeeze your shoulder blades for a beat.',
          'Let your arms extend fully without your torso collapsing forward.',
        ],
        cues: ['Tall chest', 'Elbows brush your ribs', 'Blades squeeze together'],
        mistakes: ['Rocking back and forth — your torso stays near vertical.'],
        breathing: 'Exhale as you row, inhale as you release.',
      )
    ),
    (
      ['row'],
      const ExerciseGuide(
        title: 'Bent-Over Row',
        why: 'Back thickness and posture armor — the pull that balances all your pressing.',
        steps: [
          'Hinge at your hips to ~45°, back flat, knees soft.',
          'Let the weight hang under your shoulders.',
          'Row to your lower ribs, elbows brushing your sides.',
          'Lower under control without standing up between reps.',
        ],
        cues: ['Flat back', 'Pull with elbows, not hands', 'Squeeze at the top'],
        mistakes: [
          'Standing up as you row (hips doing the work) — hold the hinge.',
          'Yanking with biceps — think "elbows to the ceiling".',
        ],
        breathing: 'Exhale as you row up, inhale as you lower.',
      )
    ),
    (
      ['face pull'],
      const ExerciseGuide(
        title: 'Face Pull',
        why: 'Rear delts and upper back — the movement that keeps pressing shoulders healthy.',
        steps: [
          'Set a rope at face height, grab with thumbs toward you.',
          'Pull the rope toward your forehead, splitting it apart.',
          'Finish with knuckles beside your ears, elbows high.',
          'Return slowly to a full stretch.',
        ],
        cues: ['Elbows high', 'Pull apart, not just back', 'Light weight, perfect reps'],
        mistakes: ['Loading too heavy and turning it into a row — stay strict.'],
        breathing: 'Exhale as you pull, inhale on the return.',
      )
    ),
    // ----- Shoulders ---------------------------------------------------------
    (
      ['lateral raise'],
      const ExerciseGuide(
        title: 'Lateral Raise',
        why: 'Isolates the side delts — the muscle that makes shoulders look wide.',
        steps: [
          'Stand with dumbbells at your sides, slight lean forward.',
          'Raise your arms out to the sides, leading with your elbows.',
          'Stop at shoulder height (hands like pouring a jug slightly).',
          'Lower twice as slowly as you lifted.',
        ],
        cues: ['Lead with elbows', 'Stop at shoulder height', 'Slow negatives'],
        mistakes: [
          'Swinging the weights up — if you rock, it\'s too heavy.',
          'Shrugging — keep your traps quiet, delts do the work.',
        ],
        breathing: 'Exhale as you raise, inhale as you lower.',
      )
    ),
    (
      ['rear delt'],
      const ExerciseGuide(
        title: 'Rear Delt Fly',
        why: 'Hits the back of the shoulders — the most neglected (and posture-saving) delt.',
        steps: [
          'Hinge forward to ~45° with light dumbbells hanging down.',
          'Raise your arms out wide, slight elbow bend.',
          'Squeeze your shoulder blades at the top.',
          'Lower slowly without standing up.',
        ],
        cues: ['Stay hinged', 'Lead with pinkies', 'Light and strict'],
        mistakes: ['Using the lower back to swing — freeze your torso.'],
        breathing: 'Exhale up, inhale down.',
      )
    ),
    (
      ['overhead', 'shoulder press', 'ohp'],
      const ExerciseGuide(
        title: 'Overhead Press',
        why: 'The full-body pressing lift — shoulders, triceps and a core that has to hold it all up.',
        steps: [
          'Start with the bar/dumbbells at your front shoulders.',
          'Squeeze glutes and brace your core hard.',
          'Press straight up, moving your head slightly back out of the way.',
          'Finish with biceps by your ears, weight over mid-foot.',
          'Lower under control back to the shoulders.',
        ],
        cues: ['Glutes tight (no back lean)', 'Biceps to ears at lockout', 'Bar path is a straight line'],
        mistakes: [
          'Arching the lower back — that\'s your core failing; brace or lighten.',
          'Pressing around your face — move your head, not the bar path.',
        ],
        breathing: 'Inhale + brace before the press, exhale at lockout.',
      )
    ),
    // ----- Arms --------------------------------------------------------------
    (
      ['hammer curl'],
      const ExerciseGuide(
        title: 'Hammer Curl',
        why: 'Neutral-grip curls that build the brachialis and forearms — thicker-looking arms.',
        steps: [
          'Hold dumbbells with palms facing each other.',
          'Pin your elbows to your sides.',
          'Curl up until the weights near your shoulders.',
          'Lower slowly with the same neutral grip.',
        ],
        cues: ['Palms face each other throughout', 'Elbows pinned', 'No swinging'],
        mistakes: ['Leaning back to lift — stand tall, or sit down to enforce it.'],
        breathing: 'Exhale up, inhale down.',
      )
    ),
    (
      ['curl'],
      const ExerciseGuide(
        title: 'Biceps Curl',
        why: 'Direct biceps work — simple, effective, and everyone\'s favorite for a reason.',
        steps: [
          'Stand tall, weights at your sides, palms forward.',
          'Pin your elbows to your ribs.',
          'Curl the weight up without moving your upper arms.',
          'Squeeze at the top, lower over 2–3 seconds.',
        ],
        cues: ['Elbows glued to your sides', 'Wrists straight', 'Slow negatives'],
        mistakes: [
          'Swinging with your back — if you rock, drop the weight.',
          'Half range — full stretch at the bottom every rep.',
        ],
        breathing: 'Exhale as you curl, inhale as you lower.',
      )
    ),
    (
      ['pushdown'],
      const ExerciseGuide(
        title: 'Triceps Pushdown',
        why: 'Constant-tension triceps work — the easiest way to safely overload the arms\' biggest muscle.',
        steps: [
          'Face the cable, grab the bar/rope, elbows tucked to your sides.',
          'Push down to full elbow lockout.',
          'Squeeze the triceps for a beat.',
          'Let it return only until forearms pass parallel — elbows never move.',
        ],
        cues: ['Elbows frozen in place', 'Full lockout', 'Lean slightly forward'],
        mistakes: ['Letting elbows flare and drift forward — pin them down.'],
        breathing: 'Exhale as you push down, inhale on the return.',
      )
    ),
    (
      ['tricep', 'extension'],
      const ExerciseGuide(
        title: 'Triceps Extension',
        why: 'Stretches the triceps under load — the long head grows best from overhead work.',
        steps: [
          'Hold one dumbbell overhead with both hands.',
          'Keep elbows close to your ears.',
          'Lower the weight behind your head until you feel a stretch.',
          'Extend back to lockout without moving your upper arms.',
        ],
        cues: ['Elbows by your ears', 'Deep stretch behind the head', 'Only forearms move'],
        mistakes: ['Flaring elbows out wide — squeeze them inward the whole set.'],
        breathing: 'Inhale as you lower, exhale as you extend.',
      )
    ),
    (
      ['dip'],
      const ExerciseGuide(
        title: 'Dips',
        why: 'Bodyweight triceps and chest strength — the push-up\'s harder sibling.',
        steps: [
          'Support yourself on parallel bars (or a sturdy bench edge).',
          'Stay upright for triceps; lean forward for chest.',
          'Lower until elbows hit ~90°.',
          'Press back to a full lockout.',
        ],
        cues: ['Shoulders away from ears', 'Control the depth', 'Lockout every rep'],
        mistakes: ['Dropping too deep too soon — build range gradually.'],
        breathing: 'Inhale down, exhale up.',
      )
    ),
    // ----- Core --------------------------------------------------------------
    (
      ['plank tap'],
      const ExerciseGuide(
        title: 'Plank Tap',
        why: 'A plank with anti-rotation — your core fights the twist as each hand lifts.',
        steps: [
          'Set a push-up-position plank, feet slightly wide.',
          'Tap your left shoulder with your right hand.',
          'Replace and switch sides, keeping hips dead still.',
        ],
        cues: ['Hips frozen — no rocking', 'Squeeze glutes', 'Slow taps'],
        mistakes: ['Hips swinging side to side — widen your feet and slow down.'],
        breathing: 'Steady breathing — never hold it.',
      )
    ),
    (
      ['plank'],
      const ExerciseGuide(
        title: 'Plank',
        why: 'The foundation of core strength — teaches your trunk to resist collapse under load.',
        steps: [
          'Forearms down, elbows under shoulders.',
          'Form one straight line from head to heels.',
          'Squeeze glutes and abs like you\'re about to be poked.',
          'Hold — quality over duration.',
        ],
        cues: ['Straight line', 'Glutes tight', 'Push the floor away'],
        mistakes: [
          'Hips sagging or piking up — film yourself once to check.',
          'Holding sloppy long planks — 30 perfect seconds beat 2 saggy minutes.',
        ],
        breathing: 'Slow, steady breaths the whole hold.',
      )
    ),
    (
      ['russian twist'],
      const ExerciseGuide(
        title: 'Russian Twist',
        why: 'Rotational core work — trains the obliques through the twisting your abs crave.',
        steps: [
          'Sit with knees bent, lean back to ~45°, chest tall.',
          'Hold a weight at your chest (or hands together).',
          'Rotate your whole trunk to one side, then the other.',
          'Move with control — the turn comes from your ribs, not your arms.',
        ],
        cues: ['Chest stays tall', 'Rotate the trunk, not just arms', 'Slow and controlled'],
        mistakes: ['Rounding the back — sit tall even while leaning.'],
        breathing: 'Exhale on each twist.',
      )
    ),
    (
      ['leg raise'],
      const ExerciseGuide(
        title: 'Hanging Leg Raise',
        why: 'Lower-ab strength and grip in one — curl the pelvis, not just the legs.',
        steps: [
          'Hang from a bar, shoulders engaged.',
          'Raise your legs (bent knees is fine) by curling your pelvis up.',
          'Lower slowly without swinging.',
        ],
        cues: ['Curl the pelvis', 'No swing between reps', 'Slow negatives'],
        mistakes: ['Swinging for momentum — pause dead still between reps.'],
        breathing: 'Exhale as you raise, inhale as you lower.',
      )
    ),
    (
      ['crunch'],
      const ExerciseGuide(
        title: 'Crunch',
        why: 'Simple, direct ab flexion — done slowly, it\'s all you need for the six-pack muscles.',
        steps: [
          'Lie back, knees bent, hands lightly by your temples.',
          'Curl your shoulders up by squeezing your abs.',
          'Pause at the top — your lower back stays on the floor.',
          'Lower over 2 seconds.',
        ],
        cues: ['Curl, don\'t sit up', 'Chin off your chest', 'Slow negatives'],
        mistakes: ['Yanking your neck with your hands — fingertips touch, never pull.'],
        breathing: 'Exhale as you crunch up, inhale down.',
      )
    ),
  ];

  static ExerciseGuide _generic(String name, String muscleGroup) {
    final target = muscleGroup.isEmpty ? 'the target muscle' : muscleGroup.toLowerCase();
    return ExerciseGuide(
      title: name,
      why: 'Trains $target. Master light weights with perfect form before adding load.',
      steps: const [
        'Set up so the movement path feels stable and repeatable.',
        'Move through the full range slowly on your first sets.',
        'Control the lowering phase — 2–3 seconds down.',
        'Stop the set when your form starts to break, not when you collapse.',
      ],
      cues: const ['Full range of motion', 'Control the negative', 'Brace your core'],
      mistakes: const [
        'Loading up before the movement feels smooth — form first, weight second.',
        'Rushing reps — slow reps build more muscle and protect your joints.',
      ],
      breathing: 'Exhale on the effort (lifting), inhale on the way back.',
    );
  }
}
