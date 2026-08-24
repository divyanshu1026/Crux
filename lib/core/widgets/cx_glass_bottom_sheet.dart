import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'cx_button.dart';

/// A premium frosted-glass bottom sheet that implements the "Gentler Streak"
/// style. Uses [BackdropFilter] to blur the underlying screen content, creating
/// a tactile, floating glass aesthetic.
class CxGlassBottomSheet extends StatelessWidget {
  const CxGlassBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onActionPressed,
    this.actionLoading = false,
    this.headerIcon,
    this.headerIconColor,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool actionLoading;
  final IconData? headerIcon;
  final Color? headerIconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Soft glass background color depending on theme brightness.
    final glassColor = isDark
        ? CxColors.darkSurface.withValues(alpha: 0.75)
        : CxColors.lightSurface.withValues(alpha: 0.82);

    final borderColor = isDark
        ? CxColors.darkBorder.withValues(alpha: 0.4)
        : CxColors.lightBorder.withValues(alpha: 0.5);

    // Lift the sheet above the on-screen keyboard so a focused field inside it
    // stays visible. Without this the content keeps its bottom-of-screen
    // position and the keyboard covers it. Requires `isScrollControlled: true`
    // on the showModalBottomSheet call, otherwise the sheet is capped at half
    // the screen and can't grow.
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomPad = keyboard > 0
        ? keyboard + CxSpace.md
        : media.padding.bottom + CxSpace.xl;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(CxRadii.xl),
          topRight: Radius.circular(CxRadii.xl),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(CxRadii.xl),
                topRight: Radius.circular(CxRadii.xl),
              ),
              border: Border(
                top: BorderSide(color: borderColor, width: 1.5),
                left: BorderSide(color: borderColor, width: 0.5),
                right: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              CxSpace.screen,
              CxSpace.md,
              CxSpace.screen,
              bottomPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: CxSpace.xl),

                // Optional Header Icon
                if (headerIcon != null) ...[
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (headerIconColor ?? c.ember).withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        headerIcon,
                        size: 32,
                        color: headerIconColor ?? c.ember,
                      ),
                    ),
                  ),
                  const SizedBox(height: CxSpace.md),
                ],

                // Title
                Text(
                  title,
                  style: CxType.headline.copyWith(color: c.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CxSpace.xl),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: child,
                  ),
                ),

                // Bottom Action Button
                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(height: CxSpace.xl),
                  CxButton(
                    label: actionLabel!,
                    onPressed: onActionPressed,
                    loading: actionLoading,
                    expand: true,
                    size: CxButtonSize.large,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the premium frosted-glass bottom sheet.
Future<T?> showRqGlassBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  String? actionLabel,
  VoidCallback? onActionPressed,
  bool actionLoading = false,
  IconData? headerIcon,
  Color? headerIconColor,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    elevation: 0,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (context) => CxGlassBottomSheet(
      title: title,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      actionLoading: actionLoading,
      headerIcon: headerIcon,
      headerIconColor: headerIconColor,
      child: child,
    ),
  );
}
