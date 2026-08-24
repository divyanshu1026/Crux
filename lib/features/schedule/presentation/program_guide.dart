import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// "How this program works" — the coaching context from the plan (rules, how to
/// progress) plus a **live weekly set-volume breakdown computed from the user's
/// actual schedule**. Shown under the weekly schedule. (Nutrition/recovery and
/// the legs footnote are intentionally omitted per the user's request.)
class ProgramGuideSection extends StatelessWidget {
  const ProgramGuideSection({super.key, required this.program});
  final Program program;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final volume = weeklyVolume(program);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Program guide',
            style: CxType.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: CxSpace.md),

        // --- Weekly volume (live) --------------------------------------------
        CxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.donut_large_rounded, color: c.ultraviolet, size: 20),
                  const SizedBox(width: CxSpace.sm),
                  Text('WEEKLY VOLUME',
                      style: CxType.overline.copyWith(color: c.textSecondary)),
                ],
              ),
              const SizedBox(height: CxSpace.xs),
              Text('Working sets per muscle across your week',
                  style: CxType.caption.copyWith(color: c.textTertiary)),
              const SizedBox(height: CxSpace.lg),
              if (volume.isEmpty)
                Text('Assign workouts to weekdays to see your volume.',
                    style: CxType.bodySmall.copyWith(color: c.textSecondary))
              else
                for (final entry in volume.entries) ...[
                  _VolumeRow(
                    muscle: entry.key,
                    sets: entry.value,
                    max: volume.values.first,
                  ),
                  const SizedBox(height: CxSpace.sm),
                ],
              const SizedBox(height: CxSpace.sm),
              Wrap(
                spacing: CxSpace.md,
                runSpacing: CxSpace.xs,
                children: [
                  _LegendDot(color: c.success, label: '10–20 growth zone'),
                  _LegendDot(color: c.warning, label: 'below 10'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: CxSpace.lg),

        // --- How to progress -------------------------------------------------
        CxPastelCard(
          tint: CxPastelTint.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: cxPastelInk(), size: 20),
                  const SizedBox(width: CxSpace.sm),
                  Expanded(
                    child: Text(
                      'HOW TO PROGRESS',
                      style: CxType.overline
                          .copyWith(color: cxPastelInk(opacity: 0.8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Double progression',
                style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.7)),
              ),
              const SizedBox(height: CxSpace.md),
              _GuideStep(
                n: 1,
                text: 'Start at a weight you can do for the bottom of the rep range with 1–2 reps in reserve.',
              ),
              _GuideStep(
                n: 2,
                text: 'Add reps each week until you hit the top of the range on all sets.',
              ),
              _GuideStep(
                n: 3,
                text: 'Then add a small jump (+2.5 kg upper, +5 kg lower) and reset to the bottom. Repeat.',
              ),
              const SizedBox(height: CxSpace.sm),
              Container(
                padding: const EdgeInsets.all(CxSpace.md),
                decoration: BoxDecoration(
                  color: cxPastelInk(opacity: 0.06),
                  borderRadius: CxRadii.brMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: cxPastelInk()),
                    const SizedBox(width: CxSpace.sm),
                    Expanded(
                      child: Text(
                        'Crux applies this for you — each workout starts pre-filled with the right weight and reps from last session.',
                        style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CxSpace.lg),

        // --- Key rules -------------------------------------------------------
        CxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KEY RULES',
                  style: CxType.overline.copyWith(color: c.textSecondary)),
              const SizedBox(height: CxSpace.md),
              for (final rule in _rules) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: CxSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: c.ember),
                      const SizedBox(width: CxSpace.sm),
                      Expanded(
                        child: Text(rule,
                            style: CxType.bodySmall.copyWith(color: c.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static const _rules = [
    'Keep 1–3 reps in reserve on most sets; only the last set of an isolation exercise goes near failure.',
    'Log every session — beating last week\'s numbers over time is the whole point.',
    'Do compounds first while you\'re fresh, isolation last.',
    'Deload every 6–8 weeks (halve the sets for one week).',
    'Keep isolation rest around 60 seconds to stay inside your session length.',
  ];

  /// Sums working sets per muscle group across every assigned weekday. Returns a
  /// map ordered by volume descending.
  static Map<String, int> weeklyVolume(Program program) {
    final totals = <String, int>{};
    final assignedDayIds = program.dayAssignments.values.toSet();
    // If no explicit assignments, fall back to counting each program day once.
    final days = assignedDayIds.isNotEmpty
        ? program.days.where((d) => assignedDayIds.contains(d.id))
        : program.days;
    // A weekday can only map to one day, but the same day can be on multiple
    // weekdays — count each assignment occurrence.
    if (program.dayAssignments.isNotEmpty) {
      for (final dayId in program.dayAssignments.values) {
        final day = _dayById(program, dayId);
        if (day == null) continue;
        for (final ex in day.exercises) {
          totals[ex.muscleGroup] = (totals[ex.muscleGroup] ?? 0) + ex.targetSets;
        }
      }
    } else {
      for (final day in days) {
        for (final ex in day.exercises) {
          totals[ex.muscleGroup] = (totals[ex.muscleGroup] ?? 0) + ex.targetSets;
        }
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  static WorkoutDay? _dayById(Program program, String id) {
    for (final d in program.days) {
      if (d.id == id) return d;
    }
    return null;
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.muscle, required this.sets, required this.max});
  final String muscle;
  final int sets;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final low = sets < 10;
    final barColor = low ? c.warning : c.success;
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(muscle,
              style: CxType.caption.copyWith(color: c.textPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: CxRadii.brPill,
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : (sets / max).clamp(0.05, 1),
              minHeight: 8,
              backgroundColor: c.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: CxSpace.md),
        SizedBox(
          width: 44,
          child: Text('$sets sets',
              textAlign: TextAlign.right,
              style: CxType.caption.copyWith(
                  color: c.textSecondary, fontFamily: CxFonts.mono)),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: CxType.caption.copyWith(color: c.textTertiary)),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CxSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cxPastelInk(opacity: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text('$n',
                style: CxType.numS.copyWith(
                    color: cxPastelInk(), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: CxSpace.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text,
                  style: CxType.bodySmall.copyWith(color: cxPastelInk(opacity: 0.9))),
            ),
          ),
        ],
      ),
    );
  }
}
