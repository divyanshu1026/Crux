import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/placeholder_screen.dart';
import '../../../app/router.dart';
import '../../../core/domain/gamification.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../exercise_guide/presentation/exercise_guide_sheet.dart';
import '../../workout/presentation/active_workout_screen.dart';

/// Today home — one job: get the user into (or back into) today's session.
///
/// Design intent:
/// - Hero: unfinished workout (Zeigarnik) OR today's plan card
/// - Quiet: greeting, XP/streak, week strip, quest
/// - Moves: progress fills only — no decoration animation
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static const _weekdays = Program.weekdays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider);
    if (program == null) {
      final l10n = AppL10n.of(context);
      return PlaceholderScreen(
        title: l10n.todayTitle,
        message: l10n.todayPlaceholder,
        icon: Icons.bolt_rounded,
        accent: CxColors.ember,
        yorhartExpression: 'resting',
      );
    }

    final c = context.cx;
    final profile = ref.watch(userProfileProvider);
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final quests = ref.watch(questProvider);
    ref.watch(hydrationProvider);

    // Daily streak guard (idempotent — runs once per calendar day).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = ref
          .read(userProfileProvider.notifier)
          .runDailyStreakCheck(ref.read(workoutHistoryProvider));
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });
    final history = ref.watch(workoutHistoryProvider);

    // Single instant for the whole build — otherwise a build that straddles
    // midnight could mix two days. Injectable so tests can pin it.
    final now = ref.watch(clockProvider)();

    final weekdayStr = _weekdayAbbr(now.weekday);
    final todayWorkout = program.dayForWeekday(
      weekdayStr,
      fallbackDays: profile.daysPerWeek,
    );
    final isTrainingDay = todayWorkout != null;
    final hasOpenLoop = activeWorkout != null;

    final nextQuest = quests.cast<Quest?>().firstWhere(
          (q) => q != null && !q.isClaimed,
          orElse: () => quests.isEmpty ? null : quests.first,
        );

    final trainedWeekdays = _trainedWeekdaysThisWeek(history, now);

    // Missed-day catch-up: if a planned day earlier this week went unlogged
    // and today is open (a rest day, no workout in progress), offer to run
    // that session today — the week can still be completed. Dismissible per
    // day, gone entirely once the week's target is hit.
    final assignedWeekdays = program.dayAssignments.isNotEmpty
        ? program.dayAssignments.keys.toSet()
        : profile.daysPerWeek.toSet();
    final weekProgress = computeWeekProgress(
      now: now,
      assignedWeekdays: assignedWeekdays,
      completedWorkoutDates:
          history.where((s) => s.completed).map((s) => s.date).toList(),
    );
    final dismissedKey = ref.watch(missedDayDismissalProvider);
    final dismissedToday =
        dismissedKey == '${now.year}-${now.month}-${now.day}';
    WorkoutDay? catchUpDay;
    String? catchUpWeekday;
    if (!isTrainingDay &&
        !hasOpenLoop &&
        !weekProgress.isComplete &&
        weekProgress.missedWeekdays.isNotEmpty &&
        !dismissedToday) {
      catchUpWeekday = weekProgress.missedWeekdays.first;
      catchUpDay = program.dayForWeekday(catchUpWeekday,
          fallbackDays: profile.daysPerWeek);
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.ember,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              CxSpace.screen,
              CxSpace.md,
              CxSpace.screen,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(profile: profile, colors: c, now: now),
                const SizedBox(height: CxSpace.x2l),

                // Open loop first — unfinished work beats the plan card.
                if (hasOpenLoop) ...[
                  _ResumeHero(
                    session: activeWorkout,
                    colors: c,
                    onResume: () => _openActiveWorkout(context),
                  ),
                  const SizedBox(height: CxSpace.xl),
                ],

                _WeekStrip(
                  program: program,
                  profile: profile,
                  today: weekdayStr,
                  trained: trainedWeekdays,
                  colors: c,
                  onOpenSchedule: () => context.push(Routes.schedule),
                ),
                const SizedBox(height: CxSpace.xl),

                if (isTrainingDay)
                  _TrainingPlanCard(
                    day: todayWorkout,
                    hasOpenLoop: hasOpenLoop,
                    onStart: () {
                      ref
                          .read(activeWorkoutProvider.notifier)
                          .startWorkout(todayWorkout, program.id, {});
                      _openActiveWorkout(context);
                    },
                    onExerciseInfo: (ex) => showExerciseGuideSheet(
                      context,
                      exerciseName: ex.name,
                      muscleGroup: ex.muscleGroup,
                      equipment: ex.equipment,
                    ),
                  )
                else if (catchUpDay != null)
                  _CatchUpCard(
                    missedWeekday: catchUpWeekday!,
                    day: catchUpDay,
                    onStart: () {
                      // Dated today — they're genuinely training now, not
                      // backfilling a forgotten log.
                      ref
                          .read(activeWorkoutProvider.notifier)
                          .startWorkout(catchUpDay!, program.id, {});
                      _openActiveWorkout(context);
                    },
                    onDismiss: () => ref
                        .read(missedDayDismissalProvider.notifier)
                        .dismissForToday(),
                  )
                else
                  _RestDayCard(
                    onTrainAnyway: () => _showTrainAnywayPicker(
                      program,
                      context,
                      ref,
                    ),
                  ),

                const SizedBox(height: CxSpace.xl),
                // Hydration — visible in Zen mode too (tracking, not a game).
                _HydrationCard(
                  todayMl: ref.read(hydrationProvider.notifier).todayMl,
                  goalMl: ref.read(hydrationProvider.notifier).goalMl,
                  colors: c,
                  onLog: (ml) =>
                      ref.read(hydrationProvider.notifier).log(ml, ref: ref),
                ),

                if (!profile.zenMode && nextQuest != null) ...[
                  const SizedBox(height: CxSpace.x2l),
                  _QuestTeaser(
                    quest: nextQuest,
                    colors: c,
                    onClaim: () {
                      ref
                          .read(questProvider.notifier)
                          .claimQuest(nextQuest.id, ref: ref);
                    },
                    onOpenCoach: () => context.go(Routes.coach),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Set<String> _trainedWeekdaysThisWeek(
      List<WorkoutSession> history, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final trained = <String>{};
    for (final s in history) {
      if (!s.completed) continue;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (d.isBefore(monday)) continue;
      trained.add(_weekdayAbbr(d.weekday));
    }
    return trained;
  }

  static String _weekdayAbbr(int weekday) {
    const map = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return map[weekday - 1];
  }

  static void _showTrainAnywayPicker(
    Program program,
    BuildContext context,
    WidgetRef ref,
  ) {
    final c = context.cx;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return CxGlassBottomSheet(
          title: 'Pick a session',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in program.days) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.ember.withValues(alpha: 0.12),
                      borderRadius: CxRadii.brMd,
                    ),
                    child: Icon(Icons.fitness_center_rounded,
                        color: c.ember, size: 22),
                  ),
                  title: Text(
                    day.name,
                    style: CxType.titleSmall.copyWith(color: c.textPrimary),
                  ),
                  subtitle: Text(
                    '${day.exercises.length} exercises · ~${_estimateMinutes(day)} min',
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: c.textTertiary),
                  onTap: () {
                    CxHaptics.fire(CxHaptic.selection);
                    ref
                        .read(activeWorkoutProvider.notifier)
                        .startWorkout(day, program.id, {});
                    Navigator.pop(context);
                    _openActiveWorkout(context);
                  },
                ),
                Divider(color: c.border, height: 1),
              ],
            ],
          ),
        );
      },
    );
  }

  static int _estimateMinutes(WorkoutDay day) {
    // Rough: ~3 min per set + rest buffer.
    final sets = day.exercises.fold<int>(0, (n, e) => n + e.targetSets);
    return (sets * 2.5).round().clamp(25, 90);
  }

  static void _openActiveWorkout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveWorkoutScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.colors,
    required this.now,
  });

  final UserProfile profile;
  final CxColorsExt colors;
  final DateTime now;

  String get _greeting {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Saturday · 22 Aug". Which day it is decides which session is due, so it
  /// belongs on the screen that tells you what to train — not only in the
  /// week strip's single letter.
  String get _dateLine =>
      '${_dayNames[now.weekday - 1]} · ${now.day} ${_monthNames[now.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final name =
        profile.firstName.isEmpty ? 'there' : profile.firstName;

    if (profile.zenMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting · $_dateLine',
            style: CxType.overline.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            'Hello, $name',
            style: CxType.headline.copyWith(color: colors.textPrimary),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting.toUpperCase(),
                    style: CxType.overline.copyWith(color: colors.ultraviolet),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateLine,
                    style: CxType.caption.copyWith(color: colors.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: CxType.displayL.copyWith(color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: CxSpace.md),
            _StreakPill(streak: profile.streak, colors: colors),
          ],
        ),
        const SizedBox(height: CxSpace.lg),
        _XpRow(profile: profile, colors: colors),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak, required this.colors});

  final int streak;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpace.md,
        vertical: CxSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CxRadii.brPill,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: colors.ember, size: 20),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: CxType.numS.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  const _XpRow({required this.profile, required this.colors});

  final UserProfile profile;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level ${profile.level}',
              style: CxType.label.copyWith(color: colors.textSecondary),
            ),
            const Spacer(),
            Text(
              '${profile.xp} / ${profile.nextLevelXpThreshold} XP',
              style: CxType.caption.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.sm),
        CxProgressBar(
          value: profile.xpProgress,
          height: 8,
          accent: CxProgressAccent.ultraviolet,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resume hero (open loop)
// ---------------------------------------------------------------------------

class _ResumeHero extends StatelessWidget {
  const _ResumeHero({
    required this.session,
    required this.colors,
    required this.onResume,
  });

  final WorkoutSession session;
  final CxColorsExt colors;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final totalSets = session.exercises.fold<int>(
      0,
      (n, e) => n + e.sets.length,
    );
    final loggedSets = session.exercises.fold<int>(
      0,
      (n, e) => n + e.sets.where((s) => s.completed).length,
    );
    final progress = totalSets == 0 ? 0.0 : (loggedSets / totalSets).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onResume,
        borderRadius: CxRadii.brXl,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: CxRadii.brXl,
            border: Border.all(color: colors.ember.withValues(alpha: 0.45)),
            boxShadow: CxShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(CxSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.ember.withValues(alpha: 0.14),
                        borderRadius: CxRadii.brMd,
                      ),
                      child: Icon(Icons.bolt_rounded,
                          color: colors.ember, size: 24),
                    ),
                    const SizedBox(width: CxSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PICK UP WHERE YOU LEFT OFF',
                            style: CxType.overline
                                .copyWith(color: colors.ember),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.workoutDayName,
                            style: CxType.title
                                .copyWith(color: colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (totalSets > 0) ...[
                  const SizedBox(height: CxSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: CxProgressBar(
                          value: progress,
                          height: 8,
                          accent: CxProgressAccent.ember,
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Text(
                        '$loggedSets / $totalSets sets',
                        style: CxType.caption
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: CxSpace.lg),
                CxButton(
                  label: 'Resume workout',
                  expand: true,
                  icon: Icons.play_arrow_rounded,
                  haptic: CxHaptic.selection,
                  onPressed: onResume,
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
// Week strip
// ---------------------------------------------------------------------------

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.program,
    required this.profile,
    required this.today,
    required this.trained,
    required this.colors,
    required this.onOpenSchedule,
  });

  final Program program;
  final UserProfile profile;
  final String today;
  final Set<String> trained;
  final CxColorsExt colors;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'This week',
              style: CxType.titleSmall.copyWith(color: colors.textPrimary),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onOpenSchedule,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    'Edit schedule',
                    style: CxType.caption.copyWith(color: colors.ultraviolet),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.ultraviolet),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            for (final day in TodayScreen._weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayDot(
                    label: day.substring(0, 1),
                    isToday: day == today,
                    isTraining: program.dayForWeekday(
                          day,
                          fallbackDays: profile.daysPerWeek,
                        ) !=
                        null,
                    isDone: trained.contains(day),
                    colors: colors,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.isToday,
    required this.isTraining,
    required this.isDone,
    required this.colors,
  });

  final String label;
  final bool isToday;
  final bool isTraining;
  final bool isDone;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isToday) {
      bg = colors.ember;
      fg = colors.onEmber;
    } else if (isDone) {
      bg = colors.ultraviolet.withValues(alpha: 0.18);
      fg = colors.ultraviolet;
    } else if (isTraining) {
      bg = colors.surfaceHigh;
      fg = colors.textPrimary;
    } else {
      bg = colors.surface;
      fg = colors.textTertiary;
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: CxDuration.fast,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CxRadii.brMd,
            border: isToday || isDone
                ? null
                : Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: isDone && !isToday
              ? Icon(Icons.check_rounded, size: 18, color: fg)
              : Text(
                  label,
                  style: CxType.label.copyWith(
                    color: fg,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTraining
                ? (isToday ? colors.ember : colors.textTertiary)
                : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Training plan
// ---------------------------------------------------------------------------

class _TrainingPlanCard extends StatelessWidget {
  const _TrainingPlanCard({
    required this.day,
    required this.hasOpenLoop,
    required this.onStart,
    required this.onExerciseInfo,
  });

  final WorkoutDay day;
  final bool hasOpenLoop;
  final VoidCallback onStart;
  final ValueChanged<Exercise> onExerciseInfo;

  @override
  Widget build(BuildContext context) {
    final minutes = TodayScreen._estimateMinutes(day);
    final preview = day.exercises.take(4).toList();
    final remaining = day.exercises.length - preview.length;

    return CxPastelCard(
      tint: CxPastelTint.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "TODAY'S PLAN",
                style: CxType.overline
                    .copyWith(color: cxPastelInk(opacity: 0.7)),
              ),
              const Spacer(),
              const CxTag(
                label: 'Training',
                icon: Icons.fitness_center_rounded,
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Text(
            day.name,
            style: CxType.displayL.copyWith(
              color: cxPastelInk(),
              height: 1.1,
            ),
          ),
          const SizedBox(height: CxSpace.sm),
          Row(
            children: [
              _MetaChip(
                icon: Icons.list_alt_rounded,
                label: '${day.exercises.length} exercises',
              ),
              const SizedBox(width: CxSpace.sm),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: '~$minutes min',
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xl),
          for (var i = 0; i < preview.length; i++) ...[
            if (i > 0) const SizedBox(height: CxSpace.sm),
            _ExerciseRow(
              exercise: preview[i],
              index: i + 1,
              onInfo: () => onExerciseInfo(preview[i]),
            ),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: CxSpace.md),
            Text(
              '+ $remaining more in session',
              style: CxType.caption.copyWith(
                color: cxPastelInk(opacity: 0.55),
              ),
            ),
          ],
          const SizedBox(height: CxSpace.x2l),
          if (hasOpenLoop)
            CxButton(
              label: 'Start this instead',
              expand: true,
              variant: CxButtonVariant.secondary,
              haptic: CxHaptic.selection,
              onPressed: onStart,
            )
          else
            CxButton(
              label: 'Start workout',
              expand: true,
              size: CxButtonSize.large,
              icon: Icons.play_arrow_rounded,
              haptic: CxHaptic.selection,
              onPressed: onStart,
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpace.md,
        vertical: CxSpace.xs,
      ),
      decoration: BoxDecoration(
        color: CxColors.pastelInk.withValues(alpha: 0.08),
        borderRadius: CxRadii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cxPastelInk(opacity: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.index,
    required this.onInfo,
  });

  final Exercise exercise;
  final int index;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: CxRadii.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$index'.padLeft(2, '0'),
                  style: CxType.numS.copyWith(
                    color: cxPastelInk(opacity: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  exercise.name,
                  style: CxType.titleSmall.copyWith(color: cxPastelInk()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${exercise.targetSets}×${exercise.targetReps}',
                style: CxType.label.copyWith(
                  color: cxPastelInk(opacity: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: CxSpace.xs),
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: cxPastelInk(opacity: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Missed-day catch-up (rest day, but a planned session went unlogged)
// ---------------------------------------------------------------------------

class _CatchUpCard extends StatelessWidget {
  const _CatchUpCard({
    required this.missedWeekday,
    required this.day,
    required this.onStart,
    required this.onDismiss,
  });

  final String missedWeekday;
  final WorkoutDay day;
  final VoidCallback onStart;
  final VoidCallback onDismiss;

  static const _fullNames = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
    'Sun': 'Sunday',
  };

  @override
  Widget build(BuildContext context) {
    final dayName = _fullNames[missedWeekday] ?? missedWeekday;
    return CxPastelCard(
      tint: CxPastelTint.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CATCH-UP DAY',
                style:
                    CxType.overline.copyWith(color: cxPastelInk(opacity: 0.7)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  CxHaptics.fire(CxHaptic.selection);
                  onDismiss();
                },
                child: Icon(Icons.close_rounded,
                    size: 20, color: cxPastelInk(opacity: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The week isn\'t\nover yet.',
                      style: CxType.displayL.copyWith(
                        color: cxPastelInk(),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: CxSpace.md),
                    Text(
                      'Life happened on $dayName — no problem. Today is open: '
                      'run ${day.name} now and this week still counts as complete.',
                      style: CxType.bodySmall
                          .copyWith(color: cxPastelInk(opacity: 0.75)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CxSpace.md),
              const YorhartWidget(expression: 'determined', size: 88),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          Text(
            '${day.exercises.length} exercises · ${day.exercises.take(3).map((e) => e.name).join(' · ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.6)),
          ),
          const SizedBox(height: CxSpace.lg),
          CxButton(
            label: 'Do it today',
            expand: true,
            size: CxButtonSize.large,
            icon: Icons.play_arrow_rounded,
            haptic: CxHaptic.selection,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest day
// ---------------------------------------------------------------------------

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({
    required this.onTrainAnyway,
  });

  final VoidCallback onTrainAnyway;

  @override
  Widget build(BuildContext context) {
    return CxPastelCard(
      tint: CxPastelTint.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RECOVERY',
                style: CxType.overline
                    .copyWith(color: cxPastelInk(opacity: 0.7)),
              ),
              const Spacer(),
              const CxTag(
                label: 'Rest day',
                icon: Icons.spa_rounded,
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You train now —\nby resting.',
                      style: CxType.displayL.copyWith(
                        color: cxPastelInk(),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: CxSpace.md),
                    Text(
                      'Sleep, walk, eat. Growth happens between sessions.',
                      style: CxType.bodySmall
                          .copyWith(color: cxPastelInk(opacity: 0.75)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CxSpace.md),
              const YorhartWidget(expression: 'resting', size: 88),
            ],
          ),
          const SizedBox(height: CxSpace.x2l),
          SizedBox(
            width: double.infinity,
            height: CxSpace.minTap,
            child: OutlinedButton(
              onPressed: () {
                CxHaptics.fire(CxHaptic.selection);
                onTrainAnyway();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: cxPastelInk(),
                side: BorderSide(
                  color: CxColors.pastelInk.withValues(alpha: 0.25),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: CxRadii.brLg,
                ),
              ),
              child: Text(
                'Train anyway',
                style: CxType.label.copyWith(
                  color: cxPastelInk(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hydration
// ---------------------------------------------------------------------------

class _HydrationCard extends StatelessWidget {
  const _HydrationCard({
    required this.todayMl,
    required this.goalMl,
    required this.colors,
    required this.onLog,
  });

  final int todayMl;
  final int goalMl;
  final CxColorsExt colors;
  final ValueChanged<int> onLog;

  @override
  Widget build(BuildContext context) {
    final progress = goalMl == 0 ? 0.0 : (todayMl / goalMl).clamp(0.0, 1.0);
    final goalHit = todayMl >= goalMl;

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded,
                  color: colors.ultraviolet, size: 20),
              const SizedBox(width: CxSpace.sm),
              Text(
                'HYDRATION',
                style: CxType.overline.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              if (goalHit)
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: colors.success, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Goal hit',
                      style: CxType.caption.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtMl(todayMl),
                style: CxType.numL.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / ${_fmtMl(goalMl)}',
                style: CxType.bodySmall.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          CxProgressBar(
            value: progress,
            height: 8,
            accent: CxProgressAccent.ultraviolet,
          ),
          const SizedBox(height: CxSpace.lg),
          Row(
            children: [
              Expanded(
                child: CxButton(
                  label: '+250 ml',
                  variant: CxButtonVariant.secondary,
                  haptic: CxHaptic.selection,
                  onPressed: () => onLog(250),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: CxButton(
                  label: '+500 ml',
                  variant: CxButtonVariant.secondary,
                  haptic: CxHaptic.selection,
                  onPressed: () => onLog(500),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              IconButton(
                tooltip: 'Undo 250 ml',
                onPressed: todayMl > 0 ? () => onLog(-250) : null,
                icon: Icon(
                  Icons.undo_rounded,
                  color:
                      todayMl > 0 ? colors.textSecondary : colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtMl(int ml) => ml >= 1000
      ? '${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1)} L'
      : '$ml ml';
}

// ---------------------------------------------------------------------------
// Quest teaser
// ---------------------------------------------------------------------------

class _QuestTeaser extends StatelessWidget {
  const _QuestTeaser({
    required this.quest,
    required this.colors,
    required this.onClaim,
    required this.onOpenCoach,
  });

  final Quest quest;
  final CxColorsExt colors;
  final VoidCallback onClaim;
  final VoidCallback onOpenCoach;

  @override
  Widget build(BuildContext context) {
    final progress =
        (quest.currentValue / quest.targetValue).clamp(0.0, 1.0);
    final accent = quest.isMilestone ? colors.ember : colors.ultraviolet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Next quest',
              style: CxType.titleSmall.copyWith(color: colors.textPrimary),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onOpenCoach,
              child: Text(
                'All quests',
                style: CxType.caption.copyWith(color: colors.ultraviolet),
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        CxCard(
          onTap: onOpenCoach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CxSpace.md,
                      vertical: CxSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: CxRadii.brPill,
                    ),
                    child: Text(
                      quest.isMilestone ? 'Milestone' : 'Weekly',
                      style: CxType.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.auto_awesome_rounded,
                      color: colors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+${quest.xpReward} XP',
                    style: CxType.label.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CxSpace.md),
              Text(
                quest.title,
                style: CxType.titleSmall.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                quest.description,
                style: CxType.caption.copyWith(color: colors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: CxSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: CxProgressBar(
                      value: progress,
                      height: 8,
                      accent: quest.isMilestone
                          ? CxProgressAccent.ember
                          : CxProgressAccent.ultraviolet,
                    ),
                  ),
                  const SizedBox(width: CxSpace.md),
                  Text(
                    '${quest.currentValue}/${quest.targetValue}',
                    style: CxType.numS.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (quest.isCompleted && !quest.isClaimed) ...[
                const SizedBox(height: CxSpace.lg),
                CxButton(
                  label: 'Claim reward',
                  expand: true,
                  haptic: CxHaptic.success,
                  onPressed: onClaim,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
