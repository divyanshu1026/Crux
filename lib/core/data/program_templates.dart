import '../models/models.dart';

/// Curated schedule templates. Onboarding picks the best match for the user's
/// sex, training days, and goal; Schedule can also browse the full sex-filtered
/// catalog. These are coach-authored plans (not live LLM output) — presented as
/// the personalized schedule the user reviews before entering the app.
abstract final class ProgramTemplates {
  // ---------------------------------------------------------------------------
  // Catalog API
  // ---------------------------------------------------------------------------

  /// The full plan library — every template, shown to everyone. Training
  /// plans aren't gendered; users pick by goal, not by who they are. The
  /// sex-based lists below only bias the *default* recommendation order.
  static List<Program> allTemplates() {
    final seen = <String>{};
    final all = <Program>[];
    for (final t in [...maleCatalog(), ...femaleCatalog()]) {
      if (seen.add(t.id)) all.add(t);
    }
    return all;
  }

  static List<Program> forSex(String sex) {
    switch (sex) {
      case 'Female':
        return femaleCatalog();
      case 'Male':
        return maleCatalog();
      default:
        // Prefer-not-to-say: show a balanced mix (3 male + 2 female staples).
        return [
          pplppHypertrophy(),
          upperLowerStrength(),
          fullBodyBeginner(),
          gluteFocusFourDay(),
          fullBodyTone(),
        ];
    }
  }

  static List<Program> maleCatalog() => [
        pplppHypertrophy(),
        upperLowerStrength(),
        fullBodyBeginner(),
        classicPpl(),
        pushPullPower(),
        ...coverageCatalog(),
      ];

  static List<Program> femaleCatalog() => [
        gluteFocusFourDay(),
        fullBodyTone(),
        upperLowerGluteBias(),
        pplGluteEmphasis(),
        homeDumbbellSculpt(),
        ...coverageCatalog(),
      ];

  /// Plans that exist to cover schedules and equipment the curated catalog
  /// misses — two training days, and home training beyond three days.
  /// Shown to everyone. (Six days is already covered by Classic PPL x 2.)
  static List<Program> coverageCatalog() => [
        twoDayFullBody(),
        homeUpperLowerFourDay(),
      ];

  /// Picks the best template for [profile]: sex catalog → closest day count →
  /// goal affinity, then remaps weekday assignments to the user's chosen days.
  static Program pickBest(UserProfile profile) {
    // Score the whole library, not the sex-filtered slice: the slice only sets
    // the tie-break order, and a filter that hides the right plan from someone
    // because of their sex is worse than no filter at all.
    final preferred = forSex(profile.sex);
    final catalog = [
      ...preferred,
      ...allTemplates().where((t) => !preferred.any((p) => p.id == t.id)),
    ];
    final wantDays = profile.daysPerWeek.length.clamp(2, 6);

    Program best = catalog.first;
    var bestScore = -99999;

    for (var i = 0; i < catalog.length; i++) {
      final t = catalog[i];
      var score = 0;

      // 1. Weekly frequency — still the strongest signal, but no longer able
      //    to outvote the hard constraints below.
      //
      //    Measured in weekdays trained, not sessions written: "Classic PPL x2"
      //    is three sessions run across six days, so scoring it as a 3-day plan
      //    hid it from everyone who asked to train six times a week.
      //    The penalty per missing day is deliberately larger than the goal
      //    bonus below: how many days someone can train is a fact they told
      //    us, while goal affinity is a preference. A plan they cannot fit
      //    into their week is the wrong plan however well it matches the goal.
      final frequency =
          t.dayAssignments.isNotEmpty ? t.dayAssignments.length : t.days.length;
      score -= (frequency - wantDays).abs() * 50;

      // 2. Goal affinity.
      final name = '${t.name} ${t.description}'.toLowerCase();
      switch (profile.goal) {
        case 'Get Stronger':
          if (name.contains('strength') || name.contains('power')) score += 40;
          break;
        case 'Lose Fat & Tone':
          if (name.contains('tone') || name.contains('sculpt')) score += 40;
          break;
        case 'Build Muscle':
          if (name.contains('hypertrophy') ||
              name.contains('muscle') ||
              name.contains('glute')) {
            score += 40;
          }
          break;
        case 'General Fitness':
          if (name.contains('full body') || name.contains('beginner')) {
            score += 40;
          }
          break;
      }

      final exercises = t.days.expand((d) => d.exercises).toList();

      // 3. Equipment — a hard constraint, judged on what the plan actually
      //    prescribes rather than what its name suggests. Handing a barbell
      //    program to someone training at home with dumbbells makes the whole
      //    plan unusable, so this has to be able to outweigh day count.
      final unavailable = _unavailableEquipment(profile.equipment);
      if (unavailable.isNotEmpty) {
        final blocked =
            exercises.where((e) => unavailable.contains(e.equipment)).length;
        final share = exercises.isEmpty ? 0.0 : blocked / exercises.length;
        score -= (share * 300).round();
      }

      // 4. Experience — a first-timer on a 5-day split quits in week two, so
      //    this outweighs even an exact frequency match. Someone new who says
      //    "5 days" is better served by 3-4 days they actually keep doing.
      if (profile.experience == 'Never trained') {
        if (t.days.length >= 5) score -= 120;
        if (name.contains('beginner') || name.contains('full body')) {
          score += 50;
        }
      } else if (profile.experience == '2+ years' && t.days.length <= 2) {
        score -= 30;
      }

      // 5. Injuries — prefer plans that lean on the flagged area least.
      for (final injury in profile.injuries) {
        final risky = _riskyMuscles[injury];
        if (risky == null) continue;
        final hits =
            exercises.where((e) => risky.contains(e.muscleGroup)).length;
        score -= hits * 6;
      }

      // Stable tie-break: earlier in the preferred order wins.
      score -= i;

      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }

    return best;
  }

  /// Equipment a user cannot use, by their onboarding answer.
  static Set<String> _unavailableEquipment(String equipment) {
    switch (equipment) {
      case 'Dumbbells only':
        return const {'Barbell', 'Machine', 'Cable'};
      case 'Minimal home':
        return const {'Barbell', 'Machine', 'Cable'};
      default: // 'Full gym'
        return const {};
    }
  }

  /// Muscle groups whose loaded work tends to aggravate each flagged injury,
  /// in the catalog's own vocabulary (Legs / Back / Shoulders / Chest / Arms /
  /// Core). Coarse on purpose: this only biases which template is offered.
  /// Swapping individual movements is the AI planner's job, and it can see the
  /// injury directly.
  static const _riskyMuscles = {
    'Shoulder': {'Shoulders', 'Chest'},
    'Knee': {'Legs'},
    'Lower back': {'Legs', 'Back'},
  };

  // ---------------------------------------------------------------------------
  // Shared exercise helper
  // ---------------------------------------------------------------------------

  static Exercise _ex(
    String day,
    int i,
    String name,
    String muscle,
    String equipment,
    int sets,
    String reps,
    int rest,
    double weight,
  ) =>
      Exercise(
        id: '${day}_$i',
        name: name,
        muscleGroup: muscle,
        equipment: equipment,
        targetSets: sets,
        targetReps: reps,
        restTimeSeconds: rest,
        suggestedWeight: weight,
      );

  // ===========================================================================
  // MALE TEMPLATES
  // ===========================================================================

  /// 5-day PPLPP hypertrophy (existing coach plan).
  static Program pplppHypertrophy() {
    final pullA = WorkoutDay(
      id: 'pull_a',
      name: 'Pull A — Back Thickness',
      exercises: [
        _ex('pa', 1, 'Barbell Row', 'Back', 'Barbell', 4, '6-8', 120, 50),
        _ex('pa', 2, 'Lat Pulldown', 'Back', 'Cable', 3, '8-10', 90, 45),
        _ex('pa', 3, 'Chest-Supported Row', 'Back', 'Machine', 3, '10-12', 90, 40),
        _ex('pa', 4, 'Rear Delt Fly', 'Shoulders', 'Dumbbell', 3, '12-15', 60, 8),
        _ex('pa', 5, 'EZ-Bar Curl', 'Arms', 'Barbell', 3, '8-10', 60, 25),
        _ex('pa', 6, 'Hammer Curl', 'Arms', 'Dumbbell', 2, '12-15', 60, 10),
      ],
    );
    final pushA = WorkoutDay(
      id: 'push_a',
      name: 'Push A — Chest Strength',
      exercises: [
        _ex('sa', 1, 'Bench Press', 'Chest', 'Barbell', 4, '6-8', 120, 60),
        _ex('sa', 2, 'Seated Shoulder Press', 'Shoulders', 'Barbell', 3, '8-10', 90, 35),
        _ex('sa', 3, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 22),
        _ex('sa', 4, 'Cable Lateral Raise', 'Shoulders', 'Cable', 3, '12-15', 60, 7),
        _ex('sa', 5, 'Overhead Triceps Extension', 'Arms', 'Dumbbell', 3, '10-12', 60, 15),
        _ex('sa', 6, 'Triceps Pushdown', 'Arms', 'Cable', 2, '12-15', 60, 25),
      ],
    );
    final legs = WorkoutDay(
      id: 'legs',
      name: 'Legs — Train It Hard',
      exercises: [
        _ex('lg', 1, 'Back Squat', 'Legs', 'Barbell', 4, '6-8', 150, 70),
        _ex('lg', 2, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 60),
        _ex('lg', 3, 'Leg Press', 'Legs', 'Machine', 3, '10-12', 90, 120),
        _ex('lg', 4, 'Hip Thrust', 'Legs', 'Barbell', 3, '8-12', 90, 60),
        _ex('lg', 5, 'Seated Leg Curl', 'Legs', 'Machine', 3, '12-15', 90, 35),
        _ex('lg', 6, 'Leg Extension', 'Legs', 'Machine', 3, '12-15', 60, 35),
        _ex('lg', 7, 'Standing Calf Raise', 'Legs', 'Machine', 4, '12-15', 60, 40),
      ],
    );
    final pullB = WorkoutDay(
      id: 'pull_b',
      name: 'Pull B — Width & Arms',
      exercises: [
        _ex('pb', 1, 'Pull-up', 'Back', 'Bodyweight', 4, '6-10', 120, 0),
        _ex('pb', 2, 'Seated Cable Row', 'Back', 'Cable', 3, '10-12', 90, 45),
        _ex('pb', 3, 'Single-Arm Dumbbell Row', 'Back', 'Dumbbell', 3, '10-12', 90, 24),
        _ex('pb', 4, 'Face Pull', 'Back', 'Cable', 3, '15-20', 60, 15),
        _ex('pb', 5, 'Incline Dumbbell Curl', 'Arms', 'Dumbbell', 3, '10-12', 60, 10),
        _ex('pb', 6, 'Preacher Curl', 'Arms', 'Cable', 2, '12-15', 60, 20),
      ],
    );
    final pushB = WorkoutDay(
      id: 'push_b',
      name: 'Push B — Delts & Arms',
      exercises: [
        _ex('sb', 1, 'Incline Barbell Press', 'Chest', 'Barbell', 4, '8-10', 120, 50),
        _ex('sb', 2, 'Machine Chest Press', 'Chest', 'Machine', 3, '10-12', 90, 40),
        _ex('sb', 3, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '10-12', 90, 16),
        _ex('sb', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 4, '12-15', 60, 8),
        _ex('sb', 5, 'Triceps Pushdown', 'Arms', 'Cable', 3, '10-12', 60, 25),
        _ex('sb', 6, 'Overhead Triceps Extension', 'Arms', 'Dumbbell', 2, '12-15', 60, 15),
      ],
    );

    return Program(
      id: 'pplpp_hypertrophy',
      name: 'PPLPP Hypertrophy',
      description:
          'Pull / Push / Legs / Pull / Push — upper 2×/week, one hard leg day. Built for muscle size.',
      days: [pullA, pushA, legs, pullB, pushB],
      whyFitsParagraph:
          'Day A leans heavy and compound; Day B adds volume and different angles so the second Pull and Push grow you instead of repeating. Upper body hits twice weekly; legs get one loaded session.',
      dayAssignments: const {
        'Mon': 'pull_a',
        'Tue': 'push_a',
        'Wed': 'legs',
        'Thu': 'pull_b',
        'Fri': 'push_b',
      },
    );
  }

  /// 4-day upper/lower strength.
  static Program upperLowerStrength() {
    final upperA = WorkoutDay(
      id: 'ul_ua',
      name: 'Upper A — Press & Pull',
      exercises: [
        _ex('ua', 1, 'Bench Press', 'Chest', 'Barbell', 4, '4-6', 150, 70),
        _ex('ua', 2, 'Barbell Row', 'Back', 'Barbell', 4, '4-6', 120, 55),
        _ex('ua', 3, 'Overhead Press', 'Shoulders', 'Barbell', 3, '6-8', 120, 40),
        _ex('ua', 4, 'Lat Pulldown', 'Back', 'Cable', 3, '8-10', 90, 50),
        _ex('ua', 5, 'Triceps Pushdown', 'Arms', 'Cable', 3, '8-12', 60, 30),
      ],
    );
    final lowerA = WorkoutDay(
      id: 'ul_la',
      name: 'Lower A — Squat Focus',
      exercises: [
        _ex('la', 1, 'Back Squat', 'Legs', 'Barbell', 4, '4-6', 180, 80),
        _ex('la', 2, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '6-8', 150, 70),
        _ex('la', 3, 'Leg Press', 'Legs', 'Machine', 3, '8-10', 120, 140),
        _ex('la', 4, 'Seated Leg Curl', 'Legs', 'Machine', 3, '10-12', 90, 40),
        _ex('la', 5, 'Standing Calf Raise', 'Legs', 'Machine', 4, '8-12', 60, 50),
      ],
    );
    final upperB = WorkoutDay(
      id: 'ul_ub',
      name: 'Upper B — Volume',
      exercises: [
        _ex('ub', 1, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 4, '6-8', 120, 26),
        _ex('ub', 2, 'Pull-up', 'Back', 'Bodyweight', 4, '5-8', 120, 0),
        _ex('ub', 3, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-10', 90, 18),
        _ex('ub', 4, 'Seated Cable Row', 'Back', 'Cable', 3, '8-12', 90, 50),
        _ex('ub', 5, 'EZ-Bar Curl', 'Arms', 'Barbell', 3, '8-12', 60, 28),
      ],
    );
    final lowerB = WorkoutDay(
      id: 'ul_lb',
      name: 'Lower B — Hinge Focus',
      exercises: [
        _ex('lb', 1, 'Conventional Deadlift', 'Legs', 'Barbell', 3, '3-5', 180, 100),
        _ex('lb', 2, 'Front Squat', 'Legs', 'Barbell', 3, '6-8', 150, 60),
        _ex('lb', 3, 'Walking Lunge', 'Legs', 'Dumbbell', 3, '8-10', 90, 18),
        _ex('lb', 4, 'Leg Extension', 'Legs', 'Machine', 3, '10-12', 60, 40),
        _ex('lb', 5, 'Seated Calf Raise', 'Legs', 'Machine', 4, '10-15', 60, 35),
      ],
    );

    return Program(
      id: 'upper_lower_strength',
      name: 'Upper / Lower Strength',
      description:
          'Four days: heavy compounds in the 3–8 rep zone. Built to get stronger.',
      days: [upperA, lowerA, upperB, lowerB],
      whyFitsParagraph:
          'Upper/Lower lets you hit each muscle twice a week with enough recovery for heavy loads. Day A is strength-biased; Day B adds volume without junk fatigue.',
      dayAssignments: const {
        'Mon': 'ul_ua',
        'Tue': 'ul_la',
        'Thu': 'ul_ub',
        'Fri': 'ul_lb',
      },
    );
  }

  /// 3-day full body beginner.
  static Program fullBodyBeginner() {
    final a = WorkoutDay(
      id: 'fb_a',
      name: 'Full Body A',
      exercises: [
        _ex('fa', 1, 'Goblet Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 20),
        _ex('fa', 2, 'Dumbbell Bench Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 18),
        _ex('fa', 3, 'Dumbbell Row', 'Back', 'Dumbbell', 3, '8-12', 90, 16),
        _ex('fa', 4, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-12', 75, 12),
        _ex('fa', 5, 'Plank Hold', 'Core', 'Bodyweight', 3, '30-45s', 45, 0),
      ],
    );
    final b = WorkoutDay(
      id: 'fb_b',
      name: 'Full Body B',
      exercises: [
        _ex('fb', 1, 'Romanian Deadlift', 'Legs', 'Dumbbell', 3, '8-12', 90, 24),
        _ex('fb', 2, 'Push-ups', 'Chest', 'Bodyweight', 3, '8-15', 75, 0),
        _ex('fb', 3, 'Lat Pulldown', 'Back', 'Cable', 3, '8-12', 90, 40),
        _ex('fb', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 60, 6),
        _ex('fb', 5, 'Dumbbell Curl', 'Arms', 'Dumbbell', 2, '10-12', 60, 10),
      ],
    );
    final c = WorkoutDay(
      id: 'fb_c',
      name: 'Full Body C',
      exercises: [
        _ex('fc', 1, 'Walking Lunge', 'Legs', 'Dumbbell', 3, '8-10', 90, 12),
        _ex('fc', 2, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 16),
        _ex('fc', 3, 'Seated Cable Row', 'Back', 'Cable', 3, '10-12', 90, 40),
        _ex('fc', 4, 'Triceps Pushdown', 'Arms', 'Cable', 2, '10-15', 60, 20),
        _ex('fc', 5, 'Dead Bug', 'Core', 'Bodyweight', 3, '8-10', 45, 0),
      ],
    );

    return Program(
      id: 'full_body_beginner',
      name: 'Full Body Beginner',
      description:
          'Three full-body days. Simple compounds, room to recover, easy to stick with.',
      days: [a, b, c],
      whyFitsParagraph:
          'Full body three times a week is the most forgiving way to learn form and build a habit. Every session trains the big patterns without burying you in volume.',
      dayAssignments: const {
        'Mon': 'fb_a',
        'Wed': 'fb_b',
        'Fri': 'fb_c',
      },
    );
  }

  /// 6-day classic PPL × 2.
  static Program classicPpl() {
    final push = WorkoutDay(
      id: 'ppl_push',
      name: 'Push',
      exercises: [
        _ex('pp', 1, 'Bench Press', 'Chest', 'Barbell', 4, '6-10', 120, 65),
        _ex('pp', 2, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 22),
        _ex('pp', 3, 'Overhead Press', 'Shoulders', 'Barbell', 3, '6-10', 120, 40),
        _ex('pp', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 60, 8),
        _ex('pp', 5, 'Triceps Pushdown', 'Arms', 'Cable', 3, '10-15', 60, 28),
      ],
    );
    final pull = WorkoutDay(
      id: 'ppl_pull',
      name: 'Pull',
      exercises: [
        _ex('pl', 1, 'Deadlift', 'Back', 'Barbell', 3, '3-5', 180, 100),
        _ex('pl', 2, 'Pull-up', 'Back', 'Bodyweight', 3, '6-10', 120, 0),
        _ex('pl', 3, 'Barbell Row', 'Back', 'Barbell', 3, '6-10', 120, 55),
        _ex('pl', 4, 'Face Pull', 'Back', 'Cable', 3, '12-15', 60, 18),
        _ex('pl', 5, 'Barbell Curl', 'Arms', 'Barbell', 3, '8-12', 60, 28),
      ],
    );
    final legs = WorkoutDay(
      id: 'ppl_legs',
      name: 'Legs',
      exercises: [
        _ex('pg', 1, 'Back Squat', 'Legs', 'Barbell', 4, '6-10', 150, 75),
        _ex('pg', 2, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 65),
        _ex('pg', 3, 'Leg Press', 'Legs', 'Machine', 3, '10-12', 90, 130),
        _ex('pg', 4, 'Leg Curl', 'Legs', 'Machine', 3, '10-15', 75, 40),
        _ex('pg', 5, 'Calf Raise', 'Legs', 'Machine', 4, '10-15', 60, 45),
      ],
    );

    return Program(
      id: 'classic_ppl',
      name: 'Classic PPL × 2',
      description:
          'Push / Pull / Legs twice a week. High frequency for intermediate lifters.',
      days: [push, pull, legs],
      whyFitsParagraph:
          'Running PPL twice gives each muscle group two weekly hits with clear session themes. Best when you can train most days and recover well.',
      dayAssignments: const {
        'Mon': 'ppl_push',
        'Tue': 'ppl_pull',
        'Wed': 'ppl_legs',
        'Thu': 'ppl_push',
        'Fri': 'ppl_pull',
        'Sat': 'ppl_legs',
      },
    );
  }

  /// 3-day push / pull / legs power.
  static Program pushPullPower() {
    final push = WorkoutDay(
      id: 'pwr_push',
      name: 'Push Power',
      exercises: [
        _ex('pw', 1, 'Bench Press', 'Chest', 'Barbell', 5, '3-5', 180, 75),
        _ex('pw', 2, 'Overhead Press', 'Shoulders', 'Barbell', 4, '4-6', 150, 42),
        _ex('pw', 3, 'Dips', 'Chest', 'Bodyweight', 3, '6-10', 90, 0),
        _ex('pw', 4, 'Triceps Extension', 'Arms', 'Dumbbell', 3, '8-12', 60, 16),
      ],
    );
    final pull = WorkoutDay(
      id: 'pwr_pull',
      name: 'Pull Power',
      exercises: [
        _ex('pr', 1, 'Deadlift', 'Back', 'Barbell', 4, '3-5', 180, 110),
        _ex('pr', 2, 'Weighted Pull-up', 'Back', 'Bodyweight', 4, '4-6', 150, 5),
        _ex('pr', 3, 'Barbell Row', 'Back', 'Barbell', 4, '5-8', 120, 60),
        _ex('pr', 4, 'Hammer Curl', 'Arms', 'Dumbbell', 3, '8-12', 60, 12),
      ],
    );
    final legs = WorkoutDay(
      id: 'pwr_legs',
      name: 'Legs Power',
      exercises: [
        _ex('plg', 1, 'Back Squat', 'Legs', 'Barbell', 5, '3-5', 180, 90),
        _ex('plg', 2, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '5-8', 150, 75),
        _ex('plg', 3, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '6-8', 120, 18),
        _ex('plg', 4, 'Calf Raise', 'Legs', 'Machine', 4, '8-12', 60, 50),
      ],
    );

    return Program(
      id: 'push_pull_power',
      name: 'Push / Pull Power',
      description:
          'Three hard days focused on the big lifts. Strength first, accessories second.',
      days: [push, pull, legs],
      whyFitsParagraph:
          'A classic power template: one push, one pull, one legs day with low-rep compounds. Ideal when your goal is getting stronger without living in the gym.',
      dayAssignments: const {
        'Mon': 'pwr_push',
        'Wed': 'pwr_pull',
        'Fri': 'pwr_legs',
      },
    );
  }

  // ===========================================================================
  // FEMALE TEMPLATES
  // ===========================================================================

  /// 4-day glute-focused.
  static Program gluteFocusFourDay() {
    final lowerA = WorkoutDay(
      id: 'gf_la',
      name: 'Lower A — Glute Strength',
      exercises: [
        _ex('gla', 1, 'Barbell Hip Thrust', 'Legs', 'Barbell', 4, '6-10', 120, 70),
        _ex('gla', 2, 'Back Squat', 'Legs', 'Barbell', 3, '6-10', 150, 50),
        _ex('gla', 3, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 50),
        _ex('gla', 4, 'Cable Kickback', 'Legs', 'Cable', 3, '12-15', 60, 15),
        _ex('gla', 5, 'Seated Abduction', 'Legs', 'Machine', 3, '15-20', 45, 40),
      ],
    );
    final upperA = WorkoutDay(
      id: 'gf_ua',
      name: 'Upper A — Pull & Press',
      exercises: [
        _ex('gua', 1, 'Lat Pulldown', 'Back', 'Cable', 3, '8-12', 90, 35),
        _ex('gua', 2, 'Seated Cable Row', 'Back', 'Cable', 3, '10-12', 90, 35),
        _ex('gua', 3, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-12', 75, 10),
        _ex('gua', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 5),
        _ex('gua', 5, 'Triceps Pushdown', 'Arms', 'Cable', 2, '12-15', 45, 18),
      ],
    );
    final lowerB = WorkoutDay(
      id: 'gf_lb',
      name: 'Lower B — Glute Volume',
      exercises: [
        _ex('glb', 1, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('glb', 2, 'Hip Thrust', 'Legs', 'Barbell', 4, '10-15', 90, 55),
        _ex('glb', 3, 'Walking Lunge', 'Legs', 'Dumbbell', 3, '10-12', 75, 10),
        _ex('glb', 4, 'Cable Pull-Through', 'Legs', 'Cable', 3, '12-15', 60, 25),
        _ex('glb', 5, 'Glute Bridge', 'Legs', 'Bodyweight', 3, '15-20', 45, 0),
      ],
    );
    final upperB = WorkoutDay(
      id: 'gf_ub',
      name: 'Upper B — Shape',
      exercises: [
        _ex('gub', 1, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('gub', 2, 'Single-Arm Dumbbell Row', 'Back', 'Dumbbell', 3, '10-12', 75, 12),
        _ex('gub', 3, 'Face Pull', 'Back', 'Cable', 3, '12-15', 45, 12),
        _ex('gub', 4, 'Cable Lateral Raise', 'Shoulders', 'Cable', 3, '12-15', 45, 5),
        _ex('gub', 5, 'Hammer Curl', 'Arms', 'Dumbbell', 2, '12-15', 45, 8),
      ],
    );

    return Program(
      id: 'glute_focus_4day',
      name: 'Glute Focus 4×',
      description:
          'Two lower days built around hip thrusts and hinges, plus two upper days for balance.',
      days: [lowerA, upperA, lowerB, upperB],
      whyFitsParagraph:
          'Lower body gets priority volume with hip thrusts, RDLs, and split squats — the movements that grow glutes. Upper days keep posture and shoulders strong without stealing recovery.',
      dayAssignments: const {
        'Mon': 'gf_la',
        'Tue': 'gf_ua',
        'Thu': 'gf_lb',
        'Fri': 'gf_ub',
      },
    );
  }

  /// 3-day full body tone.
  static Program fullBodyTone() {
    final a = WorkoutDay(
      id: 'ft_a',
      name: 'Full Body Tone A',
      exercises: [
        _ex('fta', 1, 'Goblet Squat', 'Legs', 'Dumbbell', 3, '10-15', 75, 16),
        _ex('fta', 2, 'Hip Thrust', 'Legs', 'Barbell', 3, '10-15', 75, 40),
        _ex('fta', 3, 'Dumbbell Row', 'Back', 'Dumbbell', 3, '10-15', 75, 10),
        _ex('fta', 4, 'Push-ups', 'Chest', 'Bodyweight', 3, '8-15', 60, 0),
        _ex('fta', 5, 'Dead Bug', 'Core', 'Bodyweight', 3, '10-12', 45, 0),
      ],
    );
    final b = WorkoutDay(
      id: 'ft_b',
      name: 'Full Body Tone B',
      exercises: [
        _ex('ftb', 1, 'Romanian Deadlift', 'Legs', 'Dumbbell', 3, '10-12', 90, 18),
        _ex('ftb', 2, 'Walking Lunge', 'Legs', 'Dumbbell', 3, '10-12', 75, 8),
        _ex('ftb', 3, 'Lat Pulldown', 'Back', 'Cable', 3, '10-15', 75, 30),
        _ex('ftb', 4, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '10-12', 75, 8),
        _ex('ftb', 5, 'Side Plank', 'Core', 'Bodyweight', 3, '20-40s', 45, 0),
      ],
    );
    final c = WorkoutDay(
      id: 'ft_c',
      name: 'Full Body Tone C',
      exercises: [
        _ex('ftc', 1, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '10-12', 90, 10),
        _ex('ftc', 2, 'Glute Bridge', 'Legs', 'Bodyweight', 3, '15-20', 45, 0),
        _ex('ftc', 3, 'Seated Cable Row', 'Back', 'Cable', 3, '12-15', 75, 30),
        _ex('ftc', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 4),
        _ex('ftc', 5, 'Cable Crunch', 'Core', 'Cable', 3, '12-15', 45, 20),
      ],
    );

    return Program(
      id: 'full_body_tone',
      name: 'Full Body Tone',
      description:
          'Three full-body sessions with higher reps and glute emphasis. Sustainable and joint-friendly.',
      days: [a, b, c],
      whyFitsParagraph:
          'Higher-rep full body work builds muscle and work capacity without marathon sessions. Glutes and posterior chain show up every day so progress compounds.',
      dayAssignments: const {
        'Mon': 'ft_a',
        'Wed': 'ft_b',
        'Fri': 'ft_c',
      },
    );
  }

  /// 4-day upper/lower with glute bias.
  static Program upperLowerGluteBias() {
    final lowerA = WorkoutDay(
      id: 'ulg_la',
      name: 'Lower — Strength',
      exercises: [
        _ex('ula', 1, 'Back Squat', 'Legs', 'Barbell', 4, '6-10', 150, 45),
        _ex('ula', 2, 'Hip Thrust', 'Legs', 'Barbell', 4, '8-12', 90, 60),
        _ex('ula', 3, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 45),
        _ex('ula', 4, 'Leg Curl', 'Legs', 'Machine', 3, '10-15', 60, 30),
      ],
    );
    final upperA = WorkoutDay(
      id: 'ulg_ua',
      name: 'Upper — Pull Bias',
      exercises: [
        _ex('uua', 1, 'Lat Pulldown', 'Back', 'Cable', 4, '8-12', 90, 35),
        _ex('uua', 2, 'Seated Cable Row', 'Back', 'Cable', 3, '10-12', 90, 35),
        _ex('uua', 3, 'Dumbbell Bench Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('uua', 4, 'Face Pull', 'Back', 'Cable', 3, '12-15', 45, 12),
      ],
    );
    final lowerB = WorkoutDay(
      id: 'ulg_lb',
      name: 'Lower — Volume',
      exercises: [
        _ex('ulb', 1, 'Hip Thrust', 'Legs', 'Barbell', 4, '10-15', 90, 50),
        _ex('ulb', 2, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 10),
        _ex('ulb', 3, 'Cable Kickback', 'Legs', 'Cable', 3, '12-15', 45, 12),
        _ex('ulb', 4, 'Seated Abduction', 'Legs', 'Machine', 3, '15-20', 45, 35),
      ],
    );
    final upperB = WorkoutDay(
      id: 'ulg_ub',
      name: 'Upper — Press Bias',
      exercises: [
        _ex('uub', 1, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('uub', 2, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-12', 75, 8),
        _ex('uub', 3, 'Single-Arm Row', 'Back', 'Dumbbell', 3, '10-12', 75, 12),
        _ex('uub', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 4),
      ],
    );

    return Program(
      id: 'upper_lower_glute',
      name: 'Upper / Lower Glute Bias',
      description:
          'Four days with extra lower volume and hip-thrust priority.',
      days: [lowerA, upperA, lowerB, upperB],
      whyFitsParagraph:
          'Same reliable Upper/Lower structure, but lower days lead with glute builders and keep quads/hamstrings in support. Upper days stay balanced so your physique stays proportional.',
      dayAssignments: const {
        'Mon': 'ulg_la',
        'Tue': 'ulg_ua',
        'Thu': 'ulg_lb',
        'Fri': 'ulg_ub',
      },
    );
  }

  /// 5-day PPL with glute emphasis on leg day + extra lower accessory day.
  static Program pplGluteEmphasis() {
    final push = WorkoutDay(
      id: 'pplg_push',
      name: 'Push',
      exercises: [
        _ex('pgp', 1, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('pgp', 2, 'Machine Chest Press', 'Chest', 'Machine', 3, '10-12', 75, 25),
        _ex('pgp', 3, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-12', 75, 8),
        _ex('pgp', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 4),
        _ex('pgp', 5, 'Triceps Pushdown', 'Arms', 'Cable', 2, '12-15', 45, 18),
      ],
    );
    final pull = WorkoutDay(
      id: 'pplg_pull',
      name: 'Pull',
      exercises: [
        _ex('pgl', 1, 'Lat Pulldown', 'Back', 'Cable', 4, '8-12', 90, 35),
        _ex('pgl', 2, 'Seated Cable Row', 'Back', 'Cable', 3, '10-12', 90, 35),
        _ex('pgl', 3, 'Single-Arm Dumbbell Row', 'Back', 'Dumbbell', 3, '10-12', 75, 12),
        _ex('pgl', 4, 'Face Pull', 'Back', 'Cable', 3, '12-15', 45, 12),
        _ex('pgl', 5, 'Hammer Curl', 'Arms', 'Dumbbell', 2, '12-15', 45, 8),
      ],
    );
    final legs = WorkoutDay(
      id: 'pplg_legs',
      name: 'Legs — Glute Priority',
      exercises: [
        _ex('pgg', 1, 'Hip Thrust', 'Legs', 'Barbell', 4, '8-12', 120, 60),
        _ex('pgg', 2, 'Back Squat', 'Legs', 'Barbell', 3, '6-10', 150, 45),
        _ex('pgg', 3, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 45),
        _ex('pgg', 4, 'Walking Lunge', 'Legs', 'Dumbbell', 3, '10-12', 75, 8),
        _ex('pgg', 5, 'Seated Abduction', 'Legs', 'Machine', 3, '15-20', 45, 40),
      ],
    );
    final glute = WorkoutDay(
      id: 'pplg_glute',
      name: 'Glute Accessory',
      exercises: [
        _ex('pga', 1, 'Hip Thrust', 'Legs', 'Barbell', 4, '10-15', 90, 50),
        _ex('pga', 2, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 10),
        _ex('pga', 3, 'Cable Kickback', 'Legs', 'Cable', 3, '12-15', 45, 12),
        _ex('pga', 4, 'Cable Pull-Through', 'Legs', 'Cable', 3, '12-15', 60, 25),
        _ex('pga', 5, 'Glute Bridge', 'Legs', 'Bodyweight', 2, '15-20', 45, 0),
      ],
    );
    final upper = WorkoutDay(
      id: 'pplg_upper',
      name: 'Upper Pump',
      exercises: [
        _ex('pgu', 1, 'Machine Chest Press', 'Chest', 'Machine', 3, '10-15', 75, 25),
        _ex('pgu', 2, 'Lat Pulldown', 'Back', 'Cable', 3, '10-15', 75, 30),
        _ex('pgu', 3, 'Cable Lateral Raise', 'Shoulders', 'Cable', 3, '12-15', 45, 5),
        _ex('pgu', 4, 'Triceps Pushdown', 'Arms', 'Cable', 2, '12-15', 45, 18),
        _ex('pgu', 5, 'Cable Curl', 'Arms', 'Cable', 2, '12-15', 45, 15),
      ],
    );

    return Program(
      id: 'ppl_glute_emphasis',
      name: 'PPL + Glute Day',
      description:
          'Five days: classic Push/Pull/Legs plus a dedicated glute session and an upper pump day.',
      days: [push, pull, legs, glute, upper],
      whyFitsParagraph:
          'You still get a full PPL backbone for balanced strength, then a fourth day that only loads the glutes and a lighter upper day so recovery stays realistic.',
      dayAssignments: const {
        'Mon': 'pplg_push',
        'Tue': 'pplg_pull',
        'Wed': 'pplg_legs',
        'Thu': 'pplg_glute',
        'Fri': 'pplg_upper',
      },
    );
  }

  /// 3-day home / dumbbell sculpt.
  static Program homeDumbbellSculpt() {
    final a = WorkoutDay(
      id: 'hd_a',
      name: 'Home Full Body A',
      exercises: [
        _ex('hda', 1, 'Goblet Squat', 'Legs', 'Dumbbell', 3, '10-15', 75, 14),
        _ex('hda', 2, 'Glute Bridge', 'Legs', 'Bodyweight', 3, '15-20', 45, 0),
        _ex('hda', 3, 'Dumbbell Row', 'Back', 'Dumbbell', 3, '10-15', 75, 10),
        _ex('hda', 4, 'Push-ups', 'Chest', 'Bodyweight', 3, '8-15', 60, 0),
        _ex('hda', 5, 'Plank Hold', 'Core', 'Bodyweight', 3, '30-45s', 45, 0),
      ],
    );
    final b = WorkoutDay(
      id: 'hd_b',
      name: 'Home Full Body B',
      exercises: [
        _ex('hdb', 1, 'Romanian Deadlift', 'Legs', 'Dumbbell', 3, '10-12', 90, 16),
        _ex('hdb', 2, 'Reverse Lunge', 'Legs', 'Dumbbell', 3, '10-12', 75, 8),
        _ex('hdb', 3, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '10-12', 75, 8),
        _ex('hdb', 4, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 4),
        _ex('hdb', 5, 'Dead Bug', 'Core', 'Bodyweight', 3, '10-12', 45, 0),
      ],
    );
    final c = WorkoutDay(
      id: 'hd_c',
      name: 'Home Full Body C',
      exercises: [
        _ex('hdc', 1, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 8),
        _ex('hdc', 2, 'Single-Leg Glute Bridge', 'Legs', 'Bodyweight', 3, '10-15', 45, 0),
        _ex('hdc', 3, 'Renegade Row', 'Back', 'Dumbbell', 3, '8-10', 75, 8),
        _ex('hdc', 4, 'Floor Press', 'Chest', 'Dumbbell', 3, '10-12', 75, 12),
        _ex('hdc', 5, 'Side Plank', 'Core', 'Bodyweight', 3, '20-40s', 45, 0),
      ],
    );

    return Program(
      id: 'home_dumbbell_sculpt',
      name: 'Home Dumbbell Sculpt',
      description:
          'Three full-body days you can do with dumbbells and bodyweight — no gym required.',
      days: [a, b, c],
      whyFitsParagraph:
          'Built for minimal equipment without dropping progressive overload. Every session hits legs, push, pull, and core so you keep progressing at home.',
      dayAssignments: const {
        'Mon': 'hd_a',
        'Wed': 'hd_b',
        'Fri': 'hd_c',
      },
    );
  }

  // ===========================================================================
  // COVERAGE TEMPLATES
  // ---------------------------------------------------------------------------
  // These fill gaps the curated plans above left open: nothing served someone
  // who could train twice a week, and home training stopped at three days.
  // ===========================================================================

  /// 2-day full body. For people whose real constraint is time, not ambition:
  /// two hard sessions a week still drives progress if both are full-body and
  /// compound-led.
  static Program twoDayFullBody() {
    final a = WorkoutDay(
      id: 'td_a',
      name: 'Full Body A — Squat Focus',
      exercises: [
        _ex('tda', 1, 'Back Squat', 'Legs', 'Barbell', 4, '5-8', 150, 50),
        _ex('tda', 2, 'Bench Press', 'Chest', 'Barbell', 4, '5-8', 150, 40),
        _ex('tda', 3, 'Barbell Row', 'Back', 'Barbell', 3, '8-10', 120, 40),
        _ex('tda', 4, 'Romanian Deadlift', 'Legs', 'Barbell', 3, '8-10', 120, 50),
        _ex('tda', 5, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 3, '8-12', 90, 14),
        _ex('tda', 6, 'Plank Hold', 'Core', 'Bodyweight', 3, '30-60s', 45, 0),
      ],
    );
    final b = WorkoutDay(
      id: 'td_b',
      name: 'Full Body B — Hinge Focus',
      exercises: [
        _ex('tdb', 1, 'Deadlift', 'Legs', 'Barbell', 4, '4-6', 180, 70),
        _ex('tdb', 2, 'Overhead Press', 'Shoulders', 'Barbell', 4, '5-8', 150, 30),
        _ex('tdb', 3, 'Pull-ups', 'Back', 'Bodyweight', 3, '6-10', 120, 0),
        _ex('tdb', 4, 'Leg Press', 'Legs', 'Machine', 3, '10-12', 120, 80),
        _ex('tdb', 5, 'Incline Dumbbell Press', 'Chest', 'Dumbbell', 3, '8-12', 90, 18),
        _ex('tdb', 6, 'Hanging Knee Raise', 'Core', 'Bodyweight', 3, '10-15', 45, 0),
      ],
    );

    return Program(
      id: 'two_day_full_body',
      name: 'Two-Day Full Body',
      description:
          'Two hard full-body sessions a week — the most training you can get from the least time.',
      days: [a, b],
      whyFitsParagraph:
          'You told us you can train twice a week, so every session has to earn its place. Both days are full-body and compound-led, spaced apart so each muscle gets hit twice weekly with real recovery in between. This is the layout the research keeps landing on for limited training days.',
      dayAssignments: const {'Mon': 'td_a', 'Thu': 'td_b'},
    );
  }

  /// 4-day upper/lower using only dumbbells and bodyweight. The home catalog
  /// previously stopped at three days, so anyone training at home four or more
  /// times a week was pushed onto a gym plan they couldn't perform.
  static Program homeUpperLowerFourDay() {
    final upperA = WorkoutDay(
      id: 'hul_ua',
      name: 'Upper A — Press Focus',
      exercises: [
        _ex('hua', 1, 'Floor Press', 'Chest', 'Dumbbell', 4, '8-12', 90, 18),
        _ex('hua', 2, 'Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 4, '8-12', 90, 14),
        _ex('hua', 3, 'Dumbbell Row', 'Back', 'Dumbbell', 4, '8-12', 90, 20),
        _ex('hua', 4, 'Push-ups', 'Chest', 'Bodyweight', 3, '10-20', 60, 0),
        _ex('hua', 5, 'Lateral Raise', 'Shoulders', 'Dumbbell', 3, '12-15', 45, 6),
        _ex('hua', 6, 'Overhead Triceps Extension', 'Arms', 'Dumbbell', 3, '10-15', 45, 10),
      ],
    );
    final lowerA = WorkoutDay(
      id: 'hul_la',
      name: 'Lower A — Squat Focus',
      exercises: [
        _ex('hla', 1, 'Goblet Squat', 'Legs', 'Dumbbell', 4, '10-15', 90, 20),
        _ex('hla', 2, 'Bulgarian Split Squat', 'Legs', 'Dumbbell', 3, '8-12', 90, 12),
        _ex('hla', 3, 'Romanian Deadlift', 'Legs', 'Dumbbell', 4, '10-12', 90, 22),
        _ex('hla', 4, 'Glute Bridge', 'Legs', 'Bodyweight', 3, '15-20', 45, 0),
        _ex('hla', 5, 'Calf Raise', 'Legs', 'Bodyweight', 4, '15-20', 45, 0),
        _ex('hla', 6, 'Dead Bug', 'Core', 'Bodyweight', 3, '10-12', 45, 0),
      ],
    );
    final upperB = WorkoutDay(
      id: 'hul_ub',
      name: 'Upper B — Pull Focus',
      exercises: [
        _ex('hub', 1, 'Renegade Row', 'Back', 'Dumbbell', 4, '8-10', 90, 12),
        _ex('hub', 2, 'Incline Push-ups', 'Chest', 'Bodyweight', 4, '10-20', 60, 0),
        _ex('hub', 3, 'Reverse Fly', 'Shoulders', 'Dumbbell', 3, '12-15', 60, 8),
        _ex('hub', 4, 'Dumbbell Pullover', 'Back', 'Dumbbell', 3, '10-12', 75, 16),
        _ex('hub', 5, 'Hammer Curl', 'Arms', 'Dumbbell', 3, '10-15', 45, 10),
        _ex('hub', 6, 'Pike Push-ups', 'Shoulders', 'Bodyweight', 3, '8-12', 60, 0),
      ],
    );
    final lowerB = WorkoutDay(
      id: 'hul_lb',
      name: 'Lower B — Hinge Focus',
      exercises: [
        _ex('hlb', 1, 'Single-Leg Romanian Deadlift', 'Legs', 'Dumbbell', 4, '8-12', 90, 14),
        _ex('hlb', 2, 'Reverse Lunge', 'Legs', 'Dumbbell', 4, '10-12', 90, 14),
        _ex('hlb', 3, 'Single-Leg Glute Bridge', 'Legs', 'Bodyweight', 3, '10-15', 60, 0),
        _ex('hlb', 4, 'Step-up', 'Legs', 'Dumbbell', 3, '10-12', 75, 12),
        _ex('hlb', 5, 'Seated Calf Raise', 'Legs', 'Dumbbell', 4, '15-20', 45, 16),
        _ex('hlb', 6, 'Side Plank', 'Core', 'Bodyweight', 3, '20-40s', 45, 0),
      ],
    );

    return Program(
      id: 'home_upper_lower_4',
      name: 'Home Upper / Lower',
      description:
          'Four dumbbell-and-bodyweight days, split upper and lower. No barbell, no machines.',
      days: [upperA, lowerA, upperB, lowerB],
      whyFitsParagraph:
          'Training at home four days a week gives you enough sessions to split upper and lower properly, which beats four repeated full-body days. Every movement here works with dumbbells or your own bodyweight, and each muscle gets trained twice a week. Add weight or reps each session — that is what drives progress, not the equipment.',
      dayAssignments: const {
        'Mon': 'hul_ua',
        'Tue': 'hul_la',
        'Thu': 'hul_ub',
        'Fri': 'hul_lb',
      },
    );
  }
}
