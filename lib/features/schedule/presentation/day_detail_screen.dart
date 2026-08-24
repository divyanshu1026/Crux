import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/exercise_catalog.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../exercise_guide/presentation/exercise_guide_sheet.dart';

/// Common rep-range presets offered when editing an exercise's prescription.
const _repPresets = ['4-6', '6-8', '8-10', '8-12', '10-12', '12-15', '15-20'];

/// Editable detail for one training day: add/remove exercises and tune the
/// sets, rep range, and rest per exercise. Design intent: each exercise is a
/// self-contained editable card; the prescription (sets × reps) is the hero.
class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.dayId});

  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final program = ref.watch(programProvider);
    WorkoutDay? day;
    if (program != null) {
      for (final d in program.days) {
        if (d.id == dayId) {
          day = d;
          break;
        }
      }
    }

    if (day == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(title: const Text('Workout')),
        body: Center(
          child: Text('This day is no longer in your program.',
              style: CxType.body.copyWith(color: c.textSecondary)),
        ),
      );
    }
    // Promote to non-null (the rename closure below captures it, which would
    // otherwise defeat flow promotion).
    final WorkoutDay day2 = day;

    final totalSets =
        day2.exercises.fold<int>(0, (sum, e) => sum + e.targetSets);

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: Text(day2.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: c.textSecondary),
            tooltip: 'Rename day',
            onPressed: () => _renameDay(context, ref, day2),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CxSpace.screen, CxSpace.sm, CxSpace.screen, 120),
        children: [
          Text(
            '${day2.exercises.length} exercises · $totalSets working sets',
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.lg),
          for (final ex in day2.exercises) ...[
            _ExerciseEditCard(dayId: dayId, exercise: ex),
            const SizedBox(height: CxSpace.md),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.ember,
        foregroundColor: c.onEmber,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add exercise'),
        onPressed: () => _addExercise(context, ref),
      ),
    );
  }

  void _renameDay(BuildContext context, WidgetRef ref, WorkoutDay day) {
    final controller = TextEditingController(text: day.name);
    final c = context.cx;
    CxHaptics.fire(CxHaptic.selection);
    showRqGlassBottomSheet(
      context: context,
      title: 'Rename Workout Day',
      headerIcon: Icons.edit_note_rounded,
      headerIconColor: c.ember,
      actionLabel: 'Save Changes',
      onActionPressed: () {
        final name = controller.text.trim();
        if (name.isNotEmpty) {
          ref.read(programProvider.notifier).renameDay(day.id, name);
          CxHaptics.fire(CxHaptic.success);
        }
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a descriptive name for this workout day that fits your training schedule.',
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.lg),
          CxTextField(
            label: 'Day Name',
            hint: 'e.g. Pull A — Back Thickness',
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(programProvider.notifier).renameDay(day.id, name);
                CxHaptics.fire(CxHaptic.success);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _addExercise(BuildContext context, WidgetRef ref) {
    CxHaptics.fire(CxHaptic.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _AddExerciseSheet(dayId: dayId),
    );
  }
}

class _ExerciseEditCard extends ConsumerWidget {
  const _ExerciseEditCard({required this.dayId, required this.exercise});
  final String dayId;
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final notifier = ref.read(programProvider.notifier);

    return CxCard(
      padding: const EdgeInsets.all(CxSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name (→ guide) + delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => showExerciseGuideSheet(
                    context,
                    exerciseName: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    equipment: exercise.equipment,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(exercise.name,
                                style: CxType.titleSmall
                                    .copyWith(color: c.textPrimary)),
                          ),
                          const SizedBox(width: CxSpace.xs),
                          Icon(Icons.help_outline_rounded,
                              size: 15, color: c.ultraviolet),
                        ],
                      ),
                      Text('${exercise.muscleGroup} · ${exercise.equipment}',
                          style:
                              CxType.caption.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                tooltip: 'Remove',
                onPressed: () {
                  CxHaptics.fire(CxHaptic.warning);
                  notifier.removeExerciseFromDay(dayId, exercise.id);
                },
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),

          // Sets stepper + rest stepper
          Row(
            children: [
              Expanded(
                child: _MiniStepper(
                  label: 'Sets',
                  value: '${exercise.targetSets}',
                  onDecrement: exercise.targetSets > 1
                      ? () => notifier.updateExerciseInDay(dayId, exercise.id,
                          targetSets: exercise.targetSets - 1)
                      : null,
                  onIncrement: exercise.targetSets < 10
                      ? () => notifier.updateExerciseInDay(dayId, exercise.id,
                          targetSets: exercise.targetSets + 1)
                      : null,
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: _MiniStepper(
                  label: 'Rest',
                  value: '${exercise.restTimeSeconds}s',
                  onDecrement: exercise.restTimeSeconds > 30
                      ? () => notifier.updateExerciseInDay(dayId, exercise.id,
                          restTimeSeconds: exercise.restTimeSeconds - 15)
                      : null,
                  onIncrement: exercise.restTimeSeconds < 300
                      ? () => notifier.updateExerciseInDay(dayId, exercise.id,
                          restTimeSeconds: exercise.restTimeSeconds + 15)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),

          // Rep-range presets
          Text('REP RANGE',
              style: CxType.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.sm),
          Wrap(
            spacing: CxSpace.sm,
            runSpacing: CxSpace.sm,
            children: [
              for (final preset in _repPresets)
                GestureDetector(
                  onTap: () {
                    CxHaptics.fire(CxHaptic.selection);
                    notifier.updateExerciseInDay(dayId, exercise.id,
                        targetReps: preset);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: CxSpace.md, vertical: CxSpace.sm),
                    decoration: BoxDecoration(
                      color: exercise.targetReps == preset
                          ? c.ember
                          : c.surfaceHigh,
                      borderRadius: CxRadii.brPill,
                      border: Border.all(
                        color: exercise.targetReps == preset
                            ? c.ember
                            : c.border,
                      ),
                    ),
                    child: Text(preset,
                        style: CxType.label.copyWith(
                          color: exercise.targetReps == preset
                              ? c.onEmber
                              : c.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFamily: CxFonts.mono,
                        )),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.label,
    required this.value,
    this.onIncrement,
    this.onDecrement,
  });
  final String label;
  final String value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CxSpace.sm, vertical: CxSpace.xs),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: CxRadii.brMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _RoundBtn(
              icon: Icons.remove_rounded, onTap: onDecrement, c: c),
          Expanded(
            child: Column(
              children: [
                Text(value,
                    style: CxType.numS.copyWith(
                        color: c.textPrimary, fontWeight: FontWeight.bold)),
                Text(label,
                    style: CxType.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          _RoundBtn(icon: Icons.add_rounded, onTap: onIncrement, c: c),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, required this.c});
  final IconData icon;
  final VoidCallback? onTap;
  final CxColorsExt c;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              CxHaptics.fire(CxHaptic.selection);
              onTap!();
            }
          : null,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.surface : c.surface.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? c.textPrimary : c.textTertiary),
      ),
    );
  }
}

/// Muscle-grouped catalog picker for adding an exercise to the day.
class _AddExerciseSheet extends ConsumerWidget {
  const _AddExerciseSheet({required this.dayId});
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    return CxGlassBottomSheet(
      title: 'Add exercise',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final muscle in ExerciseCatalog.muscleGroups) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: CxSpace.md, bottom: CxSpace.sm),
              child: Text(muscle.toUpperCase(),
                  style: CxType.overline.copyWith(color: c.ultraviolet)),
            ),
            for (final entry in ExerciseCatalog.byMuscle(muscle))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.name,
                    style: CxType.bodySmall.copyWith(color: c.textPrimary)),
                subtitle: Text('${entry.equipment} · ${entry.defaultReps} reps',
                    style: CxType.caption.copyWith(color: c.textTertiary)),
                trailing: Icon(Icons.add_circle_outline_rounded, color: c.ember),
                onTap: () {
                  CxHaptics.fire(CxHaptic.success);
                  ref
                      .read(programProvider.notifier)
                      .addExerciseToDay(dayId, entry.toExercise());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${entry.name}')),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
