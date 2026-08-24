import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/models/models.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;

  const WorkoutSummaryScreen({super.key, required this.session});

  @override
  ConsumerState<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _xpController;
  late Animation<double> _xpAnimation;

  @override
  void initState() {
    super.initState();
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _xpAnimation = Tween<double>(begin: 0, end: widget.session.xpEarned.toDouble()).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOutCubic),
    );

    _xpController.forward();
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = widget.session;
    final weekComplete = ref.watch(weekCompleteProvider);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CxSpace.screen),
          child: Column(
            children: [
              const SizedBox(height: CxSpace.xl),
              // Success Crown
              Icon(Icons.emoji_events_rounded, color: c.warning, size: 72),
              const SizedBox(height: CxSpace.md),
              Text(
                "Workout Complete!",
                style: CxType.displayL.copyWith(color: c.textPrimary),
              ),
              Text(
                "You smashed: ${s.workoutDayName}",
                textAlign: TextAlign.center,
                style: CxType.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: CxSpace.x3l),

              // Week-complete celebration — fires once, the moment this
              // session hits the week's training-day target (peak-end rule:
              // end the week on its biggest high).
              if (weekComplete != null) ...[
                _WeekCompleteCard(info: weekComplete),
                const SizedBox(height: CxSpace.x2l),
              ],

              // XP Earned Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _xpAnimation,
                    builder: (context, child) {
                      return Text(
                        "+${_xpAnimation.value.toInt()}",
                        style: CxType.numHero.copyWith(color: c.warning),
                      );
                    },
                  ),
                  const SizedBox(width: CxSpace.sm),
                  Text(
                    "XP",
                    style: CxType.title.copyWith(color: c.warning, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                s.coachBonusReason ??
                    "Workout, set-completion and PR rewards included",
                textAlign: TextAlign.center,
                style: CxType.caption.copyWith(
                  color: s.coachBonusReason != null ? c.warning : c.textTertiary,
                ),
              ),
              const SizedBox(height: CxSpace.x3l),

              // Key Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "DURATION",
                      "${s.durationSeconds ~/ 60}m",
                      Icons.timer_outlined,
                      c,
                    ),
                  ),
                  const SizedBox(width: CxSpace.md),
                  Expanded(
                    child: _buildStatCard(
                      "TOTAL VOLUME",
                      "${s.totalVolume.toInt()} kg",
                      Icons.fitness_center_rounded,
                      c,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CxSpace.x2l),

              // PRs Hit Card
              if (s.prsHit.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("PRs Claimed!", style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                ),
                const SizedBox(height: CxSpace.md),
                CxCard(
                  child: Column(
                    children: [
                      for (final pr in s.prsHit) ...[
                        Row(
                          children: [
                            Icon(Icons.stars_rounded, color: c.warning, size: 20),
                            const SizedBox(width: CxSpace.md),
                            Expanded(
                              child: Text(
                                pr,
                                style: CxType.bodySmall.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CxSpace.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: CxSpace.x2l),
              ],

              // Progressive Overload Suggestions Card
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Progressive Overload Coaching", style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              ),
              const SizedBox(height: CxSpace.md),
              for (final entry in s.overloadSuggestions.entries) ...[
                _buildOverloadCard(entry.key, entry.value, c),
                const SizedBox(height: CxSpace.md),
              ],

              const SizedBox(height: CxSpace.x4l),

              // Back to Today Screen
              CxButton(
                label: "Back to Today",
                expand: true,
                onPressed: () {
                  CxHaptics.fire(CxHaptic.selection);
                  ref.read(weekCompleteProvider.notifier).clear();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: CxSpace.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, CxColorsExt c) {
    return CxCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c.textTertiary, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: CxType.overline.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          Text(
            value,
            style: CxType.numXL.copyWith(color: c.textPrimary, fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildOverloadCard(String exerciseName, String suggestion, CxColorsExt c) {
    final isIncrease = suggestion.contains("+");

    return CxCard(
      border: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncrease ? Icons.trending_up_rounded : Icons.pause_circle_outline_rounded,
                color: isIncrease ? c.success : c.warning,
                size: 20,
              ),
              const SizedBox(width: CxSpace.sm),
              Text(
                exerciseName.toUpperCase(),
                style: CxType.overline.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          Text(
            suggestion,
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "That's the whole week" celebration — the biggest positive moment the app
/// has, per the plan's peak-end rule. Data-backed fact when one exists
/// (PRs, volume up, weeks streak); always positive, never hollow.
class _WeekCompleteCard extends StatelessWidget {
  const _WeekCompleteCard({required this.info});

  final WeekCompleteInfo info;

  @override
  Widget build(BuildContext context) {
    return CxPastelCard(
      tint: CxPastelTint.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const YorhartWidget(expression: 'celebrating', size: 56, animate: true),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEK COMPLETE',
                      style: CxType.overline
                          .copyWith(color: cxPastelInk(opacity: 0.7)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Every session, banked.',
                      style: CxType.title.copyWith(color: cxPastelInk()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          Wrap(
            spacing: CxSpace.sm,
            runSpacing: CxSpace.sm,
            children: [
              _chip(
                Icons.check_circle_rounded,
                '${info.workoutsThisWeek} of ${info.trainingDaysPlanned} training days',
              ),
              if (info.prsThisWeek > 0)
                _chip(Icons.stars_rounded,
                    '${info.prsThisWeek} PR${info.prsThisWeek == 1 ? '' : 's'} this week'),
              if (info.weeksStreak >= 2)
                _chip(Icons.local_fire_department_rounded,
                    '${info.weeksStreak} full weeks in a row'),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          Text(
            info.message,
            style: CxType.bodySmall.copyWith(color: cxPastelInk(opacity: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CxSpace.md, vertical: CxSpace.xs),
      decoration: BoxDecoration(
        color: CxColors.pastelInk.withValues(alpha: 0.08),
        borderRadius: CxRadii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cxPastelInk(opacity: 0.8)),
          const SizedBox(width: 4),
          Text(label,
              style: CxType.caption.copyWith(
                  color: cxPastelInk(opacity: 0.85),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
