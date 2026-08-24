import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/placeholder_screen.dart';
import '../../../app/router.dart';
import '../../../core/domain/nutrition.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Custom Painters for Sparklines, Heatmaps, and Trends
// ---------------------------------------------------------------------------

class WeightSparklinePainter extends CustomPainter {
  final List<double> weights;
  final Color color;

  /// Optional 7-day rolling average, aligned 1:1 with [weights]. When present
  /// the average is drawn as the hero line and the raw points are ghosted
  /// behind it (Phase 4: "raw points ghosted").
  final List<double>? averages;

  WeightSparklinePainter({
    required this.weights,
    required this.color,
    this.averages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;

    // Scale against the combined range of raw + average so nothing clips.
    final all = <double>[...weights, ...?averages];
    final double minW = all.reduce(math.min);
    final double maxW = all.reduce(math.max);
    final double range = maxW - minW == 0 ? 1 : maxW - minW;
    final double stepX =
        weights.length == 1 ? 0 : size.width / (weights.length - 1);

    double yFor(double v) =>
        size.height - (((v - minW) / range) * (size.height - 16) + 8);

    final hasAvg = averages != null && averages!.length == weights.length;

    // --- Raw series (ghosted when an average is shown) --------------------
    final rawOpacity = hasAvg ? 0.35 : 1.0;
    final linePaint = Paint()
      ..color = color.withValues(alpha: rawOpacity)
      ..strokeWidth = hasAvg ? 1.5 : 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (!hasAvg) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      final fillPath = Path();
      for (int i = 0; i < weights.length; i++) {
        final x = i * stepX;
        final y = yFor(weights[i]);
        if (i == 0) {
          fillPath.moveTo(x, size.height);
          fillPath.lineTo(x, y);
        } else {
          fillPath.lineTo(x, y);
        }
        if (i == weights.length - 1) {
          fillPath.lineTo(x, size.height);
          fillPath.close();
        }
      }
      canvas.drawPath(fillPath, fillPaint);
    }

    final rawPath = Path();
    for (int i = 0; i < weights.length; i++) {
      final x = i * stepX;
      final y = yFor(weights[i]);
      i == 0 ? rawPath.moveTo(x, y) : rawPath.lineTo(x, y);
    }
    canvas.drawPath(rawPath, linePaint);

    // Raw points.
    final pointPaint = Paint()
      ..color = color.withValues(alpha: rawOpacity)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < weights.length; i++) {
      canvas.drawCircle(Offset(i * stepX, yFor(weights[i])),
          hasAvg ? 3 : 5, pointPaint);
    }

    // --- Average series (hero line) ---------------------------------------
    if (hasAvg) {
      final avgPaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final avgPath = Path();
      for (int i = 0; i < averages!.length; i++) {
        final x = i * stepX;
        final y = yFor(averages![i]);
        i == 0 ? avgPath.moveTo(x, y) : avgPath.lineTo(x, y);
      }
      canvas.drawPath(avgPath, avgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeightSparklinePainter oldDelegate) =>
      oldDelegate.weights != weights || oldDelegate.averages != averages;
}

/// Rolling average series aligned to [values] (window up to 7 samples).
List<double> rollingAverageSeries(List<double> values, {int window = 7}) {
  final out = <double>[];
  for (int i = 0; i < values.length; i++) {
    final start = (i - window + 1) < 0 ? 0 : i - window + 1;
    final slice = values.sublist(start, i + 1);
    out.add(slice.reduce((a, b) => a + b) / slice.length);
  }
  return out;
}

// Heatmap Painter representing GH contribution board
class HeatmapPainter extends CustomPainter {
  final List<int> completions; // 28 values for a 4x7 grid
  final Color activeColor;

  HeatmapPainter({required this.completions, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSpacing = 4.0;
    final double cellWidth = (size.width - (3 * cellSpacing)) / 4;
    final double cellHeight = (size.height - (6 * cellSpacing)) / 7;

    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 7; row++) {
        final int index = col * 7 + row;
        if (index >= completions.length) continue;

        final count = completions[index];
        Color cellColor = CxColors.darkSurfaceHigh;
        if (count == 1) {
          cellColor = activeColor.withOpacity(0.4);
        } else if (count >= 2) {
          cellColor = activeColor;
        }

        final paint = Paint()
          ..color = cellColor
          ..style = PaintingStyle.fill;

        final double x = col * (cellWidth + cellSpacing);
        final double y = row * (cellHeight + cellSpacing);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, cellWidth, cellHeight),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Dashboard Screen
// ---------------------------------------------------------------------------
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider);
    if (program == null) {
      final l10n = AppL10n.of(context);
      return PlaceholderScreen(
        title: l10n.dashboardTitle,
        message: l10n.dashboardPlaceholder,
        icon: Icons.insights_rounded,
        accent: CxColors.ultraviolet,
        yorhartExpression: 'determined',
      );
    }

    final c = context.cx;
    final profile = ref.watch(userProfileProvider);
    final history = ref.watch(workoutHistoryProvider);
    final weights = ref.watch(bodyweightProvider);

    // Filter to completed workouts
    final completedWorkouts = history.where((s) => s.completed).toList();

    // Consistency heatmap mock completions (28 days)
    // Map history dates to days of heatmap
    final heatmapCompletions = List<int>.generate(28, (idx) {
      final daysAgo = 27 - idx;
      final checkDate = DateTime.now().subtract(Duration(days: daysAgo));
      final completedOnDay = history.where((s) =>
          s.completed &&
          s.date.year == checkDate.year &&
          s.date.month == checkDate.month &&
          s.date.day == checkDate.day);
      return completedOnDay.length;
    });

    // Extract raw weights
    final weightValues = weights.map((w) => w.weight).toList();

    // Muscle volume balance calculation
    final Map<String, double> muscleVolumes = {
      'Legs': 0.0,
      'Chest': 0.0,
      'Back': 0.0,
      'Shoulders': 0.0,
      'Arms': 0.0,
      'Core': 0.0,
    };

    for (var session in completedWorkouts) {
      for (var ex in session.exercises) {
        final double vol = ex.sets.where((s) => s.completed).map((s) => s.weight * s.reps).fold(0, (a, b) => a + b);
        muscleVolumes[ex.muscleGroup] = (muscleVolumes[ex.muscleGroup] ?? 0) + vol;
      }
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(CxSpace.screen, CxSpace.md, CxSpace.screen, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(profile, c),
              const SizedBox(height: CxSpace.x2l),

              // Weight Sparkline Card
              _buildWeightCard(context, weights, weightValues, profile.units, c),
              const SizedBox(height: CxSpace.xl),

              // Nutrition — goal-aware calorie band + daily protein quick-log.
              _NutritionCard(profile: profile),
              const SizedBox(height: CxSpace.xl),

              // Heatmap & Weekly Stats Side-by-side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildHeatmapCard(heatmapCompletions, c),
                  ),
                  const SizedBox(width: CxSpace.md),
                  Expanded(
                    flex: 5,
                    child: _buildWeeklySummaryCard(completedWorkouts, profile, c),
                  ),
                ],
              ),
              const SizedBox(height: CxSpace.xl),

              // Big Lift e1RM Trends with standard markers
              _buildBigLiftTrends(completedWorkouts, c),
              const SizedBox(height: CxSpace.xl),

              // Muscle group weekly balance chart
              _buildMuscleVolumeChart(muscleVolumes, c),
              const SizedBox(height: CxSpace.xl),

              // Recent PRs Strip
              _buildRecentPRsStrip(completedWorkouts, c),
              const SizedBox(height: CxSpace.xl),

              // Ask Coach Shortcut
              _buildCoachShortcut(context, c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile profile, CxColorsExt c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LEVEL ${profile.level}",
                style: CxType.overline.copyWith(color: c.ultraviolet),
              ),
              const SizedBox(height: 2),
              Text(
                "Iron Dashboard",
                style: CxType.headline.copyWith(color: c.textPrimary),
              ),
              Text(
                profile.rankBadge,
                style: CxType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: CxSpace.md),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceHigh,
            border: Border.all(color: c.border, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: (profile.avatar.isEmpty || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')))
              ? null
              : (profile.avatar.startsWith('assets/')
                  ? Image.asset(profile.avatar, fit: BoxFit.cover)
                  : YorhartWidget(expression: profile.avatar, size: 40)),
        ),
      ],
    );
  }

  Widget _buildWeightCard(BuildContext context, List<WeighIn> weights, List<double> weightValues, String units, CxColorsExt c) {
    final double latestWeight = weightValues.isNotEmpty ? weightValues.last : 75.0;
    final double avg7Day = weightValues.length >= 7
        ? weightValues.sublist(weightValues.length - 7).reduce((a, b) => a + b) / 7
        : latestWeight;

    // Convert kg → display units for the chart so the axis matches the labels.
    final displayValues = weightValues.isNotEmpty
        ? weightValues
            .map((w) => double.parse(formatWeightValue(w, units, decimals: 1)))
            .toList()
        : [75.0, 75.0, 75.0];

    return CxCard(
      onTap: () => _openWeighInSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BODYWEIGHT TREND", style: CxType.overline.copyWith(color: c.textSecondary)),
                    Row(
                      children: [
                        Text(
                          formatWeight(latestWeight, units),
                          style: CxType.numXL.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Avg: ${formatWeight(avg7Day, units)}",
                            style: CxType.caption.copyWith(color: c.textTertiary, fontFamily: CxFonts.mono),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, color: c.ultraviolet, size: 28),
                onPressed: () => _openWeighInSheet(context),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: WeightSparklinePainter(
                weights: displayValues,
                averages: rollingAverageSeries(displayValues),
                color: c.ultraviolet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(List<int> completions, CxColorsExt c) {
    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CONSISTENCY", style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.sm),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: HeatmapPainter(
                completions: completions,
                activeColor: c.ultraviolet,
              ),
            ),
          ),
          const SizedBox(height: CxSpace.sm),
          Text("Last 28 Days heatmap", style: CxType.caption.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard(List<WorkoutSession> sessions, UserProfile profile, CxColorsExt c) {
    // Done vs Planned Days
    final doneCount = sessions.where((s) => s.date.difference(DateTime.now()).inDays.abs() < 7).length;
    final plannedCount = profile.daysPerWeek.length;

    // Volume vs Last Week
    final double thisWeekVol = sessions
        .where((s) => s.date.difference(DateTime.now()).inDays.abs() < 7)
        .map((s) => s.totalVolume)
        .fold(0, (a, b) => a + b);
    final double lastWeekVol = sessions
        .where((s) => s.date.difference(DateTime.now()).inDays.abs() >= 7 && s.date.difference(DateTime.now()).inDays.abs() < 14)
        .map((s) => s.totalVolume)
        .fold(0, (a, b) => a + b);

    double percentDiff = 0.0;
    if (lastWeekVol > 0) {
      percentDiff = ((thisWeekVol - lastWeekVol) / lastWeekVol) * 100;
    }

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("WEEKLY SUMMARY", style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.md),
          Text(
            "$doneCount / $plannedCount Days Done",
            style: CxType.titleSmall.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: CxSpace.sm),
          Row(
            children: [
              Icon(
                percentDiff >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: percentDiff >= 0 ? c.success : c.danger,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "${percentDiff >= 0 ? "+" : ""}${percentDiff.toStringAsFixed(0)}% Vol vs Last Week",
                  style: CxType.caption.copyWith(color: percentDiff >= 0 ? c.success : c.danger, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          Text(
            "Volume: ${thisWeekVol.toInt()} kg",
            style: CxType.caption.copyWith(color: c.textTertiary, fontFamily: CxFonts.mono),
          ),
        ],
      ),
    );
  }

  Widget _buildBigLiftTrends(List<WorkoutSession> sessions, CxColorsExt c) {
    // Extract highest e1RM for Squat & Bench Press in each session
    final List<double> squatTrend = [];
    final List<double> benchTrend = [];

    for (var s in sessions) {
      double squatMax = 0;
      double benchMax = 0;
      for (var ex in s.exercises) {
        if (ex.exerciseName.contains("Squat")) {
          for (var set in ex.sets) {
            final epley = set.weight * (1 + set.reps / 30.0);
            if (epley > squatMax) squatMax = epley;
          }
        }
        if (ex.exerciseName.contains("Bench")) {
          for (var set in ex.sets) {
            final epley = set.weight * (1 + set.reps / 30.0);
            if (epley > benchMax) benchMax = epley;
          }
        }
      }
      if (squatMax > 0) squatTrend.add(squatMax);
      if (benchMax > 0) benchTrend.add(benchMax);
    }

    final double squatMaxVal = squatTrend.isNotEmpty ? squatTrend.reduce(math.max) : 85.0;
    final double benchMaxVal = benchTrend.isNotEmpty ? benchTrend.reduce(math.max) : 60.0;

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ESTIMATED 1RM STRENGTH STANDARDS", style: CxType.overline.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.lg),
          _buildStrengthStandardRow("Squat", squatMaxVal, 50, 90, 140, c),
          const SizedBox(height: CxSpace.lg),
          _buildStrengthStandardRow("Bench Press", benchMaxVal, 40, 70, 100, c),
        ],
      ),
    );
  }

  Widget _buildStrengthStandardRow(String name, double current, double novice, double intermediate, double advanced, CxColorsExt c) {
    // Find where the current falls
    String tier = "Novice";
    Color tierColor = c.textTertiary;
    double progressPercent = (current / advanced).clamp(0, 1);

    if (current >= advanced) {
      tier = "Advanced Standard";
      tierColor = c.ember;
    } else if (current >= intermediate) {
      tier = "Intermediate Standard";
      tierColor = c.ultraviolet;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: CxType.titleSmall.copyWith(color: c.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CxSpace.sm),
            Text(
              "${current.toStringAsFixed(0)} kg e1RM ($tier)",
              style: CxType.caption.copyWith(color: tierColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.sm),
        Row(
          children: [
            Expanded(
              child: CxProgressBar(
                value: progressPercent,
                height: 10,
                accent: current >= intermediate ? CxProgressAccent.ember : CxProgressAccent.ultraviolet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Novice (${novice.toInt()}kg)", style: CxType.caption.copyWith(color: c.textTertiary, fontSize: 10)),
            Text("Inter (${intermediate.toInt()}kg)", style: CxType.caption.copyWith(color: c.textTertiary, fontSize: 10)),
            Text("Adv (${advanced.toInt()}kg)", style: CxType.caption.copyWith(color: c.textTertiary, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildMuscleVolumeChart(Map<String, double> volumes, CxColorsExt c) {
    final double maxVolume = volumes.values.isNotEmpty ? volumes.values.reduce(math.max) : 1;

    // Check if any muscle has 0 volume to flag as neglected
    final List<String> neglected = [];
    volumes.forEach((muscle, vol) {
      if (vol == 0.0) {
        neglected.add(muscle);
      }
    });

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "MUSCLE GROUP WEEKLY BALANCE",
                  style: CxType.overline.copyWith(color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              if (neglected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: CxSpace.sm, vertical: CxSpace.xxs),
                  decoration: BoxDecoration(color: c.danger.withOpacity(0.15), borderRadius: CxRadii.brPill),
                  child: Text(
                    "${neglected.first} Neglected!",
                    style: CxType.caption.copyWith(color: c.danger, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CxSpace.lg),
          for (var entry in volumes.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CxSpace.xs),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(entry.key, style: CxType.caption.copyWith(color: c.textPrimary))),
                  Expanded(
                    child: CxProgressBar(
                      value: maxVolume == 0 ? 0 : (entry.value / maxVolume).clamp(0, 1),
                      height: 8,
                      accent: entry.value == 0 ? CxProgressAccent.ember : CxProgressAccent.ultraviolet,
                    ),
                  ),
                  const SizedBox(width: CxSpace.md),
                  Text(
                    "${entry.value.toInt()} kg",
                    style: CxType.caption.copyWith(color: c.textSecondary, fontFamily: CxFonts.mono),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentPRsStrip(List<WorkoutSession> sessions, CxColorsExt c) {
    // Aggregate PRs
    final List<String> prs = [];
    for (var s in sessions) {
      for (var pr in s.prsHit) {
        prs.add(pr);
      }
    }

    if (prs.isEmpty) {
      prs.add("Squat 65kg x 10 (Weight PR!)");
      prs.add("Bench Press 55kg x 9 (e1RM PR!)");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("RECENT PRS", style: CxType.titleSmall.copyWith(color: c.textPrimary)),
        const SizedBox(height: CxSpace.md),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: prs.length,
            itemBuilder: (context, idx) {
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: CxSpace.md),
                child: CxPastelCard(
                  tint: CxPastelTint.lilac,
                  padding: const EdgeInsets.all(CxSpace.md),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: cxPastelInk(), size: 24),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: Text(
                          prs[idx],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CxType.caption.copyWith(color: cxPastelInk(), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCoachShortcut(BuildContext context, CxColorsExt c) {
    return CxCard(
      border: true,
      onTap: () => context.go(Routes.coach),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: c.ember, size: 28),
          const SizedBox(width: CxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Stalled or need program advice?", style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                Text("Ask Coach Yorhart for starting weights & tips.", style: CxType.caption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: c.textTertiary, size: 16),
        ],
      ),
    );
  }

  void _openWeighInSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return const WeighInSheet();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Weigh-in Quick Sheet (Modal)
// ---------------------------------------------------------------------------
class WeighInSheet extends ConsumerStatefulWidget {
  const WeighInSheet({super.key});

  @override
  ConsumerState<WeighInSheet> createState() => _WeighInSheetState();
}

class _WeighInSheetState extends ConsumerState<WeighInSheet> {
  late double _displayWeight; // value in the user's display units
  late String _units;

  static const _measurementDefaults = {
    'Waist': 80.0,
    'Chest': 100.0,
    'Arms': 35.0,
    'Thighs': 55.0,
    'Hips': 95.0,
  };

  @override
  void initState() {
    super.initState();
    _units = ref.read(userProfileProvider).units;
    final weights = ref.read(bodyweightProvider);
    final latestKg = weights.isNotEmpty ? weights.last.weight : 74.8;
    _displayWeight =
        double.parse(formatWeightValue(latestKg, _units, decimals: 1));
  }

  double get _stepMin => _units == 'lbs' ? 88 : 40;
  double get _stepMax => _units == 'lbs' ? 440 : 200;
  double get _step => _units == 'lbs' ? 0.2 : 0.1;
  double _toKg(double v) => _units == 'lbs' ? v * 0.45359237 : v;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final weights = ref.watch(bodyweightProvider);
    final settings = ref.watch(appSettingsProvider);
    final photos = ref.watch(progressPhotosProvider);
    final measurements = ref.watch(measurementsProvider);

    final displayValues = weights
        .map((w) => double.parse(formatWeightValue(w.weight, _units, decimals: 1)))
        .toList();
    final avgKg = ref.read(bodyweightProvider.notifier).rollingAverage7Day;

    return CxGlassBottomSheet(
      title: "Daily weigh-in",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One-time explainer: watch the average, not the dots.
          if (!settings.seenWeightAvgExplainer) ...[
            _buildExplainer(c),
            const SizedBox(height: CxSpace.xl),
          ],

          Center(
            child: Column(
              children: [
                Text(
                  "Record today's bodyweight",
                  style: CxType.caption.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: CxSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _displayWeight.toStringAsFixed(1),
                      style: CxType.numHero.copyWith(
                        color: c.textPrimary,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _units,
                      style: CxType.title.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CxSpace.md),
                CxRulerSlider(
                  value: _displayWeight,
                  min: _stepMin,
                  max: _stepMax,
                  step: _step,
                  majorInterval: 10,
                  minorInterval: 2,
                  onChanged: (val) {
                    setState(() {
                      _displayWeight = val;
                    });
                  },
                ),
                const SizedBox(height: CxSpace.xl),
                CxButton(
                  label: "Save today's weight",
                  haptic: CxHaptic.success,
                  onPressed: () {
                    ref
                        .read(bodyweightProvider.notifier)
                        .logWeighIn(_toKg(_displayWeight), ref: ref);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpace.x2l),
          const Divider(),
          const SizedBox(height: CxSpace.xl),

          // 7-day average chart (raw points ghosted behind the average line).
          Container(
            padding: const EdgeInsets.all(CxSpace.lg),
            decoration: BoxDecoration(
              color: c.surfaceHigh.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("7-day rolling average",
                        style: CxType.caption.copyWith(color: c.textSecondary)),
                    Text(
                      formatWeight(avgKg, _units),
                      style: CxType.titleSmall.copyWith(
                        color: c.ultraviolet,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CxSpace.lg),
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: WeightSparklinePainter(
                      weights: displayValues.isNotEmpty ? displayValues : [75, 75, 75],
                      averages: displayValues.isNotEmpty
                          ? rollingAverageSeries(displayValues)
                          : null,
                      color: c.ultraviolet,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CxSpace.x2l),
          const Divider(),
          const SizedBox(height: CxSpace.lg),

          // Optional measurements.
          Text("Measurements (optional)",
              style: CxType.titleSmall.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          for (final key in kMeasurementKeys)
            _buildMeasurementRow(key, measurements, c),

          const SizedBox(height: CxSpace.xl),
          const Divider(),
          const SizedBox(height: CxSpace.md),

          // Local-only progress photos.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Progress photos",
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              Text("On this device only",
                  style: CxType.caption.copyWith(color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          _buildPhotos(photos, c),
          const SizedBox(height: CxSpace.sm),
        ],
      ),
    );
  }

  Widget _buildExplainer(CxColorsExt c) {
    return Container(
      padding: const EdgeInsets.all(CxSpace.lg),
      decoration: BoxDecoration(
        color: c.ultraviolet.withOpacity(0.12),
        borderRadius: CxRadii.brLg,
        border: Border.all(color: c.ultraviolet.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_rounded, color: c.ultraviolet, size: 22),
          const SizedBox(width: CxSpace.md),
          Expanded(
            child: Text(
              "Your weight bounces daily with water and food. The 7-day average "
              "is the real trend — watch the line, not the dots.",
              style: CxType.caption.copyWith(color: c.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () {
              CxHaptics.fire(CxHaptic.selection);
              ref.read(appSettingsProvider.notifier).markWeightAvgExplainerSeen();
            },
            child: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }

  IconData _getMeasurementIcon(String key) {
    switch (key) {
      case 'Waist':
        return Icons.straighten_rounded;
      case 'Chest':
        return Icons.accessibility_new_rounded;
      case 'Arms':
        return Icons.fitness_center_rounded;
      case 'Thighs':
        return Icons.directions_run_rounded;
      case 'Hips':
        return Icons.wc_rounded;
      default:
        return Icons.rule_rounded;
    }
  }

  Widget _buildMeasurementRow(
      String key, Map<String, double> measurements, CxColorsExt c) {
    final value = measurements[key];
    final isSet = value != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSet ? c.surfaceHigh.withOpacity(0.4) : c.surfaceHigh.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSet ? c.ultraviolet.withOpacity(0.3) : c.border.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getMeasurementIcon(key),
            color: isSet ? c.ultraviolet : c.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              key,
              style: CxType.body.copyWith(
                color: isSet ? c.textPrimary : c.textSecondary,
                fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (!isSet)
            GestureDetector(
              onTap: () {
                CxHaptics.fire(CxHaptic.selection);
                ref
                    .read(measurementsProvider.notifier)
                    .setMeasurement(key, _measurementDefaults[key] ?? 50);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: c.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Add",
                      style: CxType.caption.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    color: c.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => ref
                        .read(measurementsProvider.notifier)
                        .setMeasurement(key, value - 0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "${value.toStringAsFixed(1)} cm",
                      style: CxType.numS.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    color: c.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => ref
                        .read(measurementsProvider.notifier)
                        .setMeasurement(key, value + 0.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotos(List<ProgressPhoto> photos, CxColorsExt c) {
    if (photos.isEmpty) {
      return GestureDetector(
        onTap: _addPhoto,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: CxRadii.brLg,
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded, color: c.ultraviolet, size: 28),
              const SizedBox(height: CxSpace.sm),
              Text("Add your first progress photo",
                  style: CxType.caption.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in photos) ...[
            _buildPhotoThumb(p, c),
            const SizedBox(width: CxSpace.md),
          ],
          GestureDetector(
            onTap: _addPhoto,
            child: Container(
              width: 92,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: CxRadii.brLg,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.add_a_photo_rounded, color: c.ultraviolet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumb(ProgressPhoto p, CxColorsExt c) {
    final label =
        "${p.date.day}/${p.date.month}/${p.date.year % 100}";
    return GestureDetector(
      onTap: () => _viewPhoto(p),
      onLongPress: () {
        CxHaptics.fire(CxHaptic.warning);
        ref.read(progressPhotosProvider.notifier).removePhoto(p.path);
      },
      child: SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: CxRadii.brLg,
                child: CxLocalImage(
                  path: p.path,
                  width: 92,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: c.surfaceHigh,
                    child: Icon(Icons.broken_image_rounded,
                        color: c.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: CxType.caption.copyWith(color: c.textTertiary)),
          ],
        ),
      ),
    );
  }

  void _viewPhoto(ProgressPhoto p) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.cx;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(CxSpace.lg),
          child: ClipRRect(
            borderRadius: CxRadii.brXl,
            child: CxLocalImage(
              path: p.path,
              fit: BoxFit.contain,
              // Full-screen needs to say what happened, not just show a broken
              // tile: the photo is gone, and long-pressing the thumb clears it.
              placeholder: Container(
                color: c.surface,
                padding: const EdgeInsets.all(CxSpace.x2l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_rounded,
                        size: 40, color: c.textTertiary),
                    const SizedBox(height: CxSpace.md),
                    Text(
                      "This photo isn't on this device any more.",
                      textAlign: TextAlign.center,
                      style: CxType.bodySmall.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: CxSpace.xs),
                    Text(
                      'Long-press the thumbnail to remove it.',
                      textAlign: TextAlign.center,
                      style: CxType.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPhoto() async {
    try {
      final picker = ImagePicker();
      final img =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (img != null) {
        ref.read(progressPhotosProvider.notifier).addPhoto(img.path);
        CxHaptics.fire(CxHaptic.success);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Couldn't open the photo library on this device")),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Nutrition card — goal-aware targets + daily protein quick-log
// ---------------------------------------------------------------------------

/// One calorie band, one protein number (plan Phase 12.1 — explicitly not a
/// food database). Targets come from the user's own weight/height/age/sex/goal
/// via the nutrition engine, with honest pacing copy and zero crash-cut talk.
class _NutritionCard extends ConsumerWidget {
  const _NutritionCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    ref.watch(proteinProvider);
    final notifier = ref.read(proteinProvider.notifier);
    final targets = notifier.targets;
    final todayG = notifier.todayG;
    final progress = targets.proteinG == 0
        ? 0.0
        : (todayG / targets.proteinG).clamp(0.0, 1.0);
    final goalHit = todayG >= targets.proteinG;

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, color: c.ember, size: 20),
              const SizedBox(width: CxSpace.sm),
              Text("NUTRITION",
                  style: CxType.overline.copyWith(color: c.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showWhySheet(context, targets),
                child: Icon(Icons.info_outline_rounded,
                    size: 18, color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xs),
          Text(targets.strategy,
              style: CxType.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.lg),

          // Calorie band
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "${targets.caloriesLow}–${targets.caloriesHigh}",
                style: CxType.numL.copyWith(
                    color: c.textPrimary, fontWeight: FontWeight.w700),
              ),
              Text(" kcal/day",
                  style: CxType.bodySmall.copyWith(color: c.textTertiary)),
            ],
          ),
          Text(targets.pace,
              style: CxType.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.lg),
          Divider(color: c.border, height: 1),
          const SizedBox(height: CxSpace.lg),

          // Protein — the priority number
          Row(
            children: [
              Expanded(
                child: Text("PROTEIN — THE PRIORITY NUMBER",
                    style: CxType.overline.copyWith(color: c.textSecondary)),
              ),
              if (goalHit)
                Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: c.success, size: 16),
                  const SizedBox(width: 4),
                  Text("Hit",
                      style: CxType.caption.copyWith(
                          color: c.success, fontWeight: FontWeight.w600)),
                ]),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$todayG",
                  style: CxType.numL.copyWith(
                      color: c.textPrimary, fontWeight: FontWeight.w700)),
              Text(" / ${targets.proteinG} g",
                  style: CxType.bodySmall.copyWith(color: c.textTertiary)),
              const Spacer(),
              Text("~${targets.proteinPerKg} g/kg",
                  style: CxType.caption.copyWith(
                      color: c.textTertiary, fontFamily: CxFonts.mono)),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          CxProgressBar(
            value: progress,
            height: 8,
            accent: CxProgressAccent.ember,
          ),
          const SizedBox(height: CxSpace.lg),
          Row(
            children: [
              Expanded(
                child: CxButton(
                  label: "+10 g",
                  variant: CxButtonVariant.secondary,
                  haptic: CxHaptic.selection,
                  onPressed: () => notifier.log(10),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: CxButton(
                  label: "+25 g",
                  variant: CxButtonVariant.secondary,
                  haptic: CxHaptic.selection,
                  onPressed: () => notifier.log(25),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Expanded(
                child: CxButton(
                  label: "+40 g",
                  variant: CxButtonVariant.secondary,
                  haptic: CxHaptic.selection,
                  onPressed: () => notifier.log(40),
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              IconButton(
                tooltip: "Undo 10 g",
                onPressed: todayG > 0 ? () => notifier.log(-10) : null,
                icon: Icon(Icons.undo_rounded,
                    color: todayG > 0 ? c.textSecondary : c.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWhySheet(BuildContext context, NutritionTargets targets) {
    final c = context.cx;
    CxHaptics.fire(CxHaptic.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CxGlassBottomSheet(
        title: "Your nutrition targets",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Computed from your weight, height, age and goal — they update automatically as your weigh-ins change.",
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.lg),
            _whyRow(
                c,
                Icons.local_fire_department_rounded,
                "${targets.caloriesLow}–${targets.caloriesHigh} kcal/day",
                targets.pace),
            const SizedBox(height: CxSpace.md),
            _whyRow(
                c,
                Icons.egg_alt_rounded,
                "${targets.proteinG} g protein (~${targets.proteinPerKg} g/kg)",
                "Hit this daily — it's the number muscle growth actually hinges on."),
            const SizedBox(height: CxSpace.md),
            _whyRow(c, Icons.tune_rounded, "Self-correct", targets.adjustRule),
            const SizedBox(height: CxSpace.lg),
            Text(
              "General guidance, not medical or dietetic advice. Big changes or health conditions? Talk to a professional first.",
              style: CxType.caption.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: CxSpace.sm),
          ],
        ),
      ),
    );
  }

  Widget _whyRow(CxColorsExt c, IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: c.ember),
        const SizedBox(width: CxSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(body,
                  style: CxType.caption.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
