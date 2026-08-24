import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/rest_alert_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../exercise_guide/presentation/exercise_guide_sheet.dart';
import 'workout_summary_screen.dart';

/// Active workout — optimized for ≤3 taps per set.
///
/// Design intent:
/// - Hero: giant weight + reps + one Log button for the current set
/// - Quiet: exercise rail, set dots, previous performance
/// - Moves: rest timer bar; PR overlay only
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _clock;
  bool _alertPlaying = false;
  int _exerciseIndex = 0;

  /// Seconds since the session began, from the timestamp stored on the session
  /// itself.
  ///
  /// This used to anchor to a `DateTime.now()` captured in [initState], which
  /// meant the clock restarted every time the widget was rebuilt — leaving the
  /// screen and coming back showed 00:00 again even though the workout had
  /// been running for twenty minutes. The session outlives the widget, so the
  /// start time belongs there; it also survives the app being killed.
  int get _elapsedSeconds {
    final session = ref.read(activeWorkoutProvider);
    final started = session?.startedAt ?? session?.date;
    if (started == null) return 0;
    final secs = DateTime.now().difference(started).inSeconds;
    return secs < 0 ? 0 : secs;
  }

  @override
  void initState() {
    super.initState();
    // The tick only asks the UI to redraw; the value itself is always derived
    // from wall-clock time, so a missed or delayed tick can never drift.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(RestAlertService.instance.stop());
    super.dispose();
  }

  Future<void> _startAlertTone() async {
    if (_alertPlaying) return;
    _alertPlaying = true;
    await RestAlertService.instance.start();
  }

  Future<void> _stopAlertTone() async {
    _alertPlaying = false;
    await RestAlertService.instance.stop();
  }

  void _dismissRestAlert() {
    unawaited(_stopAlertTone());
    ref.read(activeWorkoutProvider.notifier).dismissRestCompleteAlert();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final session = ref.watch(activeWorkoutProvider);
    final prCelebration = ref.watch(prCelebrationProvider);
    final units = ref.watch(userProfileProvider).units;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    // Keep focus index in range if exercises were swapped/removed.
    if (_exerciseIndex >= session.exercises.length) {
      _exerciseIndex = session.exercises.length - 1;
    }
    if (_exerciseIndex < 0) _exerciseIndex = 0;

    final exLog = session.exercises[_exerciseIndex];
    final focusSetIndex = _nextOpenSetIndex(exLog);
    final focusSet = focusSetIndex != null ? exLog.sets[focusSetIndex] : null;
    final allDone = focusSet == null;

    final totalSets = session.exercises.fold<int>(0, (n, e) => n + e.sets.length);
    final doneSets = session.exercises.fold<int>(
      0,
      (n, e) => n + e.sets.where((s) => s.completed).length,
    );

    final prev = _previousPerformance(exLog.exerciseName);
    final notifier = ref.watch(activeWorkoutProvider.notifier);
    final resting = notifier.restTimerActive;
    final restAlert = notifier.restCompleteAlert;

    // Start / stop the rest-complete tone when the alert flag flips.
    if (restAlert && !_alertPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(activeWorkoutProvider.notifier).restCompleteAlert) {
          unawaited(_startAlertTone());
        }
      });
    } else if (!restAlert && _alertPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_stopAlertTone());
      });
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  title: session.workoutDayName,
                  elapsed: _formatClock(_elapsedSeconds),
                  doneSets: doneSets,
                  totalSets: totalSets,
                  colors: c,
                  onMinimize: () => Navigator.pop(context),
                  onFinish: () => _finishWorkout(),
                  onCancel: () => _showCancelDialog(context),
                ),
                if (restAlert)
                  _RestCompleteBanner(
                    colors: c,
                    onStop: _dismissRestAlert,
                  ),
                _ExerciseRail(
                  exercises: session.exercises,
                  currentIndex: _exerciseIndex,
                  colors: c,
                  onSelect: (i) {
                    _dismissRestAlert();
                    setState(() => _exerciseIndex = i);
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      CxSpace.screen,
                      CxSpace.md,
                      CxSpace.screen,
                      resting || restAlert ? 200 : 120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExerciseHeader(
                          exLog: exLog,
                          previous: prev,
                          colors: c,
                          onGuide: () => showExerciseGuideSheet(
                            context,
                            exerciseName: exLog.exerciseName,
                            muscleGroup: exLog.muscleGroup,
                          ),
                          onMore: () => _showExerciseActions(exLog),
                        ),
                        const SizedBox(height: CxSpace.xl),
                        _SetDots(
                          sets: exLog.sets,
                          focusIndex: focusSetIndex,
                          colors: c,
                          onTap: (i) {
                            // Jump focus by un-completing isn't needed —
                            // tapping a completed set lets you edit/re-log.
                            setState(() {});
                            if (exLog.sets[i].completed) {
                              _showEditCompletedSet(exLog, i, units);
                            }
                          },
                        ),
                        const SizedBox(height: CxSpace.x2l),
                        if (allDone)
                          _ExerciseCompleteCard(
                            colors: c,
                            isLast: _exerciseIndex >= session.exercises.length - 1,
                            onNext: () {
                              if (_exerciseIndex < session.exercises.length - 1) {
                                setState(() => _exerciseIndex++);
                              } else {
                                _finishWorkout();
                              }
                            },
                            onAddSet: () {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .addSet(exLog.exerciseId);
                            },
                          )
                        else ...[
                          Text(
                            focusSet.isWarmup
                                ? 'WARM-UP SET'
                                : 'SET ${(focusSetIndex ?? 0) + 1} OF ${exLog.sets.length}',
                            textAlign: TextAlign.center,
                            style: CxType.overline.copyWith(
                              color: focusSet.isWarmup
                                  ? c.warning
                                  : c.ultraviolet,
                            ),
                          ),
                          const SizedBox(height: CxSpace.lg),
                          _GiantWeightStepper(
                            weightKg: focusSet.weight,
                            units: units,
                            colors: c,
                            onChanged: (kg) {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .updateSetWeight(
                                    exLog.exerciseId,
                                    focusSetIndex ?? 0,
                                    kg,
                                  );
                            },
                          ),
                          const SizedBox(height: CxSpace.x2l),
                          _GiantRepsStepper(
                            reps: focusSet.reps,
                            colors: c,
                            onChanged: (reps) {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .updateSetReps(
                                    exLog.exerciseId,
                                    focusSetIndex ?? 0,
                                    reps,
                                  );
                            },
                          ),
                          const SizedBox(height: CxSpace.x3l),
                          CxButton(
                            label: 'Log set',
                            expand: true,
                            size: CxButtonSize.large,
                            icon: Icons.check_rounded,
                            haptic: CxHaptic.logSet,
                            onPressed: () => _logCurrent(
                              exLog.exerciseId,
                              focusSetIndex ?? 0,
                            ),
                          ),
                          const SizedBox(height: CxSpace.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(activeWorkoutProvider.notifier)
                                      .toggleWarmup(
                                        exLog.exerciseId,
                                        focusSetIndex ?? 0,
                                      );
                                },
                                child: Text(
                                  focusSet.isWarmup
                                      ? 'Mark as working set'
                                      : 'Mark as warm-up',
                                  style: CxType.caption
                                      .copyWith(color: c.textSecondary),
                                ),
                              ),
                              Text('·',
                                  style: CxType.caption
                                      .copyWith(color: c.textTertiary)),
                              TextButton.icon(
                                onPressed: () => _showSetNoteSheet(
                                  exLog,
                                  focusSetIndex ?? 0,
                                ),
                                icon: Icon(
                                  focusSet.note == null
                                      ? Icons.sticky_note_2_outlined
                                      : Icons.sticky_note_2_rounded,
                                  size: 16,
                                  color: focusSet.note == null
                                      ? c.textSecondary
                                      : c.ultraviolet,
                                ),
                                label: Text(
                                  focusSet.note == null
                                      ? 'Add note'
                                      : 'Edit note',
                                  style: CxType.caption.copyWith(
                                    color: focusSet.note == null
                                        ? c.textSecondary
                                        : c.ultraviolet,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (focusSet.note != null) ...[
                            const SizedBox(height: CxSpace.xs),
                            Text(
                              '“${focusSet.note}”',
                              textAlign: TextAlign.center,
                              style: CxType.caption.copyWith(
                                color: c.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (resting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RestBar(
                exerciseName: notifier.restTimerExerciseName,
                remaining: notifier.restTimerSecondsRemaining,
                total: notifier.restTimerTotalSeconds,
                colors: c,
                onSkip: () =>
                    ref.read(activeWorkoutProvider.notifier).skipRestTimer(),
                onAdd30: () => ref
                    .read(activeWorkoutProvider.notifier)
                    .addTimeToRestTimer(30),
              ),
            ),
          if (prCelebration != null)
            _PrOverlay(
              info: prCelebration,
              colors: c,
              units: units,
              onDismiss: () =>
                  ref.read(prCelebrationProvider.notifier).clearCelebration(),
            ),
        ],
      ),
    );
  }

  int? _nextOpenSetIndex(ExerciseLog ex) {
    for (var i = 0; i < ex.sets.length; i++) {
      if (!ex.sets[i].completed) return i;
    }
    return null;
  }

  String? _previousPerformance(String name) {
    final history = ref.read(workoutHistoryProvider);
    for (final session in history.reversed) {
      for (final e in session.exercises) {
        if (e.exerciseName != name) continue;
        final working = e.sets.where((s) => s.completed && !s.isWarmup);
        if (working.isEmpty) continue;
        final best = working.reduce(
          (a, b) => a.weight >= b.weight ? a : b,
        );
        final units = ref.read(userProfileProvider).units;
        return 'Last: ${formatWeight(best.weight, units)} × ${best.reps}';
      }
    }
    return null;
  }

  void _logCurrent(String exerciseId, int setIndex) {
    _dismissRestAlert();
    ref.read(activeWorkoutProvider.notifier).logSet(exerciseId, setIndex);
  }

  /// Per-set note sheet: quick chips for the common cases, free text for the
  /// rest. Notes ride along in history and feed the coach real context.
  void _showSetNoteSheet(ExerciseLog exLog, int setIndex) {
    final c = context.cx;
    final controller =
        TextEditingController(text: exLog.sets[setIndex].note ?? '');
    const chips = [
      'Felt heavy',
      'Felt easy',
      'Form broke down',
      'Joint tweak',
      'Grip gave out',
      'Short on rest',
    ];

    void save(String text) {
      ref
          .read(activeWorkoutProvider.notifier)
          .setSetNote(exLog.exerciseId, setIndex, text);
      Navigator.pop(context);
    }

    showRqGlassBottomSheet(
      context: context,
      title: 'Set ${setIndex + 1} note',
      actionLabel: 'Save note',
      onActionPressed: () => save(controller.text),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CxSpace.sm,
            runSpacing: CxSpace.sm,
            children: [
              for (final chip in chips)
                GestureDetector(
                  onTap: () {
                    CxHaptics.fire(CxHaptic.selection);
                    save(chip);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: CxSpace.md, vertical: CxSpace.sm),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: CxRadii.brPill,
                      border: Border.all(color: c.border),
                    ),
                    child: Text(chip,
                        style:
                            CxType.caption.copyWith(color: c.textPrimary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          CxTextField(
            label: 'Or write your own',
            hint: 'e.g. left shoulder clicked on rep 6',
            controller: controller,
            onChanged: (_) {},
          ),
          if ((exLog.sets[setIndex].note ?? '').isNotEmpty) ...[
            const SizedBox(height: CxSpace.sm),
            Center(
              child: TextButton(
                onPressed: () => save(''),
                child: Text('Remove note',
                    style: CxType.caption.copyWith(color: c.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditCompletedSet(ExerciseLog exLog, int setIndex, String units) {
    final c = context.cx;
    final set = exLog.sets[setIndex];
    showRqGlassBottomSheet(
      context: context,
      title: set.isWarmup ? 'Warm-up set' : 'Set ${setIndex + 1}',
      actionLabel: set.completed ? 'Unlog set' : 'Log set',
      onActionPressed: () {
        ref
            .read(activeWorkoutProvider.notifier)
            .logSet(exLog.exerciseId, setIndex);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Text(
            '${formatWeight(set.weight, units)} × ${set.reps}',
            style: CxType.numL.copyWith(color: c.textPrimary),
          ),
          if (set.note != null) ...[
            const SizedBox(height: CxSpace.sm),
            Text(
              '“${set.note}”',
              textAlign: TextAlign.center,
              style: CxType.caption.copyWith(
                  color: c.textTertiary, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: CxSpace.sm),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSetNoteSheet(exLog, setIndex);
            },
            icon: Icon(Icons.sticky_note_2_outlined,
                size: 16, color: c.ultraviolet),
            label: Text(set.note == null ? 'Add note' : 'Edit note',
                style: CxType.caption.copyWith(color: c.ultraviolet)),
          ),
          const SizedBox(height: CxSpace.sm),
          Text(
            'Adjust with the steppers on the main screen after unlogging, or unlog to redo.',
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showExerciseActions(ExerciseLog exLog) {
    final c = context.cx;
    showRqGlassBottomSheet(
      context: context,
      title: exLog.exerciseName,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.menu_book_rounded,
            label: 'How to do this',
            colors: c,
            onTap: () {
              Navigator.pop(context);
              showExerciseGuideSheet(
                context,
                exerciseName: exLog.exerciseName,
                muscleGroup: exLog.muscleGroup,
              );
            },
          ),
          _ActionTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Swap exercise',
            colors: c,
            onTap: () {
              Navigator.pop(context);
              _showSwapPicker(exLog.exerciseId, exLog.muscleGroup);
            },
          ),
          _ActionTile(
            icon: Icons.add_rounded,
            label: 'Add set',
            colors: c,
            onTap: () {
              ref
                  .read(activeWorkoutProvider.notifier)
                  .addSet(exLog.exerciseId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final c = context.cx;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Cancel workout?',
            style: CxType.title.copyWith(color: c.textPrimary)),
        content: Text(
          'This deletes today’s session. Logged sets will be lost.',
          style: CxType.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep going',
                style: CxType.label.copyWith(color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(activeWorkoutProvider.notifier).cancelWorkout();
            },
            child: Text('Delete session',
                style: CxType.label.copyWith(color: c.danger)),
          ),
        ],
      ),
    );
  }

  void _finishWorkout() {
    _dismissRestAlert();
    final minutes = (_elapsedSeconds / 60).ceil().clamp(1, 999);
    final finalized = ref
        .read(activeWorkoutProvider.notifier)
        .finishWorkout(mockDurationMinutes: minutes);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(session: finalized),
      ),
    );
  }

  void _showSwapPicker(String oldExerciseId, String muscleGroup) {
    final c = context.cx;
    final options = [
      _PickerItem('Leg Press', 'Legs', 'Full gym', 120),
      _PickerItem('Dumbbell Goblet Squat', 'Legs', 'Dumbbells only', 24),
      _PickerItem('Barbell Front Squat', 'Legs', 'Full gym', 65),
      _PickerItem(
          'Incline Dumbbell Bench Press', 'Chest', 'Dumbbells only', 20),
      _PickerItem('Bent Over Barbell Row', 'Back', 'Full gym', 50),
      _PickerItem('Dumbbell Hammer Curl', 'Arms', 'Dumbbells only', 10),
      _PickerItem('Dumbbell Lunges', 'Legs', 'Dumbbells only', 16),
      _PickerItem('Seated Cable Row', 'Back', 'Full gym', 40),
    ].where((o) => o.muscleGroup == muscleGroup).toList();

    showRqGlassBottomSheet(
      context: context,
      title: 'Swap exercise',
      child: Column(
        children: [
          for (final o in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.name,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              subtitle: Text('${o.muscleGroup} · ${o.equipment}',
                  style: CxType.caption.copyWith(color: c.textSecondary)),
              trailing: Icon(Icons.chevron_right_rounded, color: c.textTertiary),
              onTap: () {
                CxHaptics.fire(CxHaptic.selection);
                ref.read(activeWorkoutProvider.notifier).swapExercise(
                      oldExerciseId,
                      Exercise(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: o.name,
                        muscleGroup: o.muscleGroup,
                        equipment: o.equipment,
                        targetSets: 3,
                        targetReps: '8-12',
                        suggestedWeight: o.suggestedWeight,
                      ),
                    );
                Navigator.pop(context);
              },
            ),
          if (options.isEmpty)
            Text(
              'No swaps for this muscle yet.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }

  String _formatClock(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Top bar — spacious, one primary action
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.elapsed,
    required this.doneSets,
    required this.totalSets,
    required this.colors,
    required this.onMinimize,
    required this.onFinish,
    required this.onCancel,
  });

  final String title;
  final String elapsed;
  final int doneSets;
  final int totalSets;
  final CxColorsExt colors;
  final VoidCallback onMinimize;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = totalSets == 0 ? 0.0 : doneSets / totalSets;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CxSpace.md,
        CxSpace.sm,
        CxSpace.md,
        CxSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Minimize',
                colors: colors,
                onTap: onMinimize,
              ),
              const Spacer(),
              Text(
                elapsed,
                style: CxType.numS.copyWith(
                  color: colors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              PopupMenuButton<String>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                offset: const Offset(0, 40),
                shape: const RoundedRectangleBorder(
                  borderRadius: CxRadii.brMd,
                ),
                color: colors.surface,
                icon: Icon(Icons.more_horiz_rounded,
                    color: colors.textSecondary),
                onSelected: (value) {
                  if (value == 'finish') onFinish();
                  if (value == 'cancel') onCancel();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'finish',
                    child: Text(
                      'Finish workout',
                      style: CxType.bodySmall.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancel workout',
                      style: CxType.bodySmall.copyWith(color: colors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Text(
            title,
            style: CxType.headline.copyWith(color: colors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: CxSpace.sm),
          Row(
            children: [
              Text(
                '$doneSets of $totalSets sets',
                style: CxType.caption.copyWith(color: colors.textTertiary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: CxType.caption.copyWith(
                  color: colors.textTertiary,
                  fontFamily: CxFonts.mono,
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          CxProgressBar(
            value: progress.clamp(0.0, 1.0),
            height: 3,
            accent: CxProgressAccent.ember,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final CxColorsExt colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: colors.textPrimary, size: 26),
          ),
        ),
      ),
    );
  }
}

class _RestCompleteBanner extends StatelessWidget {
  const _RestCompleteBanner({
    required this.colors,
    required this.onStop,
  });

  final CxColorsExt colors;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CxSpace.screen,
        0,
        CxSpace.screen,
        CxSpace.sm,
      ),
      child: Material(
        color: colors.ember.withValues(alpha: 0.12),
        borderRadius: CxRadii.brLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CxSpace.lg,
            vertical: CxSpace.md,
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: colors.ember, size: 22),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rest is over',
                      style: CxType.titleSmall.copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      'Time for the next set',
                      style: CxType.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onStop,
                style: TextButton.styleFrom(
                  foregroundColor: colors.ember,
                  padding: const EdgeInsets.symmetric(horizontal: CxSpace.md),
                ),
                child: Text(
                  'Stop',
                  style: CxType.label.copyWith(
                    color: colors.ember,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise rail
// ---------------------------------------------------------------------------

class _ExerciseRail extends StatelessWidget {
  const _ExerciseRail({
    required this.exercises,
    required this.currentIndex,
    required this.colors,
    required this.onSelect,
  });

  final List<ExerciseLog> exercises;
  final int currentIndex;
  final CxColorsExt colors;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: CxSpace.screen),
        itemCount: exercises.length,
        separatorBuilder: (context, index) => const SizedBox(width: CxSpace.sm),
        itemBuilder: (context, i) {
          final ex = exercises[i];
          final done = ex.sets.every((s) => s.completed);
          final selected = i == currentIndex;
          return GestureDetector(
            onTap: () {
              CxHaptics.fire(CxHaptic.selection);
              onSelect(i);
            },
            child: AnimatedContainer(
              duration: CxDuration.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: CxSpace.lg,
                vertical: CxSpace.sm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? colors.ember.withValues(alpha: 0.14)
                    : colors.surface,
                borderRadius: CxRadii.brPill,
                border: Border.all(
                  color: selected ? colors.ember : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) ...[
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: colors.success),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    ex.exerciseName,
                    style: CxType.label.copyWith(
                      color: selected ? colors.ember : colors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise header
// ---------------------------------------------------------------------------

class _ExerciseHeader extends StatelessWidget {
  const _ExerciseHeader({
    required this.exLog,
    required this.previous,
    required this.colors,
    required this.onGuide,
    required this.onMore,
  });

  final ExerciseLog exLog;
  final String? previous;
  final CxColorsExt colors;
  final VoidCallback onGuide;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onGuide,
                child: Text(
                  exLog.exerciseName,
                  style: CxType.headline.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            IconButton(
              onPressed: onMore,
              icon: Icon(Icons.more_horiz_rounded, color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.sm),
        Wrap(
          spacing: CxSpace.sm,
          runSpacing: CxSpace.sm,
          children: [
            _Pill(
              label:
                  'Target ${exLog.sets.where((s) => !s.isWarmup).length} × ${exLog.targetReps.isEmpty ? '—' : exLog.targetReps}',
              color: colors.ultraviolet,
            ),
            if (previous != null)
              _Pill(label: previous!, color: colors.textTertiary, muted: true),
          ],
        ),
        if (exLog.progressionReason != null) ...[
          const SizedBox(height: CxSpace.md),
          Text(
            exLog.progressionReason!,
            style: CxType.caption.copyWith(color: colors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.muted = false,
  });

  final String label;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpace.md,
        vertical: CxSpace.xs,
      ),
      decoration: BoxDecoration(
        color: muted
            ? context.cx.surfaceHigh
            : color.withValues(alpha: 0.14),
        borderRadius: CxRadii.brPill,
      ),
      child: Text(
        label,
        style: CxType.caption.copyWith(
          color: muted ? context.cx.textSecondary : color,
          fontWeight: FontWeight.w600,
          fontFamily: muted ? CxFonts.mono : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set dots
// ---------------------------------------------------------------------------

class _SetDots extends StatelessWidget {
  const _SetDots({
    required this.sets,
    required this.focusIndex,
    required this.colors,
    required this.onTap,
  });

  final List<SetLog> sets;
  final int? focusIndex;
  final CxColorsExt colors;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < sets.length; i++) ...[
          if (i > 0) const SizedBox(width: CxSpace.sm),
          GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: CxDuration.fast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sets[i].completed
                    ? colors.success.withValues(alpha: 0.18)
                    : (focusIndex == i
                        ? colors.ember.withValues(alpha: 0.16)
                        : colors.surfaceHigh),
                border: Border.all(
                  color: sets[i].completed
                      ? colors.success
                      : (focusIndex == i ? colors.ember : colors.border),
                  width: focusIndex == i ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: sets[i].completed
                  ? Icon(Icons.check_rounded, size: 18, color: colors.success)
                  : Text(
                      sets[i].isWarmup ? 'W' : '${i + 1}',
                      style: CxType.label.copyWith(
                        color: focusIndex == i
                            ? colors.ember
                            : colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Giant steppers
// ---------------------------------------------------------------------------

class _GiantWeightStepper extends StatelessWidget {
  const _GiantWeightStepper({
    required this.weightKg,
    required this.units,
    required this.colors,
    required this.onChanged,
  });

  final double weightKg;
  final String units;
  final CxColorsExt colors;
  final ValueChanged<double> onChanged;

  double get _step => units == 'lbs' ? 2.5 * 0.45359237 : 2.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'WEIGHT',
          style: CxType.overline.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            _RoundStepButton(
              icon: Icons.remove_rounded,
              colors: colors,
              onTap: () => onChanged((weightKg - _step).clamp(0, 9999)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    formatWeightValue(weightKg, units),
                    style: CxType.numHero.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    unitLabel(units),
                    style: CxType.label.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            _RoundStepButton(
              icon: Icons.add_rounded,
              colors: colors,
              onTap: () => onChanged((weightKg + _step).clamp(0, 9999)),
            ),
          ],
        ),
      ],
    );
  }
}

class _GiantRepsStepper extends StatelessWidget {
  const _GiantRepsStepper({
    required this.reps,
    required this.colors,
    required this.onChanged,
  });

  final int reps;
  final CxColorsExt colors;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'REPS',
          style: CxType.overline.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            _RoundStepButton(
              icon: Icons.remove_rounded,
              colors: colors,
              onTap: () => onChanged((reps - 1).clamp(1, 999)),
            ),
            Expanded(
              child: Text(
                '$reps',
                style: CxType.numXL.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            _RoundStepButton(
              icon: Icons.add_rounded,
              colors: colors,
              onTap: () => onChanged((reps + 1).clamp(1, 999)),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final CxColorsExt colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          CxHaptics.fire(CxHaptic.selection);
          onTap();
        },
        child: SizedBox(
          width: CxSpace.x5l,
          height: CxSpace.x5l,
          child: Icon(icon, color: colors.textPrimary, size: 28),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise complete
// ---------------------------------------------------------------------------

class _ExerciseCompleteCard extends StatelessWidget {
  const _ExerciseCompleteCard({
    required this.colors,
    required this.isLast,
    required this.onNext,
    required this.onAddSet,
  });

  final CxColorsExt colors;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    return CxCard(
      elevated: true,
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.success, size: 48),
          const SizedBox(height: CxSpace.md),
          Text(
            'Exercise done',
            style: CxType.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: CxSpace.xs),
          Text(
            isLast
                ? 'That’s the last movement. Finish when you’re ready.'
                : 'Nice work — move to the next exercise.',
            style: CxType.bodySmall.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CxSpace.xl),
          CxButton(
            label: isLast ? 'Finish workout' : 'Next exercise',
            expand: true,
            size: CxButtonSize.large,
            onPressed: onNext,
          ),
          const SizedBox(height: CxSpace.sm),
          TextButton(
            onPressed: onAddSet,
            child: Text(
              'Add another set',
              style: CxType.caption.copyWith(color: colors.ultraviolet),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest bar
// ---------------------------------------------------------------------------

class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.exerciseName,
    required this.remaining,
    required this.total,
    required this.colors,
    required this.onSkip,
    required this.onAdd30,
  });

  final String exerciseName;
  final int remaining;
  final int total;
  final CxColorsExt colors;
  final VoidCallback onSkip;
  final VoidCallback onAdd30;

  @override
  Widget build(BuildContext context) {
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final progress = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          CxSpace.screen,
          0,
          CxSpace.screen,
          CxSpace.md,
        ),
        padding: const EdgeInsets.all(CxSpace.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: CxRadii.brXl,
          border: Border.all(color: colors.border),
          boxShadow: CxShadows.floating,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REST',
                        style:
                            CxType.overline.copyWith(color: colors.ultraviolet),
                      ),
                      Text(
                        exerciseName,
                        style: CxType.titleSmall
                            .copyWith(color: colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$mins:${secs.toString().padLeft(2, '0')}',
                  style: CxType.timer.copyWith(color: colors.ember),
                ),
              ],
            ),
            const SizedBox(height: CxSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colors.surfaceHighest,
                color: colors.ember,
              ),
            ),
            const SizedBox(height: CxSpace.md),
            Row(
              children: [
                Expanded(
                  child: CxButton(
                    label: '+30s',
                    variant: CxButtonVariant.secondary,
                    onPressed: onAdd30,
                  ),
                ),
                const SizedBox(width: CxSpace.md),
                Expanded(
                  child: CxButton(
                    label: 'Skip rest',
                    onPressed: onSkip,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR overlay
// ---------------------------------------------------------------------------

class _PrOverlay extends StatelessWidget {
  const _PrOverlay({
    required this.info,
    required this.colors,
    required this.units,
    required this.onDismiss,
  });

  final PRCelebrationInfo info;
  final CxColorsExt colors;
  final String units;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars_rounded, color: colors.warning, size: 72),
                const SizedBox(height: CxSpace.xl),
                Text(
                  'NEW PR',
                  style: CxType.overline.copyWith(color: colors.ember),
                ),
                const SizedBox(height: CxSpace.md),
                Text(
                  formatWeight(info.weight, units),
                  style: CxType.numHero.copyWith(color: Colors.white),
                ),
                Text(
                  '× ${info.reps}',
                  style: CxType.title.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: CxSpace.x2l),
                Text(
                  info.exerciseName,
                  style: CxType.headline.copyWith(color: colors.ultraviolet),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CxSpace.x4l),
                Text(
                  'Tap to continue',
                  style: CxType.caption.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final CxColorsExt colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.ember),
      title: Text(label,
          style: CxType.titleSmall.copyWith(color: colors.textPrimary)),
      onTap: onTap,
    );
  }
}

class _PickerItem {
  const _PickerItem(
    this.name,
    this.muscleGroup,
    this.equipment,
    this.suggestedWeight,
  );

  final String name;
  final String muscleGroup;
  final String equipment;
  final double suggestedWeight;
}
