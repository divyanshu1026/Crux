import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/domain/progression.dart';
import 'package:crux/core/models/models.dart';

void main() {
  group('RepRange.parse', () {
    test('parses a range', () {
      final r = RepRange.parse('8-12');
      expect(r.low, 8);
      expect(r.high, 12);
      expect(r.isSingle, false);
    });

    test('parses a single number / time cue', () {
      expect(RepRange.parse('60s').low, 60);
      expect(RepRange.parse('60s').isSingle, true);
    });
  });

  const bench = Exercise(
    id: 'x',
    name: 'Bench Press',
    muscleGroup: 'Chest',
    equipment: 'Barbell',
    targetSets: 3,
    targetReps: '8-12',
    suggestedWeight: 60,
  );
  const squat = Exercise(
    id: 'y',
    name: 'Back Squat',
    muscleGroup: 'Legs',
    equipment: 'Barbell',
    targetSets: 3,
    targetReps: '6-8',
    suggestedWeight: 80,
  );

  SetLog set(double w, int reps) =>
      SetLog(id: 's', weight: w, reps: reps, completed: true);

  group('ProgressionEngine.suggest', () {
    test('no history → start at suggested weight and bottom of range', () {
      final s = ProgressionEngine.suggest(exercise: bench, lastWorkingSets: []);
      expect(s.weight, 60);
      expect(s.reps, 8);
    });

    test('all sets at top of range → +2.5kg upper and reset to bottom', () {
      final s = ProgressionEngine.suggest(
        exercise: bench,
        lastWorkingSets: [set(60, 12), set(60, 12), set(60, 12)],
      );
      expect(s.weight, 62.5);
      expect(s.reps, 8);
    });

    test('lower-body compound graduates by +5kg', () {
      final s = ProgressionEngine.suggest(
        exercise: squat,
        lastWorkingSets: [set(80, 8), set(80, 8), set(80, 8)],
      );
      expect(s.weight, 85);
      expect(s.reps, 6);
    });

    test('within range → hold weight and chase one more rep', () {
      final s = ProgressionEngine.suggest(
        exercise: bench,
        lastWorkingSets: [set(60, 10), set(60, 10), set(60, 9)],
      );
      expect(s.weight, 60);
      expect(s.reps, 11); // maxReps 10 + 1
    });

    test('missed the bottom → hold weight, target the bottom', () {
      final s = ProgressionEngine.suggest(
        exercise: bench,
        lastWorkingSets: [set(65, 7), set(65, 6), set(65, 5)],
      );
      expect(s.weight, 65);
      expect(s.reps, 8);
    });
  });
}
