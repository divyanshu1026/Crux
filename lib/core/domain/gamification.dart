import 'dart:math';

/// Gamification math (plan Phase 5) — pure functions, exhaustively testable.
///
/// XP awards: workout +50 · all planned sets +25 · PR +100 · weigh-in +5,
/// plus an occasional deterministic "Coach's bonus" (variable reward with a
/// seeded RNG so tests are stable and the reward can't be gamed by retrying).
abstract final class XpValues {
  static const workoutComplete = 50;
  static const allPlannedSets = 25;
  static const perPr = 100;
  static const weighIn = 5;
  static const hydrationGoal = 5;
}

/// XP needed to advance FROM [level] — plan curve: 100 × level^1.5.
int levelXpThreshold(int level) => (100 * pow(level, 1.5)).round();

/// Variable reward (plan §5): occasional surprise bonus, positive framing,
/// deterministic seed so it's testable. Seeded off the lifetime workout count —
/// roughly 1 in 4 sessions lands a 20–50 XP bonus.
({int xp, String? reason}) coachBonus(int workoutCountSeed) {
  final rng = Random(workoutCountSeed * 7919 + 17);
  if (rng.nextDouble() >= 0.25) return (xp: 0, reason: null);
  final amount = 20 + rng.nextInt(31); // 20–50
  const reasons = [
    'Coach\'s bonus: perfect form consistency this week.',
    'Coach\'s bonus: showing up is the hardest rep.',
    'Coach\'s bonus: quality session, extra credit.',
  ];
  return (xp: amount, reason: reasons[rng.nextInt(reasons.length)]);
}

/// Result of the daily streak check.
class StreakVerdict {
  final int streak;
  final int restPassesRemaining;
  final int lastRestPassMonth; // yyyyMM of the month a pass was last granted
  final String? message; // user-facing, only when something changed

  const StreakVerdict({
    required this.streak,
    required this.restPassesRemaining,
    required this.lastRestPassMonth,
    this.message,
  });
}

/// Streak protection (plan Phase 5.3): a missed *planned* day normally resets
/// the streak, but one auto-applied Rest Pass per month absorbs the miss —
/// "Life happens — your Rest Pass covered this week." Zero shame copy.
abstract final class StreakGuard {
  /// [today] the current date · [lastWorkout] most recent completed workout
  /// date (null = none yet) · [plannedWeekdays] 'Mon'..'Sun' the user chose.
  static StreakVerdict evaluate({
    required DateTime today,
    required DateTime? lastWorkout,
    required List<String> plannedWeekdays,
    required int currentStreak,
    required int restPassesRemaining,
    required int lastRestPassMonth,
  }) {
    // Refill: one pass per calendar month.
    final thisMonth = today.year * 100 + today.month;
    var passes = restPassesRemaining;
    var passMonth = lastRestPassMonth;
    if (thisMonth != lastRestPassMonth) {
      passes = 1;
      passMonth = thisMonth;
    }

    if (lastWorkout == null || currentStreak == 0 || plannedWeekdays.isEmpty) {
      return StreakVerdict(
        streak: currentStreak,
        restPassesRemaining: passes,
        lastRestPassMonth: passMonth,
      );
    }

    // Count planned days strictly between the last workout and today.
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var missed = 0;
    var d = DateTime(lastWorkout.year, lastWorkout.month, lastWorkout.day)
        .add(const Duration(days: 1));
    final end = DateTime(today.year, today.month, today.day);
    while (d.isBefore(end)) {
      if (plannedWeekdays.contains(weekdayNames[d.weekday - 1])) missed++;
      d = d.add(const Duration(days: 1));
    }

    if (missed == 0) {
      return StreakVerdict(
        streak: currentStreak,
        restPassesRemaining: passes,
        lastRestPassMonth: passMonth,
      );
    }
    if (missed == 1 && passes > 0) {
      return StreakVerdict(
        streak: currentStreak,
        restPassesRemaining: passes - 1,
        lastRestPassMonth: passMonth,
        message:
            'Life happens — your Rest Pass covered the missed day. Streak intact.',
      );
    }
    return StreakVerdict(
      streak: 0,
      restPassesRemaining: passes,
      lastRestPassMonth: passMonth,
      message:
          'Streak reset — every lifter restarts sometimes. Today is a fresh start.',
    );
  }
}

/// Daily hydration goal in ml from bodyweight (~35 ml/kg), rounded to 250 ml
/// steps and kept in a sane 1.5–4 L band.
int hydrationGoalMl(double weightKg) {
  final raw = weightKg * 35;
  final rounded = (raw / 250).round() * 250;
  return rounded.clamp(1500, 4000);
}

// ---------------------------------------------------------------------------
// Weekly completion — celebration + missed-day catch-up.
// ---------------------------------------------------------------------------

const kWeekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The Monday (midnight) of the week containing [d]. Shared boundary logic
/// for every weekly computation (progress, streaks, volume comparisons).
DateTime mondayOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// How the current week is tracking against its training-day target.
/// Progress is counted by **distinct calendar dates** with a completed
/// workout, not by which weekday they landed on — so a catch-up session
/// logged on a rest day still counts toward completing the week.
class WeekProgress {
  /// Number of training (non-rest) days assigned this week.
  final int targetDays;

  /// Distinct calendar dates this week with at least one completed workout.
  final int loggedDays;

  /// True once [loggedDays] has reached [targetDays] (never true if there's
  /// no schedule at all).
  final bool isComplete;

  /// Assigned weekdays strictly before today with no completed workout on
  /// that exact date — the raw material for the "you missed Wed" nudge.
  /// Cleared naturally once the user logs a catch-up session that completes
  /// the week (callers should gate the nudge on `!isComplete`).
  final List<String> missedWeekdays;

  const WeekProgress({
    required this.targetDays,
    required this.loggedDays,
    required this.isComplete,
    required this.missedWeekdays,
  });
}

/// [assignedWeekdays] — 'Mon'..'Sun' keys that have a training (non-rest) day
/// this week. [completedWorkoutDates] — every completed workout's date in
/// history (not pre-filtered; this function does the week-window filtering).
WeekProgress computeWeekProgress({
  required DateTime now,
  required Set<String> assignedWeekdays,
  required List<DateTime> completedWorkoutDates,
}) {
  final monday = mondayOfWeek(now);
  final today = DateTime(now.year, now.month, now.day);

  final datesThisWeek = completedWorkoutDates
      .map((d) => DateTime(d.year, d.month, d.day))
      .where((d) => !d.isBefore(monday) && d.difference(monday).inDays < 7)
      .toSet();

  final targetDays = assignedWeekdays.length;
  final isComplete = targetDays > 0 && datesThisWeek.length >= targetDays;

  final missed = <String>[];
  for (var i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    if (!date.isBefore(today)) break; // only strictly-past days are "missed"
    if (assignedWeekdays.contains(kWeekdayNames[i]) &&
        !datesThisWeek.contains(date)) {
      missed.add(kWeekdayNames[i]);
    }
  }

  return WeekProgress(
    targetDays: targetDays,
    loggedDays: datesThisWeek.length,
    isComplete: isComplete,
    missedWeekdays: missed,
  );
}

/// Consecutive fully-completed weeks ending with the current week (assumed
/// already complete by the caller), looking backward under today's schedule.
/// A reasonable proxy even though schedules can change week to week.
int consecutiveCompletedWeeks({
  required DateTime now,
  required Set<String> assignedWeekdays,
  required List<DateTime> completedWorkoutDates,
  int maxLookback = 52,
}) {
  if (assignedWeekdays.isEmpty) return 0;
  final target = assignedWeekdays.length;
  final dates =
      completedWorkoutDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();

  var monday = mondayOfWeek(now);
  var streak = 0;
  for (var w = 0; w < maxLookback; w++) {
    final count = List.generate(7, (i) => monday.add(Duration(days: i)))
        .where(dates.contains)
        .length;
    if (count < target) break;
    streak++;
    monday = monday.subtract(const Duration(days: 7));
  }
  return streak;
}

/// A short, positive line for the week-complete celebration (plan ethics:
/// motivate, never shame; no fabricated urgency). Prefers a concrete,
/// data-backed fact when one exists; otherwise a deterministic-but-varied
/// generic encouragement via [seed] so it doesn't feel robotic.
String weeklyRecapMessage({
  required double thisWeekVolumeKg,
  required double lastWeekVolumeKg,
  required int prsThisWeek,
  required int weeksStreak,
  required int seed,
}) {
  if (prsThisWeek == 1) {
    return 'You set a new PR this week — that\'s real progress, logged forever.';
  }
  if (prsThisWeek > 1) {
    return 'You set $prsThisWeek new PRs this week. That\'s a big week.';
  }
  if (lastWeekVolumeKg > 0 && thisWeekVolumeKg > lastWeekVolumeKg) {
    final pct =
        (((thisWeekVolumeKg - lastWeekVolumeKg) / lastWeekVolumeKg) * 100)
            .round();
    if (pct >= 1) {
      return 'Total volume is up $pct% from last week — the work is adding up.';
    }
  }
  if (weeksStreak >= 2) {
    return '$weeksStreak weeks in a row, fully completed. That\'s a habit now.';
  }
  const fallback = [
    'Every session banked this week makes the next one easier. Nice work.',
    'A full week, done. Rest well — next week starts fresh.',
    'Consistency beats intensity, and you showed up all week.',
  ];
  return fallback[seed.abs() % fallback.length];
}
