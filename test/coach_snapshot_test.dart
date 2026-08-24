import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/data/coach/coach_snapshot.dart';
import 'package:crux/core/models/models.dart';

/// The snapshot is the only way the cloud coach can see a program or a logged
/// workout — none of it is synced. If a field goes missing here, Coach starts
/// answering from a profile row and generalities, which is the failure this
/// whole thing exists to prevent.
void main() {
  final now = DateTime(2026, 8, 22, 14, 0); // a Saturday

  Exercise ex(String name, String muscle, int sets) => Exercise(
        id: name.toLowerCase(),
        name: name,
        muscleGroup: muscle,
        equipment: 'Barbell',
        targetSets: sets,
        targetReps: '8-12',
        restTimeSeconds: 90,
        suggestedWeight: 60,
      );

  final program = Program(
    id: 'p',
    name: 'Full Body Beginner',
    description: '',
    whyFitsParagraph: '',
    days: [
      WorkoutDay(id: 'a', name: 'Full Body A', exercises: [
        ex('Goblet Squat', 'Legs', 3),
        ex('Bench Press', 'Chest', 3),
      ]),
      WorkoutDay(id: 'b', name: 'Full Body B', exercises: [
        ex('Romanian Deadlift', 'Legs', 3),
      ]),
    ],
    dayAssignments: const {'Mon': 'a', 'Wed': 'b'},
  );

  final profile = UserProfile(
    name: 'Test',
    sex: 'Male',
    age: 30,
    height: 180,
    weight: 72,
    goal: 'Build Muscle',
    experience: '1-2 years',
    daysPerWeek: const ['Mon', 'Wed'],
    equipment: 'Full gym',
    injuries: const ['Shoulder'],
    notificationPermission: false,
    avatar: 'default',
  );

  final session = WorkoutSession(
    id: 's1',
    programId: 'p',
    workoutDayName: 'Full Body A',
    date: DateTime(2026, 8, 19),
    durationSeconds: 3600,
    completed: true,
    totalVolume: 4200,
    xpEarned: 50,
    prsHit: const ['Bench Press'],
    overloadSuggestions: const {},
    exercises: [
      ExerciseLog(
        exerciseId: 'bench press',
        exerciseName: 'Bench Press',
        muscleGroup: 'Chest',
        targetReps: '8-12',
        sets: const [
          SetLog(id: '1', weight: 40, reps: 10, completed: true, isWarmup: true),
          SetLog(id: '2', weight: 60, reps: 8, completed: true),
          SetLog(
              id: '3',
              weight: 62.5,
              reps: 6,
              completed: true,
              note: 'left shoulder tweak'),
        ],
      ),
    ],
  );

  test('carries the week as scheduled, weekday by weekday', () {
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: [session],
      weighIns: const [],
      now: now,
    );
    final prog = snap['program'] as Map<String, dynamic>;
    final week = prog['week'] as Map<String, dynamic>;

    expect(prog['trainingDaysPerWeek'], 2);
    expect((week['Mon'] as Map)['session'], 'Full Body A');
    expect(week['Tue'], 'rest');
    expect((week['Wed'] as Map)['session'], 'Full Body B');
    expect(prog['weeklySetsPerMuscle'], {'Legs': 6, 'Chest': 3});
  });

  test('carries the top working set and the note, not warm-ups', () {
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: [session],
      weighIns: const [],
      now: now,
    );
    final sessions = snap['recentSessions'] as List;
    expect(sessions, hasLength(1));
    final logged = (sessions.first as Map)['exercises'] as List;
    final bench = logged.first as Map;
    expect(bench['topSet'], '62.5kg x 6');
    expect(bench['notes'], ['left shoulder tweak']);
    expect((sessions.first as Map)['prs'], ['Bench Press']);
  });

  test('reports adherence — planned versus actually trained', () {
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: [session],
      weighIns: const [],
      now: now,
    );
    final adherence = snap['adherence'] as Map<String, dynamic>;
    expect(adherence['plannedDaysPerWeek'], 2);
    expect(adherence['sessionsLast7Days'], 1);
    expect(adherence['totalLoggedSessions'], 1);
  });

  test('bodyweight uses the 7-day average and the 30-day change', () {
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: const [],
      weighIns: [
        WeighIn(date: DateTime(2026, 8, 1), weight: 70),
        WeighIn(date: DateTime(2026, 8, 21), weight: 72),
      ],
      now: now,
    );
    final bw = snap['bodyweight'] as Map<String, dynamic>;
    expect(bw['latestKg'], 72);
    expect(bw['avg7DayKg'], 71);
    expect(bw['change30DayKg'], 2);
  });

  test('today knows it is a rest day', () {
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: const [],
      weighIns: const [],
      now: now,
    );
    final today = snap['today'] as Map<String, dynamic>;
    expect(today['weekday'], 'Sat');
    expect(today['isRestDay'], isTrue);
    expect(today['scheduledToday'], isNull);
    expect(today['date'], '2026-08-22');
  });

  test('drops sessions older than the window', () {
    final old = WorkoutSession(
      id: 'old',
      programId: 'p',
      workoutDayName: 'Ancient',
      date: DateTime(2026, 1, 1),
      durationSeconds: 100,
      completed: true,
      totalVolume: 100,
      xpEarned: 0,
      prsHit: const [],
      overloadSuggestions: const {},
      exercises: const [],
    );
    final snap = buildCoachSnapshot(
      profile: profile,
      program: program,
      history: [session, old],
      weighIns: const [],
      now: now,
    );
    expect(snap['recentSessions'], hasLength(1));
  });
}
