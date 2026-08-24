import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/program_templates.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../exercise_guide/presentation/exercise_guide_sheet.dart';
import '../../schedule/presentation/schedule_chat_sheet.dart';
import '../../schedule/presentation/schedule_screen.dart';

/// Clean post-onboarding step: show the week, allow light edits / Coach chat,
/// then confirm before entering the app.
class ScheduleConfirmScreen extends ConsumerStatefulWidget {
  const ScheduleConfirmScreen({super.key});

  @override
  ConsumerState<ScheduleConfirmScreen> createState() =>
      _ScheduleConfirmScreenState();
}

class _ScheduleConfirmScreenState
    extends ConsumerState<ScheduleConfirmScreen> {
  String? _expandedDayId;

  @override
  void initState() {
    super.initState();
    // Guarantee a program exists before first paint (no post-frame ref tricks).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(programProvider) != null) return;
      final profile = ref.read(userProfileProvider);
      ref.read(programProvider.notifier).generateProgram(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final program = ref.watch(programProvider);
    final profile = ref.watch(userProfileProvider);

    if (program == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: Center(
          child: CircularProgressIndicator(color: c.ember),
        ),
      );
    }

    final catalog = ProgramTemplates.forSex(profile.sex);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CxSpace.screen, CxSpace.lg, CxSpace.screen, CxSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your schedule',
                      style: CxType.displayL.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.xs),
                  Text(
                    'Built for you · ${program.dayAssignments.length} training days',
                    style: CxType.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    CxSpace.screen, CxSpace.md, CxSpace.screen, CxSpace.lg),
                children: [
                  Text('This week',
                      style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  Text(
                    'Tap a day to change the workout or mark rest.',
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: CxSpace.md),
                  _WeekChips(program: program),
                  const SizedBox(height: CxSpace.x2l),

                  Text('Sessions',
                      style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.md),
                  for (final day in program.days) ...[
                    _SessionTile(
                      day: day,
                      expanded: _expandedDayId == day.id,
                      onToggle: () {
                        setState(() {
                          _expandedDayId =
                              _expandedDayId == day.id ? null : day.id;
                        });
                      },
                      onSwapExercise: (ex) =>
                          _swapExercise(program, day, ex),
                    ),
                    const SizedBox(height: CxSpace.sm),
                  ],
                  const SizedBox(height: CxSpace.x2l),

                  // Templates are secondary — below the AI schedule so the
                  // week reads as personalized, not as a catalog pick.
                  Text('Try another plan',
                      style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  Text(
                    'Want something different? Choosing one replaces your current schedule.',
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: CxSpace.md),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalog.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: CxSpace.md),
                      itemBuilder: (context, index) {
                        final t = catalog[index];
                        final selected = program.id == t.id;
                        return SizedBox(
                          width: 200,
                          child: Material(
                            color: selected
                                ? c.ember.withValues(alpha: 0.12)
                                : c.surface,
                            borderRadius: CxRadii.brLg,
                            child: InkWell(
                              borderRadius: CxRadii.brLg,
                              onTap: () => _confirmSwitchPlan(t, profile),
                              child: Container(
                                padding: const EdgeInsets.all(CxSpace.md),
                                decoration: BoxDecoration(
                                  borderRadius: CxRadii.brLg,
                                  border: Border.all(
                                    color: selected ? c.ember : c.border,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: CxType.titleSmall
                                          .copyWith(color: c.textPrimary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${ProgramNotifier.weeklyFrequency(t)} days · ${t.description}',
                                      style: CxType.caption
                                          .copyWith(color: c.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CxSpace.screen, CxSpace.sm, CxSpace.screen, CxSpace.md),
              child: Column(
                children: [
                  CxButton(
                    label: 'Ask Coach to change it',
                    variant: CxButtonVariant.secondary,
                    expand: true,
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => _openCoach(),
                  ),
                  const SizedBox(height: CxSpace.sm),
                  CxButton(
                    label: 'Confirm & continue',
                    expand: true,
                    size: CxButtonSize.large,
                    haptic: CxHaptic.success,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSwitchPlan(Program template, UserProfile profile) async {
    final current = ref.read(programProvider);
    // Same plan *and* the same shape → nothing to do. A plan that's on screen
    // with the wrong number of training days is still worth re-applying.
    if (current != null &&
        current.id == template.id &&
        ProgramNotifier.weeklyFrequency(current) ==
            ProgramNotifier.weeklyFrequency(template)) {
      return;
    }

    final c = context.cx;
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
            Text('Switch to ${template.name}?',
                style: CxType.title.copyWith(color: c.textPrimary)),
            const SizedBox(height: CxSpace.sm),
            Text(
              'This replaces your current schedule and any day edits you’ve made. Workout history stays safe.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.xl),
            CxButton(
              label: 'Switch plan',
              expand: true,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: CxSpace.sm),
            CxButton(
              label: 'Keep current plan',
              variant: CxButtonVariant.ghost,
              expand: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    // Keep the plan's own weekly frequency, placed on the days the user said
    // they train — a plan listed as "3 days" must not become a five-day week.
    final assigned =
        ProgramNotifier.fitTemplateToWeek(template, profile.daysPerWeek);
    ref.read(programProvider.notifier).loadProgram(assigned);
    setState(() => _expandedDayId = null);
  }

  void _confirm() {
    final auth = ref.read(authProvider);
    if (auth.email == 'guest@crux.com') {
      final c = context.cx;
      showModalBottomSheet(
        context: context,
        backgroundColor: c.canvas,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(CxRadii.lg)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(CxSpace.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Save your schedule?',
                  textAlign: TextAlign.center,
                  style: CxType.title.copyWith(color: c.textPrimary)),
              const SizedBox(height: CxSpace.sm),
              Text(
                'Create an account to keep progress across devices.',
                textAlign: TextAlign.center,
                style: CxType.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: CxSpace.xl),
              CxButton(
                label: 'Create account',
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(authProvider.notifier).logout();
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(userProfileProvider.notifier).completeOnboarding();
                },
                child: Text('Skip for now',
                    style: CxType.titleSmall.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
        ),
      );
      return;
    }
    ref.read(userProfileProvider.notifier).completeOnboarding();
  }

  /// Opens the same schedule chat the rest of the app uses.
  ///
  /// This screen used to carry its own copy, which had three problems the
  /// shared one doesn't: the transcript lived in the sheet's State so dragging
  /// it down erased the conversation; a rewrite was announced but never
  /// applied, because `applyAiScheduleEdit` returns a *proposal* and the reply
  /// only printed its note; and the wait was a single frozen line. One chat,
  /// one set of fixes.
  void _openCoach() {
    showScheduleAssistantSheet(
      context,
      ref,
      title: 'Schedule Coach',
      // Mid-onboarding there is no coach tab to hand off to yet.
      allowFullCoachHandoff: false,
    );
  }

  void _swapExercise(Program program, WorkoutDay day, Exercise ex) {
    final c = context.cx;
    final alternatives = <Exercise>[];
    for (final d in program.days) {
      for (final e in d.exercises) {
        if (e.muscleGroup == ex.muscleGroup && e.id != ex.id) {
          if (!alternatives.any((a) => a.name == e.name)) {
            alternatives.add(e);
          }
        }
      }
    }
    if (alternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No swap options for this move yet')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: c.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CxRadii.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(CxSpace.lg),
              child: Text('Replace ${ex.name}',
                  style: CxType.title.copyWith(color: c.textPrimary)),
            ),
            for (final alt in alternatives)
              ListTile(
                title: Text(alt.name,
                    style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                subtitle: Text('${alt.targetSets}x${alt.targetReps}',
                    style: CxType.caption.copyWith(color: c.textSecondary)),
                onTap: () {
                  ref
                      .read(programProvider.notifier)
                      .swapExercise(day.id, ex.id, alt);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekChips extends ConsumerWidget {
  const _WeekChips({required this.program});
  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    return Row(
      children: [
        for (final weekday in Program.weekdays) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: CxRadii.brMd,
                onTap: () => showDayAssignmentPicker(context, ref, weekday),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: program.dayAssignments.containsKey(weekday)
                          ? c.ember.withValues(alpha: 0.15)
                          : c.surfaceHigh,
                      borderRadius: CxRadii.brMd,
                      border: Border.all(
                        color: program.dayAssignments.containsKey(weekday)
                            ? c.ember
                            : c.border,
                      ),
                    ),
                    child: Text(
                      weekday[0],
                      style: CxType.label.copyWith(
                        color: program.dayAssignments.containsKey(weekday)
                            ? c.ember
                            : c.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.day,
    required this.expanded,
    required this.onToggle,
    required this.onSwapExercise,
  });

  final WorkoutDay day;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(Exercise ex) onSwapExercise;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Material(
      color: c.surface,
      borderRadius: CxRadii.brLg,
      child: InkWell(
        borderRadius: CxRadii.brLg,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(CxSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(day.name,
                        style:
                            CxType.titleSmall.copyWith(color: c.textPrimary)),
                  ),
                  Text(
                    '${day.exercises.length} exercises',
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: c.textTertiary,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: CxSpace.md),
                for (final ex in day.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CxSpace.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name,
                                  style: CxType.bodySmall
                                      .copyWith(color: c.textPrimary)),
                              Text(
                                '${ex.targetSets}x${ex.targetReps}',
                                style: CxType.caption
                                    .copyWith(color: c.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.help_outline_rounded,
                              size: 18, color: c.textTertiary),
                          onPressed: () => showExerciseGuideSheet(
                            context,
                            exerciseName: ex.name,
                            muscleGroup: ex.muscleGroup,
                            equipment: ex.equipment,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.swap_horiz_rounded,
                              size: 18, color: c.textTertiary),
                          onPressed: () => onSwapExercise(ex),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

