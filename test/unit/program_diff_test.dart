import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/features/schedule/domain/program_diff.dart';

/// The preview sheet's whole value is that it reports what *actually* changed
/// rather than what the model claimed it changed, so the diff has to be right.
void main() {
  Exercise ex(String name, {int sets = 3}) => Exercise(
        id: name.toLowerCase().replaceAll(' ', '-'),
        name: name,
        muscleGroup: 'Back',
        equipment: 'Barbell',
        targetSets: sets,
        targetReps: '8-12',
        restTimeSeconds: 90,
        suggestedWeight: 40,
      );

  Program prog(
    Map<String, List<Exercise>> days, {
    Map<String, String>? assignments,
  }) =>
      Program(
        id: 'p',
        name: 'Plan',
        description: 'd',
        whyFitsParagraph: 'w',
        days: days.entries
            .map((e) => WorkoutDay(
                  id: e.key.toLowerCase(),
                  name: e.key,
                  exercises: e.value,
                ))
            .toList(),
        dayAssignments: assignments ??
            {
              for (var i = 0; i < days.length; i++)
                Program.weekdays[i]: days.keys.elementAt(i).toLowerCase()
            },
      );

  test('an identical program reports nothing', () {
    final a = prog({
      'Pull A': [ex('Barbell Row')]
    });
    final b = prog({
      'Pull A': [ex('Barbell Row')]
    });
    expect(ProgramDiff.between(a, b).isEmpty, isTrue);
  });

  test('an added exercise is reported with its session', () {
    final a = prog({
      'Pull A': [ex('Barbell Row')]
    });
    final b = prog({
      'Pull A': [ex('Barbell Row'), ex('Hammer Curl')]
    });
    final d = ProgramDiff.between(a, b);
    expect(d.changes.map((c) => c.text).join(),
        contains('Pull A: added Hammer Curl'));
  });

  test('a removed exercise is reported', () {
    final a = prog({
      'Pull A': [ex('Barbell Row'), ex('Hammer Curl')]
    });
    final b = prog({
      'Pull A': [ex('Barbell Row')]
    });
    expect(ProgramDiff.between(a, b).changes.map((c) => c.text).join(),
        contains('removed Hammer Curl'));
  });

  test('a set change is reported as a volume change', () {
    final a = prog({
      'Pull A': [ex('Barbell Row', sets: 3)]
    });
    final b = prog({
      'Pull A': [ex('Barbell Row', sets: 5)]
    });
    final d = ProgramDiff.between(a, b);
    expect(d.changes.single.kind, ChangeKind.volume);
    expect(d.changes.single.text, contains('3 → 5 sets'));
  });

  test('a change in training days is reported first and plainly', () {
    final a = prog({
      'A': [ex('Row')],
      'B': [ex('Bench')],
      'C': [ex('Squat')],
    });
    final b = prog(
      {
        'A': [ex('Row')],
        'B': [ex('Bench')],
        'C': [ex('Squat')],
      },
      assignments: {'Mon': 'a', 'Thu': 'b'},
    );
    final d = ProgramDiff.between(a, b);
    expect(d.changes.first.kind, ChangeKind.schedule);
    expect(d.changes.first.text, contains('3 → 2'));
  });

  test('a new session is called out', () {
    final a = prog({
      'Pull A': [ex('Row')]
    });
    final b = prog({
      'Pull A': [ex('Row')],
      'Legs': [ex('Squat')],
    });
    expect(ProgramDiff.between(a, b).changes.map((c) => c.text).join(),
        contains('New session: Legs'));
  });

  test('the three-biceps scenario from the bug report reads clearly', () {
    final a = prog({
      'Pull A': [ex('Barbell Row'), ex('EZ-Bar Curl')]
    });
    final b = prog({
      'Pull A': [
        ex('Barbell Row'),
        ex('EZ-Bar Curl', sets: 4),
        ex('Hammer Curl'),
        ex('Concentration Curl'),
      ]
    });
    final d = ProgramDiff.between(a, b);
    final text = d.changes.map((c) => c.text).join(' | ');
    expect(text, contains('Hammer Curl'));
    expect(text, contains('Concentration Curl'));
    expect(text, contains('3 → 4 sets'));
  });
}
