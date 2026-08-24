import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/core/providers/providers.dart';

/// Regression cover for the "5 workouts across 1 training day" corruption.
///
/// The app derives the user's training days from the program's dayAssignments,
/// so a program that only schedules some of its sessions rewrites the profile
/// to match — and every template loaded afterwards inherits the shrunken week.
void main() {
  UserProfile profileWith(List<String> days) => UserProfile(
        name: 'Tester',
        sex: 'Male',
        age: 28,
        height: 175,
        weight: 75,
        goal: 'Build Muscle',
        experience: '6–24 months',
        daysPerWeek: days,
        equipment: 'Full gym',
        injuries: const [],
        notificationPermission: false,
        avatar: '',
      );

  WorkoutDay day(String id) => WorkoutDay(
        id: id,
        name: id.toUpperCase(),
        exercises: [
          Exercise(
            id: '$id-e1',
            name: 'Bench Press',
            muscleGroup: 'Chest',
            equipment: 'Barbell',
            targetSets: 3,
            targetReps: '8-12',
            restTimeSeconds: 90,
            suggestedWeight: 40,
          ),
        ],
      );

  Program programWith({
    required List<String> dayIds,
    required Map<String, String> assignments,
  }) =>
      Program(
        id: 'p1',
        name: 'Test plan',
        description: 'x',
        whyFitsParagraph: 'y',
        days: dayIds.map(day).toList(),
        dayAssignments: assignments,
      );

  test('a program that schedules every session is left alone', () {
    final p = programWith(
      dayIds: ['a', 'b', 'c'],
      assignments: {'Mon': 'a', 'Wed': 'b', 'Fri': 'c'},
    );
    final repaired =
        ProgramNotifier.repairAssignments(p, profileWith(['Mon', 'Wed', 'Fri']));
    expect(identical(repaired, p), isTrue,
        reason: 'a healthy program must not be rewritten');
  });

  test('the reported bug: 5 sessions, 1 scheduled day, gets rebuilt', () {
    final p = programWith(
      dayIds: ['a', 'b', 'c', 'd', 'e'],
      assignments: {'Wed': 'c'},
    );
    final repaired =
        ProgramNotifier.repairAssignments(p, profileWith(['Wed']));

    expect(repaired.dayAssignments.length, 5,
        reason: 'every session needs a weekday');
    expect(
      repaired.dayAssignments.values.toSet(),
      {'a', 'b', 'c', 'd', 'e'},
      reason: 'no session may be left unscheduled',
    );
  });

  test('an empty layout is rebuilt too', () {
    final p = programWith(dayIds: ['a', 'b'], assignments: const {});
    final repaired =
        ProgramNotifier.repairAssignments(p, profileWith(['Mon', 'Thu']));
    expect(repaired.dayAssignments.length, 2);
  });

  test("the user's own training days are used when they fit", () {
    final p = programWith(
      dayIds: ['a', 'b', 'c'],
      assignments: {'Mon': 'a'},
    );
    final repaired = ProgramNotifier.repairAssignments(
      p,
      profileWith(['Tue', 'Thu', 'Sat']),
    );
    expect(repaired.dayAssignments.keys.toSet(), {'Tue', 'Thu', 'Sat'});
  });

  test('a corrupted profile does not constrain the rebuild', () {
    // Profile already shrunk to one day by an earlier bad reply.
    final p = programWith(
      dayIds: ['a', 'b', 'c', 'd'],
      assignments: {'Fri': 'a'},
    );
    final repaired = ProgramNotifier.repairAssignments(p, profileWith(['Fri']));
    expect(repaired.dayAssignments.length, 4,
        reason: 'one stale training day must not cap a four-session program');
  });

  test('a program reusing sessions across more weekdays is preserved', () {
    // PPL x2: three sessions, six weekdays. Assignments legitimately
    // outnumber days and every session appears.
    final p = programWith(
      dayIds: ['push', 'pull', 'legs'],
      assignments: {
        'Mon': 'push',
        'Tue': 'pull',
        'Wed': 'legs',
        'Thu': 'push',
        'Fri': 'pull',
        'Sat': 'legs',
      },
    );
    final repaired = ProgramNotifier.repairAssignments(
      p,
      profileWith(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
    );
    expect(identical(repaired, p), isTrue);
    expect(repaired.dayAssignments.length, 6);
  });
}
