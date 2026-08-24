import '../models/models.dart';

/// A parsed rep prescription, e.g. "8-12" → low 8, high 12. A single number or
/// a time-based cue ("60s") parses to low == high.
class RepRange {
  final int low;
  final int high;
  const RepRange(this.low, this.high);

  bool get isSingle => low == high;

  factory RepRange.parse(String raw) {
    final parts = raw.split('-');
    int digits(String s) {
      final m = RegExp(r'\d+').firstMatch(s);
      return m == null ? 0 : int.parse(m.group(0)!);
    }

    if (parts.length >= 2) {
      final lo = digits(parts[0]);
      final hi = digits(parts[1]);
      if (lo == 0 && hi == 0) return const RepRange(8, 12);
      return RepRange(lo == 0 ? hi : lo, hi == 0 ? lo : hi);
    }
    final n = digits(raw);
    if (n == 0) return const RepRange(8, 12);
    return RepRange(n, n);
  }

  @override
  String toString() => isSingle ? '$low' : '$low-$high';
}

/// The next-session suggestion for one exercise, with a plain-language reason
/// the UI surfaces so the user understands *why* the numbers changed.
class ProgressionSuggestion {
  final double weight;
  final int reps;
  final String reason;
  const ProgressionSuggestion({
    required this.weight,
    required this.reps,
    required this.reason,
  });
}

/// Deterministic **double-progression** engine (the method in the coach's PDF):
/// start at the bottom of the rep range, add reps weekly until you hit the top
/// on all sets, then add a small load jump and reset to the bottom.
///
/// Pure and side-effect free so it's exhaustively testable and identical on
/// every platform.
abstract final class ProgressionEngine {
  /// Load jump when graduating the rep range: heavier for lower-body compounds.
  static double incrementFor(Exercise exercise) =>
      (exercise.muscleGroup == 'Legs' || exercise.muscleGroup == 'Glutes')
          ? 5.0
          : 2.5;

  /// Suggests the working weight + rep target for [exercise] given the
  /// completed working sets from the **last** time it was performed. Pass an
  /// empty list for a first-ever session.
  static ProgressionSuggestion suggest({
    required Exercise exercise,
    required List<SetLog> lastWorkingSets,
  }) {
    final range = RepRange.parse(exercise.targetReps);

    // No history → start conservatively at the bottom of the range.
    if (lastWorkingSets.isEmpty) {
      return ProgressionSuggestion(
        weight: exercise.suggestedWeight,
        reps: range.low,
        reason: range.isSingle
            ? 'Starting point — aim for ${range.low}, keeping 1–2 reps in reserve.'
            : 'Starting weight — aim for ${range.low} reps with 1–2 in reserve.',
      );
    }

    // Working weight = the top (heaviest) working set last time.
    final workingWeight =
        lastWorkingSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
    final maxReps =
        lastWorkingSets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
    final allHitTop = lastWorkingSets.every((s) => s.reps >= range.high);
    final anyBelowBottom = lastWorkingSets.any((s) => s.reps < range.low);
    final inc = incrementFor(exercise);

    if (allHitTop) {
      // Graduated the range on every set → add load, reset to the bottom.
      return ProgressionSuggestion(
        weight: workingWeight + inc,
        reps: range.low,
        reason:
            'You hit ${range.high} on every set — +${_fmt(inc)}kg and reset to ${range.low} (double progression).',
      );
    } else if (anyBelowBottom) {
      // Fell short → hold the weight and consolidate clean reps.
      return ProgressionSuggestion(
        weight: workingWeight,
        reps: range.low,
        reason:
            'Hold ${_fmt(workingWeight)}kg and lock in ${range.low}+ clean reps before adding.',
      );
    } else {
      // Inside the range → chase one more rep at the same weight.
      final target = (maxReps + 1).clamp(range.low, range.high);
      return ProgressionSuggestion(
        weight: workingWeight,
        reps: target,
        reason:
            'Same weight — add a rep toward ${range.high} (you managed $maxReps last time).',
      );
    }
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
