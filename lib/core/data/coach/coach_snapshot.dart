import '../../domain/gamification.dart';
import '../../domain/nutrition.dart';
import '../../models/models.dart';

/// Everything Coach needs to know about this user, assembled on the device.
///
/// The server has a `coach_context()` RPC, but it can only see what has been
/// synced — and workouts, programs and schedules never leave the device (sync
/// covers profile + body logs only). So the cloud coach was answering from a
/// profile row and nothing else: no program, no sessions, no weights. That is
/// how "add a second leg day" gets a reply that ignores the user's actual week.
///
/// This is the fix: the client sends what it holds, the server merges it into
/// the grounding context, and the model answers from real training data.
///
/// Kept compact on purpose — every field costs tokens on every message, so it
/// carries what changes an answer (the week, recent top sets, bodyweight trend,
/// adherence) and nothing decorative (XP, quest progress, avatars).
Map<String, dynamic> buildCoachSnapshot({
  required UserProfile profile,
  required Program? program,
  required List<WorkoutSession> history,
  required List<WeighIn> weighIns,
  required DateTime now,
  int recentSessionLimit = 8,
  int historyWindowDays = 42,
}) {
  return {
    'profile': _profile(profile),
    'today': todaySnapshot(profile: profile, program: program, history: history, now: now),
    if (program != null) 'program': _program(program),
    'recentSessions': _sessions(history, now, recentSessionLimit, historyWindowDays),
    'adherence': _adherence(profile, history, now),
    'bodyweight': _bodyweight(profile, weighIns, now),
    'nutritionTargets': _nutrition(profile),
  };
}

/// The user's local "today" — the current date, what their plan schedules on
/// it, and whether they have already trained. Separated out because it is also
/// what the offline coach reads.
Map<String, dynamic> todaySnapshot({
  required UserProfile profile,
  required Program? program,
  required List<WorkoutSession> history,
  required DateTime now,
}) {
  final weekday = kWeekdayNames[now.weekday - 1];
  final day = program?.dayForWeekday(weekday, fallbackDays: profile.daysPerWeek);
  final trainedToday = history.any((s) => s.completed && _sameDay(s.date, now));
  return {
    'date': _date(now),
    'weekday': weekday,
    'localTime':
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    'scheduledToday': day?.name,
    'isRestDay': day == null,
    'exercisesToday':
        day?.exercises.map((e) => e.name).toList() ?? const <String>[],
    'alreadyTrainedToday': trainedToday,
    'trainingDays': profile.daysPerWeek,
  };
}

Map<String, dynamic> _profile(UserProfile p) => {
      'sex': p.sex,
      'age': p.age,
      'heightCm': p.height,
      'weightKg': p.weight,
      'goal': p.goal,
      'experience': p.experience,
      'trainingDays': p.daysPerWeek,
      'equipment': p.equipment,
      'injuries': p.injuries,
      'units': p.units,
    };

/// The week as it actually stands: which session runs on which weekday, what's
/// in each one, and the weekly set count per muscle — the number every
/// "should I add more X?" question turns on.
Map<String, dynamic> _program(Program program) {
  final week = <String, dynamic>{};
  final setsByMuscle = <String, int>{};

  for (final weekday in Program.weekdays) {
    final dayId = program.dayAssignments[weekday];
    if (dayId == null) {
      week[weekday] = 'rest';
      continue;
    }
    WorkoutDay? day;
    for (final d in program.days) {
      if (d.id == dayId) day = d;
    }
    if (day == null) {
      week[weekday] = 'rest';
      continue;
    }
    week[weekday] = {
      'session': day.name,
      'exercises': [
        for (final e in day.exercises)
          {
            'name': e.name,
            'muscle': e.muscleGroup,
            'sets': e.targetSets,
            'reps': e.targetReps,
          },
      ],
    };
    for (final e in day.exercises) {
      setsByMuscle[e.muscleGroup] =
          (setsByMuscle[e.muscleGroup] ?? 0) + e.targetSets;
    }
  }

  return {
    'name': program.name,
    'trainingDaysPerWeek': program.dayAssignments.length,
    'week': week,
    'weeklySetsPerMuscle': setsByMuscle,
  };
}

/// Recent sessions, one top set per exercise. The top set (heaviest working
/// set) plus any note the user left is what a coach reads to judge progress —
/// the full set-by-set log would be mostly noise at ten times the size.
List<Map<String, dynamic>> _sessions(
  List<WorkoutSession> history,
  DateTime now,
  int limit,
  int windowDays,
) {
  final cutoff = now.subtract(Duration(days: windowDays));
  final recent = history
      .where((s) => s.completed && s.date.isAfter(cutoff))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  return [
    for (final s in recent.take(limit))
      {
        'date': _date(s.date),
        'weekday': kWeekdayNames[s.date.weekday - 1],
        'session': s.workoutDayName,
        'durationMin': (s.durationSeconds / 60).round(),
        'totalVolumeKg': s.totalVolume.round(),
        if (s.prsHit.isNotEmpty) 'prs': s.prsHit,
        'exercises': [
          for (final e in s.exercises)
            if (_topSet(e) != null)
              {
                'name': e.exerciseName,
                'topSet': _topSet(e),
                if (e.targetReps.isNotEmpty) 'targetReps': e.targetReps,
                if (_notes(e).isNotEmpty) 'notes': _notes(e),
              },
        ],
      },
  ];
}

String? _topSet(ExerciseLog log) {
  SetLog? best;
  for (final s in log.sets) {
    if (!s.completed || s.isWarmup) continue;
    if (best == null ||
        s.weight > best.weight ||
        (s.weight == best.weight && s.reps > best.reps)) {
      best = s;
    }
  }
  if (best == null) return null;
  return '${_num(best.weight)}kg x ${best.reps}';
}

List<String> _notes(ExerciseLog log) => [
      for (final s in log.sets)
        if (s.note != null && s.note!.trim().isNotEmpty) s.note!.trim(),
    ];

/// How much of the plan is actually being done. Advice that ignores this ("add
/// a fourth day") is advice for someone else.
Map<String, dynamic> _adherence(
  UserProfile profile,
  List<WorkoutSession> history,
  DateTime now,
) {
  int since(int days) {
    final cutoff = now.subtract(Duration(days: days));
    return history
        .where((s) => s.completed && s.date.isAfter(cutoff))
        .map((s) => _date(s.date))
        .toSet()
        .length;
  }

  final monday = mondayOfWeek(now);
  final thisWeek = history
      .where((s) =>
          s.completed &&
          !s.date.isBefore(monday) &&
          s.date.difference(monday).inDays < 7)
      .map((s) => kWeekdayNames[s.date.weekday - 1])
      .toSet();

  return {
    'plannedDaysPerWeek': profile.daysPerWeek.length,
    'sessionsLast7Days': since(7),
    'sessionsLast28Days': since(28),
    'trainedThisWeek': thisWeek.toList(),
    'totalLoggedSessions': history.where((s) => s.completed).length,
  };
}

Map<String, dynamic> _bodyweight(
  UserProfile profile,
  List<WeighIn> weighIns,
  DateTime now,
) {
  if (weighIns.isEmpty) {
    return {
      'latestKg': profile.weight,
      'source': 'onboarding (no weigh-ins logged yet)',
    };
  }
  final sorted = [...weighIns]..sort((a, b) => a.date.compareTo(b.date));
  final latest = sorted.last;
  final last7 = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
  final avg7 =
      last7.map((w) => w.weight).reduce((a, b) => a + b) / last7.length;

  final monthAgo = now.subtract(const Duration(days: 30));
  WeighIn? oldest;
  for (final w in sorted) {
    if (w.date.isAfter(monthAgo)) {
      oldest = w;
      break;
    }
  }

  return {
    'latestKg': latest.weight,
    'latestDate': _date(latest.date),
    'avg7DayKg': double.parse(avg7.toStringAsFixed(1)),
    if (oldest != null && oldest.date != latest.date)
      'change30DayKg':
          double.parse((latest.weight - oldest.weight).toStringAsFixed(1)),
    'entries': sorted.length,
  };
}

Map<String, dynamic> _nutrition(UserProfile p) {
  final t = nutritionTargets(
    weightKg: p.weight,
    heightCm: p.height,
    age: p.age,
    sex: p.sex,
    goal: p.goal,
  );
  return {
    'caloriesLow': t.caloriesLow,
    'caloriesHigh': t.caloriesHigh,
    'proteinG': t.proteinG,
    'note': 'computed by the app from the profile above — use these numbers',
  };
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _num(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
