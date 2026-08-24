import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/features/schedule/presentation/schedule_assistant.dart';

void main() {
  final program = Program(
    id: 'p',
    name: 'Test',
    description: '',
    whyFitsParagraph: '',
    days: const [
      WorkoutDay(id: 'pull_a', name: 'Pull A — Back Thickness', exercises: []),
      WorkoutDay(id: 'push_a', name: 'Push A — Chest Strength', exercises: []),
      WorkoutDay(id: 'legs', name: 'Legs — Train It Hard', exercises: []),
    ],
    dayAssignments: const {'Mon': 'pull_a', 'Tue': 'push_a', 'Wed': 'legs'},
  );

  group('parseScheduleCommand', () {
    test('rest day', () {
      final i = parseScheduleCommand('make wednesday a rest day', program);
      expect(i, isA<RestDayIntent>());
      expect((i as RestDayIntent).weekday, 'Wed');
    });

    test('swap days', () {
      final i = parseScheduleCommand('swap monday and friday', program);
      expect(i, isA<SwapDaysIntent>());
      final s = i as SwapDaysIntent;
      expect(s.a, 'Mon');
      expect(s.b, 'Fri');
    });

    test('move workout by keyword', () {
      final i = parseScheduleCommand('move legs to saturday', program);
      expect(i, isA<MoveWorkoutIntent>());
      final m = i as MoveWorkoutIntent;
      expect(m.dayId, 'legs');
      expect(m.targetWeekday, 'Sat');
    });

    test('move workout by fragment name ("pull a")', () {
      final i = parseScheduleCommand('put pull a on thursday', program);
      expect(i, isA<MoveWorkoutIntent>());
      expect((i as MoveWorkoutIntent).dayId, 'pull_a');
    });

    test('train N days', () {
      final i = parseScheduleCommand('i can only train 3 days', program);
      expect(i, isA<TrainNDaysIntent>());
      expect((i as TrainNDaysIntent).n, 3);
    });

    test('balance', () {
      expect(parseScheduleCommand('balance my week', program),
          isA<BalanceIntent>());
    });

    test('unrelated question returns null (hand off to coach)', () {
      expect(
          parseScheduleCommand(
              'should i eat more protein on rest days?', program),
          isNull);
      expect(parseScheduleCommand('', program), isNull);
    });
  });
}
