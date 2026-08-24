import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';

/// History — past sessions + consistency heatmap.
///
/// Design intent:
/// - Hero: recent workouts list (what you came to find)
/// - Quiet: 12-week heatmap as context, not chrome
/// - Moves: none beyond tap → detail
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final history = ref.watch(workoutHistoryProvider);
    final units = ref.watch(userProfileProvider).units;

    final completed = history.where((s) => s.completed).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final heatmap = _buildHeatmapDays(completed, weeks: 12);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: completed.isEmpty
            ? _EmptyHistory(colors: c)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CxSpace.screen,
                        CxSpace.lg,
                        CxSpace.screen,
                        CxSpace.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'History',
                            style: CxType.displayL
                                .copyWith(color: c.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${completed.length} workouts logged',
                            style: CxType.bodySmall
                                .copyWith(color: c.textSecondary),
                          ),
                          const SizedBox(height: CxSpace.x2l),
                          _HeatmapCard(days: heatmap, colors: c),
                          const SizedBox(height: CxSpace.x2l),
                          Text(
                            'Past workouts',
                            style: CxType.titleSmall
                                .copyWith(color: c.textPrimary),
                          ),
                          const SizedBox(height: CxSpace.md),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CxSpace.screen,
                      0,
                      CxSpace.screen,
                      120,
                    ),
                    sliver: SliverList.separated(
                      itemCount: completed.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: CxSpace.md),
                      itemBuilder: (context, index) {
                        final session = completed[index];
                        return _WorkoutHistoryCard(
                          session: session,
                          units: units,
                          colors: c,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutDetailScreen(
                                  session: session,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Last [weeks] × 7 days, oldest → newest. Value is workout count that day.
  static List<_HeatDay> _buildHeatmapDays(
    List<WorkoutSession> sessions, {
    required int weeks,
  }) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final totalDays = weeks * 7;
    final start = end.subtract(Duration(days: totalDays - 1));

    final counts = <DateTime, int>{};
    for (final s in sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      counts[d] = (counts[d] ?? 0) + 1;
    }

    return List.generate(totalDays, (i) {
      final day = start.add(Duration(days: i));
      return _HeatDay(date: day, count: counts[day] ?? 0);
    });
  }
}

class _HeatDay {
  const _HeatDay({required this.date, required this.count});
  final DateTime date;
  final int count;
}

// ---------------------------------------------------------------------------
// Empty
// ---------------------------------------------------------------------------

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.colors});

  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CxSpace.x3l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 56, color: colors.ultraviolet.withValues(alpha: 0.6)),
            const SizedBox(height: CxSpace.xl),
            Text(
              'No workouts yet',
              style: CxType.headline.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CxSpace.sm),
            Text(
              'Finish a session and it shows up here — with every set you logged.',
              style: CxType.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heatmap
// ---------------------------------------------------------------------------

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.days, required this.colors});

  final List<_HeatDay> days;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    final trained = days.where((d) => d.count > 0).length;

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 12 weeks',
                style: CxType.titleSmall.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              Text(
                '$trained days trained',
                style: CxType.caption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          AspectRatio(
            aspectRatio: 12 / 7 * 1.15,
            child: CustomPaint(
              painter: _WeekHeatmapPainter(
                days: days,
                active: colors.ultraviolet,
                empty: colors.surfaceHighest,
              ),
            ),
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            children: [
              Text('Less',
                  style: CxType.caption.copyWith(color: colors.textTertiary)),
              const SizedBox(width: CxSpace.sm),
              _LegendSwatch(color: colors.surfaceHighest),
              const SizedBox(width: 4),
              _LegendSwatch(
                  color: colors.ultraviolet.withValues(alpha: 0.35)),
              const SizedBox(width: 4),
              _LegendSwatch(
                  color: colors.ultraviolet.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              _LegendSwatch(color: colors.ultraviolet),
              const SizedBox(width: CxSpace.sm),
              Text('More',
                  style: CxType.caption.copyWith(color: colors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// GitHub-style contribution grid: columns = weeks, rows = weekdays.
class _WeekHeatmapPainter extends CustomPainter {
  _WeekHeatmapPainter({
    required this.days,
    required this.active,
    required this.empty,
  });

  final List<_HeatDay> days;
  final Color active;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const gap = 3.0;
    final weeks = (days.length / 7).ceil();
    final cellW = (size.width - gap * (weeks - 1)) / weeks;
    final cellH = (size.height - gap * 6) / 7;

    for (var i = 0; i < days.length; i++) {
      final week = i ~/ 7;
      final weekday = i % 7;
      final count = days[i].count;
      final color = count == 0
          ? empty
          : count == 1
              ? active.withValues(alpha: 0.4)
              : count == 2
                  ? active.withValues(alpha: 0.7)
                  : active;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          week * (cellW + gap),
          weekday * (cellH + gap),
          cellW,
          cellH,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _WeekHeatmapPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.active != active;
}

// ---------------------------------------------------------------------------
// List card
// ---------------------------------------------------------------------------

class _WorkoutHistoryCard extends StatelessWidget {
  const _WorkoutHistoryCard({
    required this.session,
    required this.units,
    required this.colors,
    required this.onTap,
  });

  final WorkoutSession session;
  final String units;
  final CxColorsExt colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatRelativeDate(session.date);
    final mins = (session.durationSeconds / 60).round().clamp(1, 999);
    final sets = session.exercises.fold<int>(
      0,
      (n, e) => n + e.sets.where((s) => s.completed).length,
    );
    final hasPr = session.prsHit.isNotEmpty;

    return CxCard(
      onTap: onTap,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.workoutDayName,
                  style: CxType.titleSmall.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasPr) ...[
                Icon(Icons.stars_rounded, size: 16, color: colors.warning),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right_rounded,
                  color: colors.textTertiary, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: CxType.caption.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            children: [
              _StatChip(
                icon: Icons.schedule_rounded,
                label: '$mins min',
                colors: colors,
              ),
              const SizedBox(width: CxSpace.sm),
              _StatChip(
                icon: Icons.fitness_center_rounded,
                label: '$sets sets',
                colors: colors,
              ),
              const SizedBox(width: CxSpace.sm),
              _StatChip(
                icon: Icons.monitor_weight_outlined,
                label: formatWeight(session.totalVolume, units, decimals: 0),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today · ${DateFormat.jm().format(date)}';
    if (diff == 1) return 'Yesterday · ${DateFormat.jm().format(date)}';
    if (diff < 7) {
      return '${DateFormat.EEEE().format(date)} · ${DateFormat.jm().format(date)}';
    }
    return DateFormat.yMMMd().add_jm().format(date);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpace.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: CxRadii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: CxType.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final units = ref.watch(userProfileProvider).units;
    final mins = (session.durationSeconds / 60).round().clamp(1, 999);
    final dateLabel = DateFormat.yMMMEd().add_jm().format(session.date);

    final totalCompletedSets = session.exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.completed).length,
    );

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: Text(
          session.workoutDayName,
          style: CxType.title.copyWith(color: c.textPrimary),
        ),
        backgroundColor: c.canvas,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CxSpace.screen,
          CxSpace.xs,
          CxSpace.screen,
          140, // Generous bottom padding so the floating bottom nav bar never obscures the last exercise
        ),
        children: [
          // Date & session summary badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CxSpace.md,
                  vertical: CxSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: CxRadii.brPill,
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: c.ember),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: CxType.caption.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${session.exercises.length} exercises · $totalCompletedSets sets',
                style: CxType.caption.copyWith(color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),

          // 3 Top KPI Stat Cards
          Row(
            children: [
              Expanded(
                child: _DetailStat(
                  label: 'Duration',
                  value: '$mins min',
                  icon: Icons.timer_outlined,
                  accentColor: c.ember,
                  colors: c,
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              Expanded(
                child: _DetailStat(
                  label: 'Volume',
                  value: formatWeight(session.totalVolume, units, decimals: 0),
                  icon: Icons.fitness_center_rounded,
                  accentColor: c.ultraviolet,
                  colors: c,
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              Expanded(
                child: _DetailStat(
                  label: 'XP Earned',
                  value: '+${session.xpEarned}',
                  icon: Icons.bolt_rounded,
                  accentColor: c.warning,
                  colors: c,
                ),
              ),
            ],
          ),

          // PRs Celebration Card
          if (session.prsHit.isNotEmpty) ...[
            const SizedBox(height: CxSpace.xl),
            CxCard(
              backgroundColor: c.warning.withValues(alpha: 0.1),
              borderColor: c.warning.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(CxSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.warning.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emoji_events_rounded,
                            size: 18, color: c.warning),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Text(
                        'New Personal Records!',
                        style: CxType.titleSmall.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  for (final pr in session.prsHit)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.stars_rounded, size: 14, color: c.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pr,
                              style: CxType.bodySmall.copyWith(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Next Session Progression Recommendations (Elevated Coach Card)
          if (session.overloadSuggestions.isNotEmpty) ...[
            const SizedBox(height: CxSpace.xl),
            CxCard(
              backgroundColor: c.surfaceHigh,
              padding: const EdgeInsets.all(CxSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.ember.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 18, color: c.ember),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coach Overload Targets',
                            style: CxType.titleSmall.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Next session progression recommendations',
                            style: CxType.caption.copyWith(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  const Divider(height: 1),
                  const SizedBox(height: CxSpace.md),
                  for (final entry in session.overloadSuggestions.entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: CxSpace.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: CxSpace.md,
                        vertical: CxSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: CxRadii.brMd,
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.trending_up_rounded,
                              size: 16, color: c.ember),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${entry.key}: ',
                                    style: CxType.bodySmall.copyWith(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: entry.value,
                                    style: CxType.bodySmall.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: CxSpace.x2l),

          // Exercises Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercises & Sets',
                style: CxType.headline.copyWith(color: c.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: CxRadii.brPill,
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  '${session.exercises.length} Total',
                  style: CxType.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),

          // Exercise Log Cards
          for (final ex in session.exercises) ...[
            _ExerciseDetailCard(ex: ex, units: units, colors: c),
            const SizedBox(height: CxSpace.md),
          ],
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CxSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CxRadii.brLg,
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: CxType.caption.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: CxType.titleSmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: CxFonts.mono,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({
    required this.ex,
    required this.units,
    required this.colors,
  });

  final ExerciseLog ex;
  final String units;
  final CxColorsExt colors;

  @override
  Widget build(BuildContext context) {
    final logged = ex.sets.where((s) => s.completed).toList();
    final totalVol = logged.fold<double>(
      0,
      (sum, s) => sum + (s.weight * s.reps),
    );

    return CxCard(
      padding: const EdgeInsets.all(CxSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Muscle group tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.exerciseName,
                      style: CxType.titleSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ex.muscleGroup.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ex.muscleGroup,
                        style: CxType.caption.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              if (totalVol > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CxSpace.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceHigh,
                    borderRadius: CxRadii.brPill,
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    formatWeight(totalVol, units, decimals: 0),
                    style: CxType.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFamily: CxFonts.mono,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          if (logged.isEmpty)
            Text(
              'No sets logged',
              style: CxType.caption.copyWith(color: colors.textTertiary),
            )
          else ...[
            // Set table column headers
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: colors.surfaceHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      'SET',
                      style: CxType.caption.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'WEIGHT & REPS',
                      style: CxType.caption.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    'STATUS',
                    style: CxType.caption.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Set rows
            for (var i = 0; i < logged.length; i++) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: logged[i].isPR
                      ? colors.warning.withValues(alpha: 0.08)
                      : (i % 2 == 0
                          ? Colors.transparent
                          : colors.surfaceHigh.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    // Set Number Pill
                    SizedBox(
                      width: 38,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: logged[i].isWarmup
                              ? colors.warning.withValues(alpha: 0.2)
                              : colors.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          logged[i].isWarmup ? 'W' : '${i + 1}',
                          textAlign: TextAlign.center,
                          style: CxType.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: logged[i].isWarmup
                                ? colors.warning
                                : colors.textSecondary,
                            fontFamily: CxFonts.mono,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Weight and Reps
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            formatWeight(logged[i].weight, units),
                            style: CxType.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontFamily: CxFonts.mono,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '×',
                              style: CxType.caption
                                  .copyWith(color: colors.textTertiary),
                            ),
                          ),
                          Text(
                            '${logged[i].reps} reps',
                            style: CxType.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontFamily: CxFonts.mono,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // PR or check icon
                    if (logged[i].isPR || logged[i].isEpleyPR)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded,
                                size: 12, color: colors.warning),
                            const SizedBox(width: 3),
                            Text(
                              'PR',
                              style: CxType.caption.copyWith(
                                color: colors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: colors.success.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
