import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/program_templates.dart';
import '../../../core/data/saved_schedules.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../exercise_guide/presentation/exercise_guide_sheet.dart';
import '../../workout/presentation/active_workout_screen.dart';
import 'day_detail_screen.dart';
import 'program_guide.dart';
import 'schedule_chat_sheet.dart';

/// Weekly schedule — one glance at the whole week (plan §5 "commitment &
/// consistency": the app holds the user to *their own* plan). Design intent:
/// the seven day rows are the hero; editing is one tap; rest days are framed
/// as recovery, never as gaps.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final program = ref.watch(programProvider);
    final profile = ref.watch(userProfileProvider);

    if (program == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(title: const Text('Weekly schedule')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(CxSpace.x2l),
            child: Text(
              'Finish onboarding to generate your program — your weekly schedule appears here.',
              textAlign: TextAlign.center,
              style: CxType.body.copyWith(color: c.textSecondary),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final todayAbbrev = Program.weekdays[now.weekday - 1];

    // Which days of *this* week already have a completed log — drives the
    // "missed a day? log it now" backfill affordance.
    final history = ref.watch(workoutHistoryProvider);
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final loggedThisWeek = <String>{};
    for (final s in history) {
      if (!s.completed) continue;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (!d.isBefore(monday) && d.difference(monday).inDays < 7) {
        loggedThisWeek.add(Program.weekdays[d.weekday - 1]);
      }
    }

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: const Text('Weekly schedule'),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded,
                color: c.textSecondary),
            tooltip: 'Ask Coach to change it',
            onPressed: () => showScheduleAssistantSheet(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.library_books_rounded, color: c.textSecondary),
            tooltip: 'Plan library',
            onPressed: () => _showTemplates(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CxSpace.screen, CxSpace.sm, CxSpace.screen, 48),
        children: [
          Text(
            'Tap a day to open and edit its workout, or use the swap icon to change which workout runs that day.',
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.lg),

          // Coach is the primary way to change the plan, so it gets the one
          // prominent card. The old "balance my week" banner sat above this
          // doing a narrower version of the same job — asking Coach to even out
          // the week covers it, and it stated a day count that was wrong
          // whenever the schedule was in a bad state.
          CxPastelCard(
            tint: CxPastelTint.lilac,
            padding: const EdgeInsets.all(CxSpace.lg),
            onTap: () => showScheduleAssistantSheet(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const YorhartWidget(expression: 'coaching', size: 48),
                    const SizedBox(width: CxSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change my schedule',
                              style: CxType.titleSmall
                                  .copyWith(color: cxPastelInk())),
                          Text(
                            'Tell Coach what you want different. You review '
                            'every change before it happens.',
                            style: CxType.caption
                                .copyWith(color: cxPastelInk(opacity: 0.72)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: cxPastelInk()),
                  ],
                ),
                const SizedBox(height: CxSpace.md),
                Wrap(
                  spacing: CxSpace.sm,
                  runSpacing: CxSpace.sm,
                  children: [
                    for (final prompt in const [
                      'Even out my week',
                      'More glute work',
                      'I can only train 3 days',
                      'My shoulder hurts',
                    ])
                      _CoachPromptChip(
                        label: prompt,
                        onTap: () => showScheduleAssistantSheet(
                          context,
                          ref,
                          initialRequest: prompt,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpace.xl),

          for (final weekday in Program.weekdays) ...[
            Builder(builder: (context) {
              final day = program.dayForWeekday(weekday,
                  fallbackDays: profile.daysPerWeek);
              final dayIndex = Program.weekdays.indexOf(weekday);
              final isPast = dayIndex < now.weekday - 1;
              final missedLog =
                  isPast && day != null && !loggedThisWeek.contains(weekday);
              return _DayRow(
                weekday: weekday,
                isToday: weekday == todayAbbrev,
                day: day,
                onReassign: () => showDayAssignmentPicker(context, ref, weekday),
                onBackfill: missedLog
                    ? () => _backfillDay(
                        context, ref, day, monday.add(Duration(days: dayIndex)))
                    : null,
                onOpen: day == null
                    ? () => showDayAssignmentPicker(context, ref, weekday)
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DayDetailScreen(dayId: day.id),
                          ),
                        ),
              );
            }),
            const SizedBox(height: CxSpace.md),
          ],

          const SizedBox(height: CxSpace.lg),
          ProgramGuideSection(program: program),
        ],
      ),
    );
  }

  /// Names and keeps the current week so switching plans is reversible.
  Future<void> _saveCurrentSchedule(BuildContext context, WidgetRef ref) async {
    final program = ref.read(programProvider);
    if (program == null) return;
    final controller = TextEditingController(text: program.name);

    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CxGlassBottomSheet(
        title: 'Save this schedule',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give it a name you will recognise later — "My 4-day split", '
              '"Winter bulk".',
              style: CxType.bodySmall
                  .copyWith(color: ctx.cx.textSecondary),
            ),
            const SizedBox(height: CxSpace.lg),
            CxTextField(
              label: 'Schedule name',
              hint: 'My 4-day split',
              controller: controller,
              onChanged: (_) {},
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: CxSpace.lg),
            CxButton(
              label: 'Save',
              expand: true,
              haptic: CxHaptic.success,
              onPressed: () => Navigator.pop(ctx, controller.text),
            ),
            const SizedBox(height: CxSpace.sm),
          ],
        ),
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    ref.read(savedSchedulesProvider.notifier).save(name, program);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as "${name.trim()}"')),
      );
    }
  }

  void _showTemplates(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final sex = ref.read(userProfileProvider).sex;
    // Sex only filters which plans appear — no “men’s / women’s” labels.
    final catalog = ProgramTemplates.forSex(sex);
    const title = 'Plan library';
    CxHaptics.fire(CxHaptic.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => CxGlassBottomSheet(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready-made plans you can switch to. Your workout history is kept.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.lg),

            // Save first, so trying a different plan is never one-way.
            CxButton(
              label: 'Save my current schedule',
              variant: CxButtonVariant.secondary,
              expand: true,
              icon: Icons.bookmark_add_outlined,
              onPressed: () => _saveCurrentSchedule(context, ref),
            ),
            const SizedBox(height: CxSpace.lg),

            Consumer(builder: (context, ref, _) {
              final saved = ref.watch(savedSchedulesProvider);
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your saved schedules',
                      style:
                          CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  for (final s in saved) ...[
                    CxCard(
                      onTap: () {
                        CxHaptics.fire(CxHaptic.success);
                        ref
                            .read(programProvider.notifier)
                            .loadProgram(s.program);
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${s.name} loaded')),
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: CxType.titleSmall
                                        .copyWith(color: c.textPrimary)),
                                const SizedBox(height: 4),
                                Text(s.subtitle,
                                    style: CxType.bodySmall
                                        .copyWith(color: c.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline_rounded,
                                color: c.textTertiary, size: 20),
                            onPressed: () => ref
                                .read(savedSchedulesProvider.notifier)
                                .remove(s.id),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CxSpace.md),
                  ],
                  const SizedBox(height: CxSpace.sm),
                  Text('Ready-made plans',
                      style:
                          CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                ],
              );
            }),
            for (final t in catalog) ...[
              CxCard(
                onTap: () => _confirmLoadTemplate(context, ref, sheetCtx, t),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style:
                            CxType.titleSmall.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      // Days trained per week, not sessions written — PPL × 2
                      // is three sessions across six days.
                      '${ProgramNotifier.weeklyFrequency(t)} days · ${t.description}',
                      style:
                          CxType.bodySmall.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CxSpace.md),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLoadTemplate(
    BuildContext context,
    WidgetRef ref,
    BuildContext sheetCtx,
    Program template,
  ) async {
    final c = context.cx;
    final current = ref.read(programProvider);
    // Re-picking the plan you're already on is a no-op — unless the week you
    // ended up with doesn't match the plan (an older build laid these out
    // across every training day), in which case re-picking it is exactly how
    // someone would try to fix it, and it should work.
    if (current != null &&
        current.id == template.id &&
        ProgramNotifier.weeklyFrequency(current) ==
            ProgramNotifier.weeklyFrequency(template)) {
      Navigator.pop(sheetCtx);
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CxRadii.lg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(CxSpace.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: c.warning),
                const SizedBox(width: CxSpace.sm),
                Expanded(
                  child: Text('Replace your current plan?',
                      style: CxType.title.copyWith(color: c.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: CxSpace.md),
            Text(
              'Switching to “${template.name}” will replace your current schedule and any day edits. Logged workouts and PRs stay on this device.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.xl),
            CxButton(
              label: 'Yes, switch plan',
              expand: true,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: CxSpace.sm),
            CxButton(
              label: 'Cancel',
              variant: CxButtonVariant.ghost,
              expand: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    // Keep the plan's own weekly frequency — the card said "3 days", so the
    // week it produces trains three days. Which three comes from the user's
    // preferred days when they offer enough of them.
    final days = ref.read(userProfileProvider).daysPerWeek;
    final assigned = ProgramNotifier.fitTemplateToWeek(template, days);
    ref.read(programProvider.notifier).loadProgram(assigned);
    if (context.mounted) {
      Navigator.pop(sheetCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.name} loaded')),
      );
    }
  }

  /// Backfill: opens the normal logging screen with the session dated to the
  /// missed day — log what you actually did, finish, and it lands in history
  /// on the right date (heatmap, week strip and progression all pick it up).
  void _backfillDay(
      BuildContext context, WidgetRef ref, WorkoutDay day, DateTime date) {
    if (ref.read(activeWorkoutProvider) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Finish or cancel your current workout first, then backfill.')));
      return;
    }
    CxHaptics.fire(CxHaptic.selection);
    final program = ref.read(programProvider);
    ref.read(activeWorkoutProvider.notifier).startWorkout(
          day,
          program?.id ?? '',
          {},
          // Noon avoids any timezone edge landing it on the wrong day.
          forDate: DateTime(date.year, date.month, date.day, 12),
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ActiveWorkoutScreen(),
        fullscreenDialog: true,
      ),
    );
  }

}

/// One weekday row: workout card (with tappable exercise chips → guide) or a
/// quiet rest-day card.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.isToday,
    required this.day,
    required this.onOpen,
    required this.onReassign,
    this.onBackfill,
  });

  final String weekday;
  final bool isToday;
  final WorkoutDay? day;
  final VoidCallback onOpen;
  final VoidCallback onReassign;

  /// Non-null when this is a past training day of the current week with no
  /// logged workout — shows the "log it now" affordance.
  final VoidCallback? onBackfill;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isRest = day == null;

    return CxCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(CxSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday
                      ? c.ember
                      : (isRest ? c.surfaceHigh : c.ultraviolet.withValues(alpha: 0.15)),
                  borderRadius: CxRadii.brMd,
                ),
                child: Text(
                  weekday.substring(0, 2).toUpperCase(),
                  style: CxType.label.copyWith(
                    color: isToday
                        ? c.onEmber
                        : (isRest ? c.textTertiary : c.ultraviolet),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRest ? 'Rest & recovery' : day!.name,
                      style: CxType.titleSmall.copyWith(
                        color: isRest ? c.textSecondary : c.textPrimary,
                      ),
                    ),
                    Text(
                      isRest
                          ? 'Muscles grow on rest days'
                          : '${day!.exercises.length} exercises',
                      style: CxType.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Padding(
                  padding: const EdgeInsets.only(right: CxSpace.sm),
                  child: Text('TODAY',
                      style: CxType.overline.copyWith(color: c.ember)),
                ),
              IconButton(
                icon: Icon(Icons.swap_horiz_rounded, color: c.textTertiary),
                tooltip: "Change this day's workout",
                onPressed: onReassign,
              ),
              if (!isRest)
                Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
          if (!isRest) ...[
            const SizedBox(height: CxSpace.md),
            Wrap(
              spacing: CxSpace.sm,
              runSpacing: CxSpace.sm,
              children: [
                for (final ex in day!.exercises)
                  GestureDetector(
                    onTap: () => showExerciseGuideSheet(
                      context,
                      exerciseName: ex.name,
                      muscleGroup: ex.muscleGroup,
                      equipment: ex.equipment,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: CxSpace.md, vertical: CxSpace.xs),
                      decoration: BoxDecoration(
                        color: c.surfaceHigh,
                        borderRadius: CxRadii.brPill,
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ex.name,
                              style: CxType.caption
                                  .copyWith(color: c.textSecondary)),
                          const SizedBox(width: 4),
                          Icon(Icons.help_outline_rounded,
                              size: 12, color: c.ultraviolet),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (onBackfill != null) ...[
            const SizedBox(height: CxSpace.md),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBackfill,
                borderRadius: CxRadii.brMd,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: CxSpace.md, vertical: CxSpace.sm),
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.12),
                    borderRadius: CxRadii.brMd,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: c.warning),
                      const SizedBox(width: CxSpace.sm),
                      Expanded(
                        child: Text(
                          'Trained but forgot to log? Add it now.',
                          style: CxType.caption.copyWith(color: c.textPrimary),
                        ),
                      ),
                      Text('Log $weekday',
                          style: CxType.caption.copyWith(
                              color: c.warning, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom-sheet picker: assign any program day to [weekday], or make it rest.
/// Shared by the schedule screen and the onboarding review step.
void showDayAssignmentPicker(
    BuildContext context, WidgetRef ref, String weekday) {
  final c = context.cx;
  final program = ref.read(programProvider);
  if (program == null) return;
  final currentId = program.dayAssignments[weekday];

  CxHaptics.fire(CxHaptic.selection);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => CxGlassBottomSheet(
      title: '$weekday plan',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rest option
          ListTile(
            leading: Icon(Icons.hotel_rounded,
                color: currentId == null ? c.ember : c.textSecondary),
            title: Text('Rest day',
                style: CxType.titleSmall.copyWith(color: c.textPrimary)),
            subtitle: Text('Recovery is where muscle is built',
                style: CxType.caption.copyWith(color: c.textTertiary)),
            trailing: currentId == null
                ? Icon(Icons.check_rounded, color: c.ember)
                : null,
            onTap: () {
              CxHaptics.fire(CxHaptic.selection);
              ref
                  .read(programProvider.notifier)
                  .assignWorkoutToWeekday(weekday, null);
              Navigator.pop(sheetCtx);
            },
          ),
          const Divider(),
          for (final day in program.days)
            ListTile(
              leading: Icon(Icons.fitness_center_rounded,
                  color: currentId == day.id ? c.ember : c.textSecondary),
              title: Text(day.name,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              subtitle: Text(
                day.exercises.map((e) => e.name).take(3).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CxType.caption.copyWith(color: c.textTertiary),
              ),
              trailing: currentId == day.id
                  ? Icon(Icons.check_rounded, color: c.ember)
                  : null,
              onTap: () {
                CxHaptics.fire(CxHaptic.selection);
                ref
                    .read(programProvider.notifier)
                    .assignWorkoutToWeekday(weekday, day.id);
                Navigator.pop(sheetCtx);
              },
            ),
        ],
      ),
    ),
  );
}

/// A one-tap starting point for the Coach sheet. Real requests users actually
/// have, rather than making them guess what the assistant understands.
class _CoachPromptChip extends StatelessWidget {
  const _CoachPromptChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cxPastelInk(opacity: 0.08),
      borderRadius: CxRadii.brPill,
      child: InkWell(
        borderRadius: CxRadii.brPill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: CxSpace.md, vertical: CxSpace.sm),
          child: Text(
            label,
            style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.85)),
          ),
        ),
      ),
    );
  }
}
