import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A neutral surface card that sits on the dark canvas.
class CxCard extends StatelessWidget {
  const CxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CxSpace.xl),
    this.onTap,
    this.elevated = false,
    this.border = true,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;
  final bool border;

  /// Overrides the neutral surface — for cards that carry a status tint (a PR
  /// celebration, a warning). Null keeps the theme surface, which is what
  /// almost every card should use.
  final Color? backgroundColor;

  /// Overrides the border colour. Ignored when [border] is false.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final decoration = BoxDecoration(
      color: backgroundColor ?? c.surface,
      borderRadius: CxRadii.brXl,
      border: border ? Border.all(color: borderColor ?? c.border) : null,
      boxShadow: elevated ? CxShadows.card : CxShadows.none,
    );

    final body = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: body);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: CxRadii.brXl,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: CxRadii.brXl,
          onTap: onTap,
          child: body,
        ),
      ),
    );
  }
}

enum CxPastelTint { lilac, cream, mint }

/// A tactile pastel card that floats on the dark canvas — used for plan/content
/// chips and program day cards. Always renders dark ink for AA contrast.
class CxPastelCard extends StatelessWidget {
  const CxPastelCard({
    super.key,
    required this.child,
    this.tint = CxPastelTint.lilac,
    this.padding = const EdgeInsets.all(CxSpace.xl),
    this.onTap,
  });

  final Widget child;
  final CxPastelTint tint;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final color = switch (tint) {
      CxPastelTint.lilac => c.lilac,
      CxPastelTint.cream => c.cream,
      CxPastelTint.mint => c.mint,
    };

    final decoration = BoxDecoration(
      color: color,
      borderRadius: CxRadii.brXl,
      boxShadow: CxShadows.floating,
    );

    final body = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: body);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: CxRadii.brXl,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: CxRadii.brXl,
          splashColor: CxColors.pastelInk.withValues(alpha: 0.06),
          highlightColor: CxColors.pastelInk.withValues(alpha: 0.04),
          onTap: onTap,
          child: body,
        ),
      ),
    );
  }
}

/// Ink color to use for text/icons on a [CxPastelCard].
Color cxPastelInk({double opacity = 1}) =>
    CxColors.pastelInk.withValues(alpha: opacity);
