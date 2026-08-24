import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// Bottom-navigation shell with a premium floating frosted-glass menu.
///
/// Primary actions stay in the lower two-thirds for one-handed reach.
/// The navigation bar floats above the content (using extendBody: true on Scaffold)
/// and uses BackdropFilter to blur scrolling content behind it.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth + onboarding gating is handled by the router (see app/router.dart);
    // by the time the shell renders, the user is authenticated and onboarded.
    final l10n = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final destinations = <_NavItem>[
      _NavItem(
        Icons.bolt_outlined,
        Icons.bolt_rounded,
        l10n.navToday,
        CxColors.ember,
      ),
      _NavItem(
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        l10n.navHistory,
        CxColors.ultraviolet,
      ),
      _NavItem(
        Icons.insights_outlined,
        Icons.insights_rounded,
        l10n.navDashboard,
        CxColors.ultraviolet,
      ),
      _NavItem(
        Icons.forum_outlined,
        Icons.forum_rounded,
        l10n.navCoach,
        CxColors.ember,
      ),
      _NavItem(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        l10n.navProfile,
        CxColors.ultraviolet,
      ),
    ];

    // Soft glass background color depending on theme brightness.
    final glassColor = isDark
        ? const Color(0xFF121214).withOpacity(0.85)
        : Colors.white.withOpacity(0.92);

    final borderColor = isDark
        ? const Color(0xFF232328)
        : const Color(0xFFECECEF);

    return Scaffold(
      extendBody: true, // Crucial: lets body content scroll behind the floating bar
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.07),
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth - CxSpace.sm * 2;
                  final itemWidth = totalWidth / destinations.length;
                  final activeIndex = navigationShell.currentIndex;
                  const circleSize = 44.0;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Sliding background circle with spring physics
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: CxCurves.spring,
                        left: CxSpace.sm + activeIndex * itemWidth + (itemWidth - circleSize) / 2,
                        width: circleSize,
                        height: circleSize,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white : const Color(0xFF1E1E22),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Navigation Items Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CxSpace.sm),
                        child: Row(
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              Expanded(
                                child: _NavButton(
                                  item: destinations[i],
                                  selected: activeIndex == i,
                                  onTap: () => _goBranch(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    CxHaptics.fire(CxHaptic.selection);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label, this.accentColor);
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accentColor;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final inactiveColor = isDark ? c.textTertiary : const Color(0xFF8E8E93);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: CxDuration.fast,
              curve: CxCurves.spring,
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(
                  begin: selected ? activeColor : inactiveColor,
                  end: selected ? activeColor : inactiveColor,
                ),
                builder: (context, color, child) {
                  return Icon(
                    selected ? item.activeIcon : item.icon,
                    color: color,
                    size: selected ? 24 : 22,
                  );
                },
              ),
            ),
            // Visually hidden text specifically for widget tests to find
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
