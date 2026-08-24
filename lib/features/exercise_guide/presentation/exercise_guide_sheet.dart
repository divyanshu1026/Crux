import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/data/exercise_guide.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Opens the how-to guide for an exercise. Design intent: the steps are the
/// hero, chrome stays quiet, and "Ask Coach" is the escape hatch for anything
/// the static guide can't answer.
void showExerciseGuideSheet(
  BuildContext context, {
  required String exerciseName,
  String muscleGroup = '',
  String equipment = '',
}) {
  CxHaptics.fire(CxHaptic.selection);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.88,
    ),
    builder: (_) => ExerciseGuideSheet(
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      equipment: equipment,
    ),
  );
}

class ExerciseGuideSheet extends ConsumerWidget {
  const ExerciseGuideSheet({
    super.key,
    required this.exerciseName,
    this.muscleGroup = '',
    this.equipment = '',
  });

  final String exerciseName;
  final String muscleGroup;
  final String equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final guide =
        ExerciseGuideLibrary.find(exerciseName, muscleGroup: muscleGroup);

    return CxGlassBottomSheet(
      title: exerciseName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta chips
          Center(
            child: Wrap(
              spacing: CxSpace.sm,
              alignment: WrapAlignment.center,
              children: [
                if (muscleGroup.isNotEmpty) _MetaChip(label: muscleGroup),
                if (equipment.isNotEmpty) _MetaChip(label: equipment),
              ],
            ),
          ),
          const SizedBox(height: CxSpace.lg),

          // Why this exercise
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CxSpace.lg),
            decoration: BoxDecoration(
              color: c.ultraviolet.withValues(alpha: 0.12),
              borderRadius: CxRadii.brLg,
            ),
            child: Text(
              guide.why,
              style: CxType.bodySmall.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: CxSpace.xl),

          // How to do it
          Text('HOW TO DO IT',
              style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.md),
          for (var i = 0; i < guide.steps.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: CxSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: Text('${i + 1}',
                        style: CxType.numS.copyWith(
                            color: c.ember, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: CxSpace.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(guide.steps[i],
                          style: CxType.bodySmall
                              .copyWith(color: c.textPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: CxSpace.sm),

          // Form cues
          Text('THINK ABOUT',
              style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.md),
          Wrap(
            spacing: CxSpace.sm,
            runSpacing: CxSpace.sm,
            children: [
              for (final cue in guide.cues)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: CxSpace.md, vertical: CxSpace.sm),
                  decoration: BoxDecoration(
                    color: c.mint,
                    borderRadius: CxRadii.brPill,
                  ),
                  child: Text(cue,
                      style: CxType.caption.copyWith(
                          color: cxPastelInk(),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: CxSpace.xl),

          // Common mistakes
          Text('COMMON MISTAKES',
              style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.md),
          for (final m in guide.mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: CxSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.close_rounded, size: 16, color: c.danger),
                  const SizedBox(width: CxSpace.sm),
                  Expanded(
                    child: Text(m,
                        style:
                            CxType.caption.copyWith(color: c.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: CxSpace.lg),

          // Breathing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.air_rounded, size: 18, color: c.ultraviolet),
              const SizedBox(width: CxSpace.sm),
              Expanded(
                child: Text(guide.breathing,
                    style: CxType.caption.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xl),

          // Safety note + Ask Coach
          Text(
            'Sharp pain? Stop the movement and ask a professional. Soreness is normal; pain is a signal.',
            style: CxType.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: CxSpace.lg),
          CxButton(
            label: 'Ask Coach about this exercise',
            icon: Icons.chat_bubble_outline_rounded,
            variant: CxButtonVariant.secondary,
            expand: true,
            onPressed: () => _askCoach(context, ref),
          ),
          const SizedBox(height: CxSpace.sm),
        ],
      ),
    );
  }

  void _askCoach(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    ref.read(coachChatProvider.notifier).sendMessage(
          'How do I do $exerciseName with proper form? Any tips for a beginner?',
          ref: ref,
        );
    context.go(Routes.coach);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CxSpace.md, vertical: CxSpace.xs),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: CxRadii.brPill,
        border: Border.all(color: c.border),
      ),
      child: Text(label,
          style: CxType.caption.copyWith(color: c.textSecondary)),
    );
  }
}
