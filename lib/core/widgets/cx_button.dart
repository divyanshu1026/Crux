import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum CxButtonVariant { primary, secondary, ghost, danger }

enum CxButtonSize { regular, large }

/// The Crux button. Chunky radius, a subtle spring press, one clear haptic,
/// and a guaranteed minimum tap target. Labels should say exactly what happens.
class CxButton extends StatefulWidget {
  const CxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CxButtonVariant.primary,
    this.size = CxButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.haptic = CxHaptic.selection,
  });

  final String label;
  final VoidCallback? onPressed;
  final CxButtonVariant variant;
  final CxButtonSize size;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final CxHaptic haptic;

  bool get _enabled => onPressed != null && !loading;

  @override
  State<CxButton> createState() => _RqButtonState();
}

class _RqButtonState extends State<CxButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!widget._enabled) return;
    CxHaptics.fire(widget.haptic);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final (bg, fg, border) = switch (widget.variant) {
      CxButtonVariant.primary => (c.ember, c.onEmber, null),
      CxButtonVariant.secondary => (c.surfaceHigh, c.textPrimary, null),
      CxButtonVariant.ghost => (
          Colors.transparent,
          c.textPrimary,
          c.border,
        ),
      CxButtonVariant.danger => (c.danger, c.onStatus, null),
    };

    final disabledBg = Color.alphaBlend(c.canvas.withValues(alpha: 0.6), bg);
    final effectiveBg = widget._enabled ? bg : disabledBg;
    final effectiveFg = widget._enabled ? fg : c.textTertiary;

    final height = switch (widget.size) {
      CxButtonSize.regular => CxSpace.minTap,
      CxButtonSize.large => 64.0,
    };
    final textStyle = switch (widget.size) {
      CxButtonSize.regular => CxType.label.copyWith(fontSize: 16),
      CxButtonSize.large => CxType.titleSmall,
    };

    final content = widget.loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: effectiveFg),
                const SizedBox(width: CxSpace.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: textStyle.copyWith(color: effectiveFg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: widget._enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget._enabled ? (_) => _setPressed(true) : null,
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? 0.97 : 1.0,
          duration: CxDuration.fast,
          curve: CxCurves.standard,
            child: AnimatedContainer(
            duration: CxDuration.fast,
            height: height,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: CxSpace.x2l),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: CxRadii.brLg,
              border: border != null ? Border.all(color: border) : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
