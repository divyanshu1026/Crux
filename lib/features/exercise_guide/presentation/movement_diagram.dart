import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../domain/movement_pose.dart';

/// An animated side-on diagram of how a movement is performed.
///
/// Drawn in code rather than shipped as video or artwork: it is a few KB,
/// works with no connection in a gym basement, follows the app's theme, and
/// stays sharp at any size. It also does the one thing footage is bad at —
/// showing the common mistake and the correct position in the same frame.
class MovementDiagram extends StatefulWidget {
  const MovementDiagram({
    super.key,
    required this.pattern,
    this.showGhost = true,
    this.height = 200,
  });

  final MovementPattern pattern;

  /// Draw the "watch for" error behind the correct figure.
  final bool showGhost;
  final double height;

  @override
  State<MovementDiagram> createState() => _MovementDiagramState();
}

class _MovementDiagramState extends State<MovementDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final pattern = widget.pattern;

    return Semantics(
      label: '${pattern.name} demonstration. ${pattern.topLabel} to '
          '${pattern.bottomLabel}.',
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: CxRadii.brLg,
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Ease so the figure slows at both ends of the rep, which is
                  // where the position actually matters.
                  final t = Curves.easeInOutSine.transform(_controller.value);
                  return CustomPaint(
                    painter: _MovementPainter(
                      pattern: pattern,
                      t: t,
                      showGhost: widget.showGhost,
                      figure: c.textPrimary,
                      accent: c.ember,
                      ghost: c.warning,
                      floor: c.border,
                      labelColor: c.textTertiary,
                      labelStyle: CxType.caption,
                    ),
                  );
                },
              ),
            ),
            // Phase label, driven by which half of the rep we're in.
            Positioned(
              left: CxSpace.md,
              top: CxSpace.md,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final label = _controller.value < 0.5
                      ? pattern.topLabel
                      : pattern.bottomLabel;
                  return Text(
                    label,
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  );
                },
              ),
            ),
            Positioned(
              right: CxSpace.xs,
              top: CxSpace.xs,
              child: IconButton(
                tooltip: _playing ? 'Pause' : 'Play',
                iconSize: 20,
                color: c.textTertiary,
                onPressed: _toggle,
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Badge { good, bad }

/// Shared framing so both panels draw at one scale.
class _Fit {
  const _Fit({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.scale,
    required this.padBottom,
  });
  final double minX, maxX, minY, scale, padBottom;
}

class _MovementPainter extends CustomPainter {
  _MovementPainter({
    required this.pattern,
    required this.t,
    required this.showGhost,
    required this.figure,
    required this.accent,
    required this.ghost,
    required this.floor,
    required this.labelColor,
    required this.labelStyle,
  });

  final MovementPattern pattern;
  final double t;
  final bool showGhost;
  final Color figure;
  final Color accent;
  final Color ghost;
  final Color floor;
  final Color labelColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final hasGhost = showGhost && pattern.watchFor != null;

    // Side by side, not overlaid. Drawing the mistake on top of the correct
    // figure just reads as a person with four legs; putting them next to each
    // other is what makes the difference legible at a glance.
    //
    // Both panels are measured together so they share one scale. Sizing each
    // to its own bounds made the compact "wrong" pose render half again as
    // large as the correct one, which is the opposite of a fair comparison.
    final allPoses = <Pose>[
      pattern.top,
      pattern.bottom,
      if (hasGhost) pattern.watchFor!.pose,
    ];
    final metrics = _fit(allPoses, hasGhost ? size.width / 2 : size.width, size.height);

    if (!hasGhost) {
      _drawPanel(
        canvas,
        Rect.fromLTWH(0, 0, size.width, size.height),
        metrics,
        shown: pattern.at(t),
        color: figure,
      );
      return;
    }

    final half = size.width / 2;
    _drawPanel(
      canvas,
      Rect.fromLTWH(0, 0, half, size.height),
      metrics,
      shown: pattern.at(t),
      color: figure,
    );
    _drawPanel(
      canvas,
      Rect.fromLTWH(half, 0, half, size.height),
      metrics,
      shown: pattern.watchFor!.pose,
      color: ghost,
      heading: 'Common mistake',
      badge: _Badge.bad,
      caption: pattern.watchFor!.label,
    );

    canvas.drawLine(
      Offset(half, 16),
      Offset(half, size.height - 16),
      Paint()
        ..color = floor
        ..strokeWidth = 1,
    );
  }

  /// Bounds across every pose either panel can show, plus the scale that fits
  /// them into one panel of [panelWidth] x [height].
  _Fit _fit(List<Pose> poses, double panelWidth, double height) {
    var minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (final p in poses) {
      final (a, b, c, d) = Skeleton.fromPose(p).bounds();
      minX = math.min(minX, a);
      maxX = math.max(maxX, b);
      minY = math.min(minY, c);
      maxY = math.max(maxY, d);
    }
    const padTop = 30.0, padBottom = 42.0, padX = 16.0;
    final scale = math.min(
      (panelWidth - padX * 2) / (maxX - minX),
      (height - padTop - padBottom) / (maxY - minY),
    );
    return _Fit(minX: minX, maxX: maxX, minY: minY, scale: scale, padBottom: padBottom);
  }

  void _drawPanel(
    Canvas canvas,
    Rect rect,
    _Fit fit, {
    required Pose shown,
    required Color color,
    String? heading,
    _Badge? badge,
    String? caption,
  }) {
    final scale = fit.scale;
    final originX =
        rect.left + rect.width / 2 - ((fit.minX + fit.maxX) / 2) * scale;
    final originY = rect.bottom - fit.padBottom + fit.minY * scale;
    Offset px(Offset p) =>
        Offset(originX + p.dx * scale, originY - p.dy * scale);

    _drawFloor(canvas, rect, originY);
    _drawFigure(
      canvas,
      Skeleton.fromPose(shown),
      px,
      scale,
      color: color,
      strokeWidth: math.max(2.5, scale * 0.07),
      drawLoad: true,
    );
    if (heading != null) _drawHeading(canvas, rect, heading, badge);
    if (caption != null) _drawCaption(canvas, rect, caption);
  }

  /// Heading sits top-left so it never collides with the play/pause control
  /// in the card's top-right corner.
  void _drawHeading(Canvas canvas, Rect rect, String text, _Badge? badge) {
    var x = rect.left + 12.0;
    if (badge != null) {
      _drawBadge(canvas, Offset(x + 7, rect.top + 19), badge);
      x += 20;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 40);
    painter.paint(canvas, Offset(x, rect.top + 19 - painter.height / 2));
  }

  void _drawBadge(Canvas canvas, Offset centre, _Badge badge) {
    final good = badge == _Badge.good;
    final colour = good ? accent : ghost;
    canvas.drawCircle(
      centre,
      9,
      Paint()..color = colour.withValues(alpha: 0.16),
    );
    final tick = Paint()
      ..color = colour
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (good) {
      canvas.drawLine(centre + const Offset(-4, 0), centre + const Offset(-1, 3.5), tick);
      canvas.drawLine(centre + const Offset(-1, 3.5), centre + const Offset(4.5, -3.5), tick);
    } else {
      canvas.drawLine(centre + const Offset(-3.5, -3.5), centre + const Offset(3.5, 3.5), tick);
      canvas.drawLine(centre + const Offset(3.5, -3.5), centre + const Offset(-3.5, 3.5), tick);
    }
  }

  void _drawFloor(Canvas canvas, Rect rect, double y) {
    final paint = Paint()
      ..color = floor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(rect.left + 14, y),
      Offset(rect.right - 14, y),
      paint,
    );
  }

  void _drawFigure(
    Canvas canvas,
    Skeleton s,
    Offset Function(Offset) px,
    double scale, {
    required Color color,
    required double strokeWidth,
    required bool drawLoad,
  }) {
    final bone = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void line(Offset a, Offset b) => canvas.drawLine(px(a), px(b), bone);

    line(s.heel, s.toe); // foot
    line(s.ankle, s.knee);
    line(s.knee, s.hip);
    line(s.hip, s.shoulder);
    line(s.shoulder, s.elbow);
    line(s.elbow, s.hand);

    canvas.drawCircle(
      px(s.head),
      Skeleton.headRadius * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (!drawLoad) return;
    _drawLoad(canvas, s, px, scale, strokeWidth);
  }

  void _drawLoad(
    Canvas canvas,
    Skeleton s,
    Offset Function(Offset) px,
    double scale,
    double strokeWidth,
  ) {
    final loadPaint = Paint()
      ..color = accent
      ..strokeWidth = strokeWidth * 1.15
      ..strokeCap = StrokeCap.round;

    switch (pattern.load) {
      case LoadStyle.barbellBack:
        // Bar across the upper back, drawn end-on as a short disc.
        final centre = px(s.shoulder);
        canvas.drawCircle(centre, strokeWidth * 1.5, loadPaint);
        // Bar path: a vertical guide showing the bar should travel straight.
        final guide = Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..strokeWidth = 1.2;
        _dashedLine(
          canvas,
          Offset(centre.dx, centre.dy - scale * 0.35),
          Offset(centre.dx, px(s.ankle).dy),
          guide,
        );
      case LoadStyle.barbellHands:
      case LoadStyle.dumbbellHands:
        final hand = px(s.hand);
        canvas.drawCircle(hand, strokeWidth * 1.5, loadPaint);
        final guide = Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..strokeWidth = 1.2;
        _dashedLine(
          canvas,
          Offset(hand.dx, hand.dy - scale * 0.3),
          Offset(hand.dx, px(s.ankle).dy),
          guide,
        );
      case LoadStyle.dumbbellChest:
        canvas.drawCircle(px(s.hand), strokeWidth * 1.6, loadPaint);
      case LoadStyle.none:
        break;
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0, gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + dir * travelled, a + dir * end, paint);
      travelled = end + gap;
    }
  }

  void _drawCaption(Canvas canvas, Rect rect, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(color: labelColor, fontSize: 10.5),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 20);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.bottom - painter.height - 6,
      ),
    );
  }

  @override
  bool shouldRepaint(_MovementPainter old) =>
      old.t != t ||
      old.pattern.id != pattern.id ||
      old.showGhost != showGhost ||
      old.figure != figure;
}
