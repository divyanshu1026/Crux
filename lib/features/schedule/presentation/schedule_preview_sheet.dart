import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/program_diff.dart';

/// Review step between Coach proposing a change and it actually happening.
///
/// Three things, in the order they matter:
///   1. What will change — computed from the two programs, not from the
///      model's account of its own work.
///   2. Why — Coach's reasoning, clearly attributed.
///   3. Coach's objection, if it thinks this is a bad idea for you. Shown
///      prominently, but it never blocks: the change is yours to make.
///
/// Returns true when the user accepts.
Future<bool> showSchedulePreviewSheet(
  BuildContext context, {
  required Program before,
  required Program after,
  required String note,
  String? concern,
  required String request,
}) async {
  final diff = ProgramDiff.between(before, after);
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _PreviewSheet(
      diff: diff,
      note: note,
      concern: concern,
      request: request,
    ),
  );
  return result ?? false;
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    required this.diff,
    required this.note,
    required this.concern,
    required this.request,
  });

  final ProgramDiff diff;
  final String note;
  final String? concern;
  final String request;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final hasConcern = concern != null && concern!.trim().isNotEmpty;

    return CxGlassBottomSheet(
      title: 'Review this change',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You asked: "$request"',
            style: CxType.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: CxSpace.lg),

          // --- What changes ---------------------------------------------
          Text('What changes',
              style: CxType.titleSmall.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.sm),
          if (diff.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(CxSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: CxRadii.brMd,
              ),
              child: Text(
                "Nothing — Coach didn't actually change your plan. Try being "
                'more specific about what you want different.',
                style: CxType.bodySmall.copyWith(color: c.textSecondary),
              ),
            )
          else
            for (final change in diff.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: CxSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(change.kind), size: 16, color: c.ember),
                    const SizedBox(width: CxSpace.sm),
                    Expanded(
                      child: Text(
                        change.text,
                        style:
                            CxType.bodySmall.copyWith(color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

          // --- Coach's reasoning ----------------------------------------
          const SizedBox(height: CxSpace.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CxSpace.lg),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: CxRadii.brLg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const YorhartWidget(expression: 'coaching', size: 32),
                const SizedBox(width: CxSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coach',
                          style: CxType.caption.copyWith(color: c.textTertiary)),
                      const SizedBox(height: 2),
                      Text(note,
                          style: CxType.bodySmall
                              .copyWith(color: c.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Coach's objection ----------------------------------------
          if (hasConcern) ...[
            const SizedBox(height: CxSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(CxSpace.lg),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: CxRadii.brLg,
                border: Border.all(color: c.warning.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: c.warning),
                      const SizedBox(width: CxSpace.sm),
                      Text("Coach isn't sure about this",
                          style: CxType.caption.copyWith(color: c.warning)),
                    ],
                  ),
                  const SizedBox(height: CxSpace.sm),
                  Text(concern!,
                      style:
                          CxType.bodySmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  Text(
                    "It's still your call — applying this will do exactly what "
                    'you asked.',
                    style: CxType.caption.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: CxSpace.xl),
          CxButton(
            label: diff.isEmpty ? 'Close' : 'Apply this change',
            expand: true,
            haptic: CxHaptic.success,
            onPressed: () => Navigator.pop(context, diff.isNotEmpty),
          ),
          if (diff.isNotEmpty) ...[
            const SizedBox(height: CxSpace.sm),
            CxButton(
              label: 'Keep my current plan',
              variant: CxButtonVariant.secondary,
              expand: true,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
          const SizedBox(height: CxSpace.sm),
        ],
      ),
    );
  }

  IconData _iconFor(ChangeKind kind) => switch (kind) {
        ChangeKind.schedule => Icons.calendar_today_rounded,
        ChangeKind.session => Icons.fitness_center_rounded,
        ChangeKind.exercise => Icons.swap_horiz_rounded,
        ChangeKind.volume => Icons.trending_up_rounded,
      };
}
