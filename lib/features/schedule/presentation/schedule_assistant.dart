import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';

// ---------------------------------------------------------------------------
// Intent parsing (pure — unit tested)
// ---------------------------------------------------------------------------

/// A recognized schedule edit. Parsed deterministically so schedule changes
/// work offline and are instant; anything unrecognized is handed to the full
/// coach chat instead of being guessed at.
sealed class ScheduleIntent {}

class RestDayIntent extends ScheduleIntent {
  RestDayIntent(this.weekday);
  final String weekday;
}

class SwapDaysIntent extends ScheduleIntent {
  SwapDaysIntent(this.a, this.b);
  final String a;
  final String b;
}

class MoveWorkoutIntent extends ScheduleIntent {
  MoveWorkoutIntent(this.dayId, this.workoutName, this.targetWeekday);
  final String dayId;
  final String workoutName;
  final String targetWeekday;
}

class TrainNDaysIntent extends ScheduleIntent {
  TrainNDaysIntent(this.n);
  final int n;
}

class BalanceIntent extends ScheduleIntent {}

const _weekdayTokens = {
  'mon': 'Mon', 'monday': 'Mon',
  'tue': 'Tue', 'tues': 'Tue', 'tuesday': 'Tue',
  'wed': 'Wed', 'wednesday': 'Wed',
  'thu': 'Thu', 'thur': 'Thu', 'thurs': 'Thu', 'thursday': 'Thu',
  'fri': 'Fri', 'friday': 'Fri',
  'sat': 'Sat', 'saturday': 'Sat',
  'sun': 'Sun', 'sunday': 'Sun',
};

/// Sensible default training-day layouts per week-count.
const kDefaultDayLayouts = {
  2: ['Mon', 'Thu'],
  3: ['Mon', 'Wed', 'Fri'],
  4: ['Mon', 'Tue', 'Thu', 'Fri'],
  5: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
  6: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
};

List<String> _weekdaysIn(String text) {
  final found = <String>[];
  for (final word in text.split(RegExp(r'[^a-z]+'))) {
    final wd = _weekdayTokens[word];
    if (wd != null && !found.contains(wd)) found.add(wd);
  }
  return found;
}

/// Parses a natural-language schedule command against the user's [program].
/// Returns null when the request isn't a recognizable schedule edit.
ScheduleIntent? parseScheduleCommand(String input, Program program) {
  final text = input.toLowerCase().trim();
  if (text.isEmpty) return null;
  final days = _weekdaysIn(text);

  // "swap monday and friday"
  if (text.contains('swap') && days.length >= 2) {
    return SwapDaysIntent(days[0], days[1]);
  }

  // "make wednesday a rest day" / "rest on sunday"
  if (text.contains('rest') && days.isNotEmpty) {
    return RestDayIntent(days.first);
  }

  // "train 3 days" / "i can only do 4 days a week"
  final nMatch = RegExp(r'(\d)\s*days?').firstMatch(text);
  if (nMatch != null &&
      (text.contains('train') ||
          text.contains('only') ||
          text.contains('do ') ||
          text.contains('week'))) {
    final n = int.parse(nMatch.group(1)!);
    if (n >= 2 && n <= 6) return TrainNDaysIntent(n);
  }

  // "move legs to saturday" / "put pull a on monday"
  if ((text.contains('move') ||
          text.contains('put') ||
          text.contains(' to ') ||
          text.contains(' on ')) &&
      days.isNotEmpty) {
    final target = days.last;
    // Match a program day by name tokens (longest name match wins so
    // "pull a" beats a bare "pull").
    WorkoutDay? bestDay;
    var bestLen = 0;
    for (final d in program.days) {
      final name = d.name.toLowerCase();
      // Try full name then meaningful fragments ("pull a", "legs").
      final fragments = <String>{
        name,
        ...name.split(RegExp(r'[—\-·:]')).map((s) => s.trim()),
      }..removeWhere((s) => s.length < 3);
      for (final frag in fragments) {
        if (text.contains(frag) && frag.length > bestLen) {
          bestDay = d;
          bestLen = frag.length;
        }
      }
      // Loose keyword match on first word ("legs", "pull", "push", "upper"…)
      final first = name.split(RegExp(r'\s+')).first;
      if (first.length >= 3 && text.contains(first) && first.length > bestLen) {
        bestDay = d;
        bestLen = first.length;
      }
    }
    if (bestDay != null) {
      return MoveWorkoutIntent(bestDay.id, bestDay.name, target);
    }
  }

  // "balance / rebuild / spread my week"
  if (text.contains('balance') ||
      text.contains('rebuild') ||
      text.contains('spread') ||
      text.contains('auto')) {
    return BalanceIntent();
  }

  return null;
}

// ---------------------------------------------------------------------------
// Applying intents
// ---------------------------------------------------------------------------

/// Executes [intent] against the program and returns a coach-voiced
/// confirmation for the chat to display.
String applyScheduleIntent(Ref ref, ScheduleIntent intent) {
  final notifier = ref.read(programProvider.notifier);
  final program = ref.read(programProvider)!;

  switch (intent) {
    case RestDayIntent(:final weekday):
      notifier.assignWorkoutToWeekday(weekday, null);
      return 'Done — $weekday is now a rest day. Recovery counts as training.';

    case SwapDaysIntent(:final a, :final b):
      final aId = program.dayAssignments[a];
      final bId = program.dayAssignments[b];
      notifier.assignWorkoutToWeekday(a, bId);
      notifier.assignWorkoutToWeekday(b, aId);
      return 'Swapped $a and $b. Your week is updated.';

    case MoveWorkoutIntent(:final dayId, :final workoutName, :final targetWeekday):
      // Move (not copy): clear the weekday that currently holds it.
      for (final entry in program.dayAssignments.entries) {
        if (entry.value == dayId && entry.key != targetWeekday) {
          notifier.assignWorkoutToWeekday(entry.key, null);
          break;
        }
      }
      notifier.assignWorkoutToWeekday(targetWeekday, dayId);
      return 'Moved $workoutName to $targetWeekday.';

    case TrainNDaysIntent(:final n):
      final layout = kDefaultDayLayouts[n]!;
      notifier.autoAssignSchedule(layout);
      return 'Rebuilt your week around $n days (${layout.join(' · ')}). '
          'Tweak any day if those don\'t fit.';

    case BalanceIntent():
      final days = ref.read(userProfileProvider).daysPerWeek;
      notifier.autoAssignSchedule(days);
      return 'Balanced your workouts evenly across your training days.';
  }
}

