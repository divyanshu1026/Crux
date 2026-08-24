import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A selectable chip. Selection is signalled by fill AND a check glyph (never
/// color alone) so it stays colorblind-safe.
class CxChip extends StatelessWidget {
  const CxChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent = CxChipAccent.ultraviolet,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final CxChipAccent accent;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final accentColor =
        accent == CxChipAccent.ember ? c.ember : c.ultraviolet;
    final onAccent =
        accent == CxChipAccent.ember ? c.onEmber : c.onUltraviolet;

    final bg = selected ? accentColor : c.surfaceHigh;
    final fg = selected ? onAccent : c.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                CxHaptics.fire(CxHaptic.selection);
                onTap!();
              },
        child: AnimatedContainer(
          duration: CxDuration.fast,
          curve: CxCurves.standard,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: CxSpace.lg,
            vertical: CxSpace.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CxRadii.brPill,
            border: Border.all(
              color: selected ? accentColor : c.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: fg),
                const SizedBox(width: CxSpace.xs),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: CxSpace.xs),
              ],
              Text(label, style: CxType.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

enum CxChipAccent { ember, ultraviolet }

/// A small static tag rendered on a pastel card.
class CxTag extends StatelessWidget {
  const CxTag({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CxSpace.md,
        vertical: CxSpace.xs,
      ),
      decoration: BoxDecoration(
        color: CxColors.pastelInk.withValues(alpha: 0.08),
        borderRadius: CxRadii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14, color: CxColors.pastelInk.withValues(alpha: 0.8)),
            const SizedBox(width: CxSpace.xs),
          ],
          Text(
            label,
            style: CxType.caption
                .copyWith(color: CxColors.pastelInk.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
