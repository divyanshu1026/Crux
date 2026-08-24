import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/domain/gamification.dart';

void main() {
  group('levelXpThreshold', () {
    test('follows the plan curve 100 × level^1.5', () {
      expect(levelXpThreshold(1), 100);
      expect(levelXpThreshold(4), 800);
      expect(levelXpThreshold(9), 2700);
    });
  });

  group('coachBonus', () {
    test('is deterministic for the same seed', () {
      final a = coachBonus(7);
      final b = coachBonus(7);
      expect(a.xp, b.xp);
      expect(a.reason, b.reason);
    });

    test('bonus, when present, is within 20–50 with a reason', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = coachBonus(seed);
        if (r.xp > 0) {
          expect(r.xp, inInclusiveRange(20, 50));
          expect(r.reason, isNotNull);
        } else {
          expect(r.reason, isNull);
        }
      }
    });

    test('fires sometimes but not always', () {
      final hits = List.generate(100, (s) => coachBonus(s).xp > 0)
          .where((h) => h)
          .length;
      expect(hits, greaterThan(5));
      expect(hits, lessThan(60));
    });
  });

  group('hydrationGoalMl', () {
    test('scales with bodyweight, rounded to 250, clamped to sane band', () {
      expect(hydrationGoalMl(70), 2500); // 2450 → 2500
      expect(hydrationGoalMl(40), 1500); // clamped up
      expect(hydrationGoalMl(150), 4000); // clamped down
    });
  });

  group('StreakGuard.evaluate', () {
    final monday = DateTime(2026, 7, 6); // a Monday

    test('no misses → streak untouched, pass refilled monthly', () {
      final v = StreakGuard.evaluate(
        today: monday.add(const Duration(days: 1)), // Tue
        lastWorkout: monday,
        plannedWeekdays: const ['Mon', 'Wed', 'Fri'],
        currentStreak: 6,
        restPassesRemaining: 0,
        lastRestPassMonth: 202606, // last granted in June
      );
      expect(v.streak, 6);
      expect(v.restPassesRemaining, 1); // July refill
      expect(v.message, isNull);
    });

    test('one missed planned day consumes the Rest Pass, streak survives', () {
      final v = StreakGuard.evaluate(
        today: monday.add(const Duration(days: 3)), // Thu; Wed was missed
        lastWorkout: monday,
        plannedWeekdays: const ['Mon', 'Wed', 'Fri'],
        currentStreak: 6,
        restPassesRemaining: 1,
        lastRestPassMonth: 202607,
      );
      expect(v.streak, 6);
      expect(v.restPassesRemaining, 0);
      expect(v.message, contains('Rest Pass'));
    });

    test('miss without a pass resets the streak, without shame copy', () {
      final v = StreakGuard.evaluate(
        today: monday.add(const Duration(days: 3)),
        lastWorkout: monday,
        plannedWeekdays: const ['Mon', 'Wed', 'Fri'],
        currentStreak: 6,
        restPassesRemaining: 0,
        lastRestPassMonth: 202607,
      );
      expect(v.streak, 0);
      expect(v.message, isNot(contains('fail')));
    });

    test('multiple misses reset even with a pass available', () {
      final v = StreakGuard.evaluate(
        today: monday.add(const Duration(days: 7)), // next Mon; Wed+Fri missed
        lastWorkout: monday,
        plannedWeekdays: const ['Mon', 'Wed', 'Fri'],
        currentStreak: 6,
        restPassesRemaining: 1,
        lastRestPassMonth: 202607,
      );
      expect(v.streak, 0);
      expect(v.restPassesRemaining, 1); // pass kept for a single-miss week
    });

    test('rest days between workouts never count as misses', () {
      final v = StreakGuard.evaluate(
        today: monday.add(const Duration(days: 2)), // Wed morning
        lastWorkout: monday,
        plannedWeekdays: const ['Mon', 'Wed', 'Fri'],
        currentStreak: 4,
        restPassesRemaining: 1,
        lastRestPassMonth: 202607,
      );
      // Tue is not planned; Wed is today (not yet missed).
      expect(v.streak, 4);
      expect(v.restPassesRemaining, 1);
    });
  });
}
