import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'cx_number_roll.dart';

/// A big, thumb-friendly numeric stepper. Giant mono numerals roll on change;
/// each press ticks a haptic. Built for the logging screen's fast path.
class CxStepper extends StatelessWidget {
  const CxStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 2.5,
    this.min = 0,
    this.max = 9999,
    this.decimals = 1,
    this.unitLabel,
    this.numberStyle,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final String? unitLabel;
  final TextStyle? numberStyle;

  void _bump(double delta) {
    final next = (value + delta).clamp(min, max);
    if (next != value) {
      CxHaptics.fire(CxHaptic.selection);
      onChanged(next.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => _bump(-step) : null,
          semanticLabel: 'Decrease',
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CxNumberRoll(
                value: value,
                decimals: decimals,
                style: numberStyle ?? CxType.numXL,
                color: c.textPrimary,
              ),
              if (unitLabel != null)
                Text(
                  unitLabel!,
                  style: CxType.caption.copyWith(color: c.textTertiary),
                ),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          onTap: value < max ? () => _bump(step) : null,
          semanticLabel: 'Increase',
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: c.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: CxSpace.x5l,
            height: CxSpace.x5l,
            child: Icon(
              icon,
              color: enabled ? c.textPrimary : c.textTertiary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
