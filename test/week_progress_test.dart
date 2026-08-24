import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/domain/gamification.dart';

void main() {
  // 2026-07-06 is a Monday.
  final mon = DateTime(2026, 7, 6);
  DateTime d(int offset) => mon.add(Duration(days: offset));

  group('computeWeekProgress', () {
    test('no schedule → never complete', () {
      final p = computeWeekProgress(
        now: d(4),
        assignedWeekdays: {},
        completedWorkoutDates: [d(0), d(1)],
      );
      expect(p.isComplete, false);
      expect(p.targetDays, 0);
    });

    test('all planned days logged → complete', () {
      final p = computeWeekProgress(
        now: d(4), // Friday
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0), d(2), d(4)],
      );
      expect(p.isComplete, true);
      expect(p.loggedDays, 3);
      expect(p.missedWeekdays, isEmpty);
    });

    test('missed Wed detected on Friday; week not complete', () {
      final p = computeWeekProgress(
        now: d(4), // Friday
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0)],
      );
      expect(p.isComplete, false);
      expect(p.missedWeekdays, ['Wed']);
    });

    test('catch-up on a rest day (Sat) completes the week by count', () {
      // Missed Wed, but trained Sat instead: Mon + Fri + Sat = 3 dates.
      final p = computeWeekProgress(
        now: d(5).add(const Duration(hours: 20)), // Saturday evening
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0), d(4), d(5)],
      );
      expect(p.isComplete, true);
    });

    test('today is never counted as missed', () {
      final p = computeWeekProgress(
        now: d(2), // Wednesday morning, not trained yet
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0)],
      );
      expect(p.missedWeekdays, isEmpty);
    });

    test('last week\'s workouts don\'t leak into this week', () {
      final p = computeWeekProgress(
        now: d(1),
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(-7), d(-5), d(-3), d(0)],
      );
      expect(p.loggedDays, 1);
    });

    test('two sessions on the same date count as one day', () {
      final p = computeWeekProgress(
        now: d(4),
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0), d(0), d(2)],
      );
      expect(p.loggedDays, 2);
      expect(p.isComplete, false);
    });
  });

  group('consecutiveCompletedWeeks', () {
    test('counts back-to-back complete weeks and stops at a gap', () {
      final dates = [
        // this week: Mon Wed Fri
        d(0), d(2), d(4),
        // last week: complete
        d(-7), d(-5), d(-3),
        // two weeks ago: only one day → breaks the chain
        d(-14),
      ];
      final streak = consecutiveCompletedWeeks(
        now: d(4),
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: dates,
      );
      expect(streak, 2);
    });

    test('zero when this week itself is incomplete', () {
      final streak = consecutiveCompletedWeeks(
        now: d(4),
        assignedWeekdays: {'Mon', 'Wed', 'Fri'},
        completedWorkoutDates: [d(0)],
      );
      expect(streak, 0);
    });
  });

  group('weeklyRecapMessage', () {
    test('PRs win over everything', () {
      final msg = weeklyRecapMessage(
        thisWeekVolumeKg: 5000,
        lastWeekVolumeKg: 1000,
        prsThisWeek: 2,
        weeksStreak: 5,
        seed: 1,
      );
      expect(msg, contains('2 new PRs'));
    });

    test('volume increase is quoted as a percentage', () {
      final msg = weeklyRecapMessage(
        thisWeekVolumeKg: 1100,
        lastWeekVolumeKg: 1000,
        prsThisWeek: 0,
        weeksStreak: 1,
        seed: 1,
      );
      expect(msg, contains('10%'));
    });

    test('weeks streak used when no PRs/volume gain', () {
      final msg = weeklyRecapMessage(
        thisWeekVolumeKg: 900,
        lastWeekVolumeKg: 1000,
        prsThisWeek: 0,
        weeksStreak: 3,
        seed: 1,
      );
      expect(msg, contains('3 weeks in a row'));
    });

    test('always returns something positive as a fallback', () {
      for (var seed = 0; seed < 6; seed++) {
        final msg = weeklyRecapMessage(
          thisWeekVolumeKg: 0,
          lastWeekVolumeKg: 0,
          prsThisWeek: 0,
          weeksStreak: 1,
          seed: seed,
        );
        expect(msg, isNotEmpty);
      }
    });
  });
}
