import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A premium, custom-painted character widget for "Yorhart" — the Crux heart.
///
/// Supports multiple poses/attires to ensure a consistent, delightful, and
/// non-templated brand identity throughout the app.
class YorhartWidget extends StatefulWidget {
  const YorhartWidget({
    super.key,
    this.size = 160,
    this.expression = 'happy',
    this.animate = true,
  });

  final double size;

  /// The pose/expression of Yorhart.
  /// Allowed values: 'happy', 'determined', 'resting', 'weightlifting', 'coaching', 'celebrating'
  final String expression;

  final bool animate;

  @override
  State<YorhartWidget> createState() => _YorhartWidgetState();
}

class _YorhartWidgetState extends State<YorhartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool get _shouldAnimate =>
      widget.animate && (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST'));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Subtle breathing or floating animation depending on the pose.
    if (widget.expression == 'resting') {
      _animation = Tween<double>(begin: -6.0, end: 6.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    } else {
      _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }

    if (_shouldAnimate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant YorhartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      // Reconfigure animation if pose changes
      _controller.stop();
      if (widget.expression == 'resting') {
        _animation = Tween<double>(begin: -6.0, end: 6.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
      } else {
        _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
      }
      if (_shouldAnimate) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _YorhartPainter(
          expression: widget.expression,
          isDark: isDark,
        ),
      ),
    );

    if (widget.animate) {
      if (widget.expression == 'resting') {
        // Floating up and down on a cloud
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animation.value),
              child: child,
            );
          },
          child: child,
        );
      } else {
        // Gentle pulse
        return ScaleTransition(
          scale: _animation,
          child: child,
        );
      }
    }

    return child;
  }
}

class _YorhartPainter extends CustomPainter {
  _YorhartPainter({required this.expression, required this.isDark});

  final String expression;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Scaling factor to keep drawing proportional
    final scale = math.min(w, h) / 160.0;

    // -------------------------------------------------------------------------
    // 1. Draw Background Cloud for 'resting' pose
    // -------------------------------------------------------------------------
    if (expression == 'resting') {
      final cloudPaint = Paint()
        ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      // Draw overlapping circles to form a fluffy cloud
      final cloudCenter = Offset(w / 2, h * 0.75);
      canvas.drawCircle(cloudCenter, 35 * scale, cloudPaint);
      canvas.drawCircle(cloudCenter + Offset(-40 * scale, 5 * scale), 25 * scale, cloudPaint);
      canvas.drawCircle(cloudCenter + Offset(40 * scale, 5 * scale), 25 * scale, cloudPaint);
      canvas.drawCircle(cloudCenter + Offset(-20 * scale, -15 * scale), 28 * scale, cloudPaint);
      canvas.drawCircle(cloudCenter + Offset(20 * scale, -15 * scale), 28 * scale, cloudPaint);
    }

    // -------------------------------------------------------------------------
    // 2. Draw Legs
    // -------------------------------------------------------------------------
    final limbPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.9) : CxColors.pastelInk
      ..strokeWidth = 4.5 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shoeBlue = Paint()
      ..color = CxColors.ultraviolet
      ..style = PaintingStyle.fill;

    final shoeWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    if (expression == 'resting') {
      // Crossed legs resting on cloud
      // Left Leg
      final leftLeg = Path()
        ..moveTo(w * 0.42, h * 0.65)
        ..quadraticBezierTo(w * 0.35, h * 0.75, w * 0.32, h * 0.78);
      canvas.drawPath(leftLeg, limbPaint);
      // Right Leg (crossed over)
      final rightLeg = Path()
        ..moveTo(w * 0.58, h * 0.65)
        ..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.38, h * 0.76);
      canvas.drawPath(rightLeg, limbPaint);

      // Cute sleeping sneakers
      canvas.drawCircle(Offset(w * 0.32, h * 0.78), 8 * scale, shoeBlue);
      canvas.drawCircle(Offset(w * 0.32, h * 0.78), 4 * scale, shoeWhite);
      canvas.drawCircle(Offset(w * 0.38, h * 0.76), 8 * scale, shoeBlue);
      canvas.drawCircle(Offset(w * 0.38, h * 0.76), 4 * scale, shoeWhite);
    } else {
      // Standing legs
      // Left Leg
      canvas.drawLine(Offset(w * 0.42, h * 0.65), Offset(w * 0.4, h * 0.85), limbPaint);
      // Right Leg
      canvas.drawLine(Offset(w * 0.58, h * 0.65), Offset(w * 0.6, h * 0.85), limbPaint);

      // Shorts
      final shortsPaint = Paint()
        ..color = isDark ? CxColors.darkSurfaceHighest : CxColors.pastelInk
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.36, h * 0.62, w * 0.28, h * 0.08),
          Radius.circular(4 * scale),
        ),
        shortsPaint,
      );

      // Sneakers
      final leftShoeRect = Rect.fromLTWH(w * 0.34, h * 0.83, w * 0.09, h * 0.05);
      canvas.drawRRect(RRect.fromRectAndRadius(leftShoeRect, Radius.circular(6 * scale)), shoeBlue);
      canvas.drawRRect(RRect.fromRectAndRadius(leftShoeRect.deflate(2 * scale), Radius.circular(4 * scale)), shoeWhite);

      final rightShoeRect = Rect.fromLTWH(w * 0.57, h * 0.83, w * 0.09, h * 0.05);
      canvas.drawRRect(RRect.fromRectAndRadius(rightShoeRect, Radius.circular(6 * scale)), shoeBlue);
      canvas.drawRRect(RRect.fromRectAndRadius(rightShoeRect.deflate(2 * scale), Radius.circular(4 * scale)), shoeWhite);
    }

    // -------------------------------------------------------------------------
    // 3. Draw Heart Body
    // -------------------------------------------------------------------------
    final heartPaint = Paint()
      ..color = CxColors.ember
      ..style = PaintingStyle.fill;

    final heartPath = Path();
    final hW = w;
    final hH = h;

    // Draw a perfectly proportioned heart centered in the 160x160 canvas
    heartPath.moveTo(hW / 2, hH * 0.68);
    // Left curve
    heartPath.cubicTo(
      hW * 0.15,
      hH * 0.52,
      hW * 0.08,
      hH * 0.22,
      hW / 2,
      hH * 0.18,
    );
    // Right curve
    heartPath.cubicTo(
      hW * 0.92,
      hH * 0.22,
      hW * 0.85,
      hH * 0.52,
      hW / 2,
      hH * 0.68,
    );
    canvas.drawPath(heartPath, heartPaint);

    // -------------------------------------------------------------------------
    // 4. Draw Arms & Smartwatch
    // -------------------------------------------------------------------------
    if (expression == 'resting') {
      // Arms tucked behind head
      final leftArm = Path()
        ..moveTo(w * 0.25, h * 0.35)
        ..quadraticBezierTo(w * 0.18, h * 0.25, w * 0.3, h * 0.2);
      canvas.drawPath(leftArm, limbPaint);

      final rightArm = Path()
        ..moveTo(w * 0.75, h * 0.35)
        ..quadraticBezierTo(w * 0.82, h * 0.25, w * 0.7, h * 0.2);
      canvas.drawPath(rightArm, limbPaint);
    } else if (expression == 'weightlifting') {
      // Arms raised high holding barbell
      canvas.drawLine(Offset(w * 0.25, h * 0.35), Offset(w * 0.18, h * 0.12), limbPaint);
      canvas.drawLine(Offset(w * 0.75, h * 0.35), Offset(w * 0.82, h * 0.12), limbPaint);

      // Barbell
      final barPaint = Paint()
        ..color = isDark ? Colors.white70 : Colors.black87
        ..strokeWidth = 5 * scale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w * 0.05, h * 0.1), Offset(w * 0.95, h * 0.1), barPaint);

      // Barbell Plates
      final platePaint = Paint()
        ..color = CxColors.darkSurfaceHighest
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.04, w * 0.05, h * 0.12), Radius.circular(4 * scale)), platePaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.9, h * 0.04, w * 0.05, h * 0.12), Radius.circular(4 * scale)), platePaint);
    } else if (expression == 'celebrating') {
      // Arms raised high in excitement
      final leftArm = Path()
        ..moveTo(w * 0.25, h * 0.38)
        ..quadraticBezierTo(w * 0.15, h * 0.25, w * 0.18, h * 0.15);
      canvas.drawPath(leftArm, limbPaint);

      final rightArm = Path()
        ..moveTo(w * 0.75, h * 0.38)
        ..quadraticBezierTo(w * 0.85, h * 0.25, w * 0.82, h * 0.15);
      canvas.drawPath(rightArm, limbPaint);

      // Draw party hat
      final hatPaint = Paint()
        ..color = CxColors.ultraviolet
        ..style = PaintingStyle.fill;
      final hatPath = Path()
        ..moveTo(w * 0.42, h * 0.18)
        ..lineTo(w * 0.58, h * 0.18)
        ..lineTo(w * 0.5, h * 0.05)
        ..close();
      canvas.drawPath(hatPath, hatPaint);
      // Hat pom-pom
      canvas.drawCircle(Offset(w * 0.5, h * 0.04), 5 * scale, Paint()..color = CxColors.warning);
    } else if (expression == 'coaching') {
      // One arm holding clipboard, other arm pointing
      // Left arm holding clipboard
      final leftArm = Path()
        ..moveTo(w * 0.25, h * 0.4)
        ..quadraticBezierTo(w * 0.15, h * 0.45, w * 0.22, h * 0.55);
      canvas.drawPath(leftArm, limbPaint);

      // Clipboard
      final boardPaint = Paint()
        ..color = Colors.brown.shade400
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.5, w * 0.15, h * 0.16), Radius.circular(4 * scale)), boardPaint);
      // Paper on board
      canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.52, w * 0.11, h * 0.12), Paint()..color = Colors.white);

      // Right arm pointing
      final rightArm = Path()
        ..moveTo(w * 0.75, h * 0.4)
        ..quadraticBezierTo(w * 0.88, h * 0.38, w * 0.92, h * 0.35);
      canvas.drawPath(rightArm, limbPaint);
    } else {
      // Standing normal / happy / determined
      // Left arm with smartwatch
      final leftArm = Path()
        ..moveTo(w * 0.25, h * 0.42)
        ..quadraticBezierTo(w * 0.15, h * 0.48, w * 0.18, h * 0.58);
      canvas.drawPath(leftArm, limbPaint);

      // Smartwatch
      final watchPaint = Paint()
        ..color = isDark ? Colors.white : CxColors.pastelInk
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.51, w * 0.05, w * 0.05),
          Radius.circular(2 * scale),
        ),
        watchPaint,
      );
      // Watch screen (Ember dot)
      canvas.drawCircle(Offset(w * 0.165, h * 0.525), 1.5 * scale, Paint()..color = CxColors.ember);

      // Right arm
      final rightArm = Path()
        ..moveTo(w * 0.75, h * 0.42)
        ..quadraticBezierTo(w * 0.85, h * 0.48, w * 0.82, h * 0.58);
      canvas.drawPath(rightArm, limbPaint);
    }

    // -------------------------------------------------------------------------
    // 5. Draw Headband (attire for gym/determined poses)
    // -------------------------------------------------------------------------
    if (expression == 'determined' || expression == 'weightlifting') {
      final bandPaint = Paint()
        ..color = CxColors.ultraviolet
        ..style = PaintingStyle.fill;
      final bandRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.23, w * 0.56, h * 0.08),
        Radius.circular(4 * scale),
      );
      canvas.drawRRect(bandRect, bandPaint);

      final bandStripe = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(w * 0.28, h * 0.25, w * 0.44, h * 0.02),
        bandStripe,
      );
    }

    // -------------------------------------------------------------------------
    // 6. Draw Face (Eyes, Mouth, Cheeks)
    // -------------------------------------------------------------------------
    final facePaint = Paint()
      ..color = isDark ? CxColors.darkCanvas : CxColors.pastelInk
      ..style = PaintingStyle.fill;

    // Blush Cheeks (always cute)
    final blushPaint = Paint()..color = Colors.pinkAccent.withOpacity(0.35);
    canvas.drawCircle(Offset(w * 0.32, h * 0.45), 7 * scale, blushPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.45), 7 * scale, blushPaint);

    if (expression == 'resting') {
      // Peaceful sleeping eyes (curved arcs)
      final eyePaint = Paint()
        ..color = isDark ? Colors.white.withOpacity(0.9) : CxColors.pastelInk
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final leftEye = Path()
        ..moveTo(w * 0.36, h * 0.4)
        ..quadraticBezierTo(w * 0.4, h * 0.44, w * 0.44, h * 0.4);
      canvas.drawPath(leftEye, eyePaint);

      final rightEye = Path()
        ..moveTo(w * 0.56, h * 0.4)
        ..quadraticBezierTo(w * 0.6, h * 0.44, w * 0.64, h * 0.4);
      canvas.drawPath(rightEye, eyePaint);

      // Soft smile
      final mouthPaint = Paint()
        ..color = isDark ? Colors.white.withOpacity(0.9) : CxColors.pastelInk
        ..strokeWidth = 2.5 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mouth = Path()
        ..moveTo(w * 0.46, h * 0.5)
        ..quadraticBezierTo(w * 0.5, h * 0.54, w * 0.54, h * 0.5);
      canvas.drawPath(mouth, mouthPaint);
    } else if (expression == 'determined' || expression == 'weightlifting') {
      // Determined eyes
      canvas.drawCircle(Offset(w * 0.39, h * 0.42), 5 * scale, facePaint);
      canvas.drawCircle(Offset(w * 0.61, h * 0.42), 5 * scale, facePaint);

      // Slanted angry/determined eyebrows
      final browPaint = Paint()
        ..color = isDark ? CxColors.darkCanvas : CxColors.pastelInk
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w * 0.33, h * 0.36), Offset(w * 0.43, h * 0.39), browPaint);
      canvas.drawLine(Offset(w * 0.67, h * 0.36), Offset(w * 0.57, h * 0.39), browPaint);

      // Determined mouth (straight line)
      canvas.drawLine(Offset(w * 0.46, h * 0.52), Offset(w * 0.54, h * 0.52), browPaint);

      // Sweat drops
      final sweatPaint = Paint()
        ..color = Colors.lightBlueAccent
        ..style = PaintingStyle.fill;
      final sweatPath = Path()
        ..moveTo(w * 0.26, h * 0.32)
        ..quadraticBezierTo(w * 0.24, h * 0.38, w * 0.26, h * 0.4)
        ..quadraticBezierTo(w * 0.28, h * 0.38, w * 0.26, h * 0.32);
      canvas.drawPath(sweatPath, sweatPaint);
    } else if (expression == 'coaching') {
      // Wearing cute round glasses
      final glassesPaint = Paint()
        ..color = isDark ? Colors.white70 : CxColors.pastelInk
        ..strokeWidth = 3 * scale
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(w * 0.38, h * 0.41), 12 * scale, glassesPaint);
      canvas.drawCircle(Offset(w * 0.62, h * 0.41), 12 * scale, glassesPaint);
      // Bridge
      canvas.drawLine(Offset(w * 0.46, h * 0.41), Offset(w * 0.54, h * 0.41), glassesPaint);

      // Normal eyes inside glasses
      canvas.drawCircle(Offset(w * 0.38, h * 0.41), 4 * scale, facePaint);
      canvas.drawCircle(Offset(w * 0.62, h * 0.41), 4 * scale, facePaint);

      // Smile
      final mouthPaint = Paint()
        ..color = isDark ? CxColors.darkCanvas : CxColors.pastelInk
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mouth = Path()
        ..moveTo(w * 0.44, h * 0.51)
        ..quadraticBezierTo(w * 0.5, h * 0.56, w * 0.56, h * 0.51);
      canvas.drawPath(mouth, mouthPaint);
    } else {
      // Normal happy face
      canvas.drawCircle(Offset(w * 0.39, h * 0.42), 5 * scale, facePaint);
      canvas.drawCircle(Offset(w * 0.61, h * 0.42), 5 * scale, facePaint);

      final mouthPaint = Paint()
        ..color = isDark ? CxColors.darkCanvas : CxColors.pastelInk
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mouth = Path()
        ..moveTo(w * 0.44, h * 0.51)
        ..quadraticBezierTo(w * 0.5, h * 0.56, w * 0.56, h * 0.51);
      canvas.drawPath(mouth, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _YorhartPainter oldDelegate) {
    return oldDelegate.expression != expression || oldDelegate.isDark != isDark;
  }
}
