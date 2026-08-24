import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../core/widgets/widgets.dart';

/// A shared, non-sad placeholder used by the shell tabs until each feature is
/// built. Empty states are invitations to act, not dead ends.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.accent = CxColors.ultraviolet,
    this.yorhartExpression,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final String? yorhartExpression;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CxSpace.x3l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (yorhartExpression != null)
                  YorhartWidget(
                    expression: yorhartExpression!,
                    size: 140,
                  )
                else
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(CxRadii.x2l),
                    ),
                    child: Icon(icon, size: 40, color: accent),
                  ),
                const SizedBox(height: CxSpace.x3l),
                Text(
                  title,
                  style: CxType.displayL.copyWith(color: c.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CxSpace.md),
                Text(
                  message,
                  style: CxType.body.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
