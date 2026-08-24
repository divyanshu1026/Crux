import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A rounded progress bar. Fill animates with a spring; ultraviolet for
/// progress/XP by default, ember for goal-gradient moments.
class CxProgressBar extends StatelessWidget {
  const CxProgressBar({
    super.key,
    required this.value,
    this.height = 14,
    this.accent = CxProgressAccent.ultraviolet,
    this.trackColor,
  }) : assert(value >= 0 && value <= 1);

  final double value;
  final double height;
  final CxProgressAccent accent;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final fill = accent == CxProgressAccent.ember ? c.ember : c.ultraviolet;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Container(
          height: height,
          color: trackColor ?? c.surfaceHighest,
          child: Align(
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final target = constraints.maxWidth * value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: target),
                  duration:
                      reduceMotion ? CxDuration.instant : CxDuration.slow,
                  curve: CxCurves.emphasized,
                  builder: (context, width, _) => Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum CxProgressAccent { ultraviolet, ember }
