import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A mechanical-counter numeric display. When the value changes, each digit
/// rolls forward (through 9 → 0 on a carry) to its new value, like an odometer.
/// At rest every digit sits exactly on its value — no tilt, no jitter — and
/// tabular mono figures keep the width stable.
///
/// Respects reduced-motion: when animations are disabled the value snaps.
class CxNumberRoll extends StatefulWidget {
  const CxNumberRoll({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.minIntegerDigits = 1,
    this.color,
    this.duration = CxDuration.counterRoll,
    this.curve = CxCurves.standard,
  })  : assert(decimals >= 0),
        assert(minIntegerDigits >= 1);

  /// Value to display. Negative values are clamped to zero.
  final num value;

  /// Base text style. Must define a [TextStyle.fontSize]. Defaults to
  /// [CxType.numL].
  final TextStyle? style;

  /// Fixed number of fractional digits (e.g. `1` shows `62.5`).
  final int decimals;

  /// Minimum number of integer digits shown (leading zeros).
  final int minIntegerDigits;

  final Color? color;
  final Duration duration;
  final Curve curve;

  @override
  State<CxNumberRoll> createState() => _RqNumberRollState();
}

class _RqNumberRollState extends State<CxNumberRoll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _scaleInt;
  late int _from;
  late int _to;

  int _target() {
    final v = widget.value < 0 ? 0.0 : widget.value.toDouble();
    return (v * _scaleInt).round();
  }

  @override
  void initState() {
    super.initState();
    _scaleInt = _pow10(widget.decimals);
    _to = _target();
    _from = _to;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant CxNumberRoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decimals != widget.decimals) {
      _scaleInt = _pow10(widget.decimals);
    }
    final next = _target();
    if (next != _to) {
      _from = _to;
      _to = next;
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _intDigits(int scaledVal) {
    var ip = scaledVal ~/ _scaleInt;
    if (ip == 0) return 1;
    var n = 0;
    while (ip > 0) {
      n++;
      ip ~/= 10;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final style = (widget.style ?? CxType.numL).copyWith(color: widget.color);
    final fontSize = style.fontSize ?? 32;
    final lineHeight = fontSize * (style.height ?? 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 1.0 : widget.curve.transform(_controller.value);
        final integerDigits = [
          widget.minIntegerDigits,
          _intDigits(_from),
          _intDigits(_to),
        ].reduce((a, b) => a > b ? a : b);
        final columns = integerDigits + widget.decimals;

        final children = <Widget>[];
        for (var place = columns - 1; place >= 0; place--) {
          if (widget.decimals > 0 && place == widget.decimals - 1) {
            children.add(_StaticGlyph(glyph: '.', style: style));
          }
          final divisor = _pow10(place);
          final oldDigit = (_from ~/ divisor) % 10;
          final newDigit = (_to ~/ divisor) % 10;
          var delta = newDigit - oldDigit;
          if (delta < 0) delta += 10;
          children.add(
            _DigitColumn(
              oldDigit: oldDigit,
              delta: delta,
              t: t,
              lineHeight: lineHeight,
              style: style,
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      },
    );
  }
}

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}

/// One digit wheel. Rolls forward from [oldDigit] by [delta] steps as [t] goes
/// 0 → 1, wrapping through 9 → 0 on a carry.
class _DigitColumn extends StatelessWidget {
  const _DigitColumn({
    required this.oldDigit,
    required this.delta,
    required this.t,
    required this.lineHeight,
    required this.style,
  });

  final int oldDigit;
  final int delta;
  final double t;
  final double lineHeight;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final glyphWidth = (style.fontSize ?? 32) * 0.62;
    final localPos = delta * t;

    return ClipRect(
      child: SizedBox(
        width: glyphWidth,
        height: lineHeight,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -localPos * lineHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i <= delta; i++)
                  SizedBox(
                    width: glyphWidth,
                    height: lineHeight,
                    child: Center(
                      child: Text(
                        '${(oldDigit + i) % 10}',
                        style: style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticGlyph extends StatelessWidget {
  const _StaticGlyph({required this.glyph, required this.style});

  final String glyph;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(glyph, style: style);
  }
}
