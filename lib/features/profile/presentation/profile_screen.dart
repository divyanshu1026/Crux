import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Profile tab — identity, rank, lifetime stats, and the entry points to
/// Settings, Pro, and account actions. Numbers are the hero; chrome stays quiet.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final profile = ref.watch(userProfileProvider);
    final history = ref.watch(workoutHistoryProvider);

    final completed = history.where((w) => w.completed).toList();
    final totalVolume =
        completed.fold<double>(0, (sum, w) => sum + w.totalVolume);
    final totalPrs =
        completed.fold<int>(0, (sum, w) => sum + w.prsHit.length);

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              CxSpace.screen, CxSpace.md, CxSpace.screen, 120),
          children: [
            // --- Header: settings shortcut ------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile',
                    style: CxType.displayL.copyWith(color: c.textPrimary)),
                IconButton(
                  icon: Icon(Icons.settings_rounded, color: c.textSecondary),
                  tooltip: 'Settings',
                  onPressed: () => context.push(Routes.settings),
                ),
              ],
            ),
            const SizedBox(height: CxSpace.lg),

            // --- Identity card ------------------------------------------------
            _IdentityCard(profile: profile),
            const SizedBox(height: CxSpace.xl),

            // --- Lifetime stats ----------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Workouts',
                    value: '${completed.length}',
                    icon: Icons.fitness_center_rounded,
                    accent: c.ultraviolet,
                  ),
                ),
                const SizedBox(width: CxSpace.md),
                Expanded(
                  child: _StatTile(
                    label: 'Volume',
                    value: _compactVolume(totalVolume, profile.units),
                    icon: Icons.bar_chart_rounded,
                    accent: c.ember,
                  ),
                ),
                const SizedBox(width: CxSpace.md),
                Expanded(
                  child: _StatTile(
                    label: 'PRs',
                    value: '$totalPrs',
                    icon: Icons.emoji_events_rounded,
                    accent: c.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CxSpace.xl),

            // --- Pro upsell / status -----------------------------------------
            // hasProAccess, not isPro: a lapsed subscription should show the
            // upsell again rather than a Pro badge that no longer means
            // anything.
            if (!profile.hasProAccess)
              _ProUpsellCard(onTap: () => context.push(Routes.paywall))
            else
              _ProActiveCard(expiresAt: profile.proExpiresAt),
            const SizedBox(height: CxSpace.xl),

            // --- Actions ------------------------------------------------------
            _ActionTile(
              icon: Icons.calendar_month_rounded,
              label: 'My schedule',
              subtitle: 'View your week, edit days, sets and exercises',
              onTap: () => context.push(Routes.schedule),
            ),
            const SizedBox(height: CxSpace.md),
            _ActionTile(
              icon: Icons.tune_rounded,
              label: 'Settings',
              subtitle: 'Units, reminders, Zen mode, data',
              onTap: () => context.push(Routes.settings),
            ),
            // Internal design reference — a developer tool, not a feature.
            // Debug builds only so it never ships to the Play Store.
            if (kDebugMode) ...[
              const SizedBox(height: CxSpace.md),
              _ActionTile(
                icon: Icons.palette_rounded,
                label: 'Design gallery',
                subtitle: 'Every token, button and card',
                onTap: () => context.push(Routes.gallery),
              ),
            ],
            const SizedBox(height: CxSpace.md),
            _ActionTile(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              subtitle: 'Your data stays on this device',
              destructive: true,
              onTap: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  static String _compactVolume(double kg, String units) {
    final v = units == 'lbs' ? kg / 0.45359237 : kg;
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}t';
    return v.toStringAsFixed(0);
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CxGlassBottomSheet(
        title: 'Sign out?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You can sign back in anytime. Your training data stays on this device.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.xl),
            CxButton(
              label: 'Sign out',
              variant: CxButtonVariant.danger,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: CxSpace.sm),
            CxButton(
              label: 'Stay signed in',
              variant: CxButtonVariant.ghost,
              expand: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final authState = ref.watch(authProvider);
    final email = authState.email;
    return CxCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(CxSpace.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.ember, width: 2),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: c.surfaceHigh,
                  child: YorhartWidget(expression: profile.avatar, size: 56),
                ),
              ),
              const SizedBox(width: CxSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name.isEmpty ? 'Athlete' : profile.name,
                            style: CxType.title.copyWith(color: c.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.hasProAccess) ...[
                          const SizedBox(width: CxSpace.sm),
                          _ProBadge(),
                        ],
                      ],
                    ),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: CxType.caption.copyWith(color: c.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.ultraviolet.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _rankTitle(profile.level).toUpperCase(),
                            style: CxType.overline.copyWith(
                              color: c.ultraviolet,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: CxSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.ember.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: c.ember, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${profile.streak} DAY STREAK',
                                style: CxType.overline.copyWith(
                                  color: c.ember,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xl),
          // XP bar
          Row(
            children: [
              Text('LEVEL ${profile.level}',
                  style: CxType.overline.copyWith(color: c.ultraviolet)),
              const Spacer(),
              Text('${profile.xp} / ${profile.nextLevelXpThreshold} XP',
                  style: CxType.caption.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: CxSpace.sm),
          CxProgressBar(
            value: profile.xpProgress,
            height: 10,
            accent: CxProgressAccent.ultraviolet,
          ),
        ],
      ),
    );
  }
}

String _rankTitle(int level) {
  if (level <= 2) return 'Novice';
  if (level <= 4) return 'Apprentice';
  if (level <= 7) return 'Iron';
  if (level <= 10) return 'Steel';
  return 'Titan';
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: CxSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: c.ember.withValues(alpha: 0.15),
        borderRadius: CxRadii.brPill,
      ),
      child: Text('PRO',
          style: CxType.caption
              .copyWith(color: c.ember, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: CxSpace.md, vertical: CxSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: CxRadii.brLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: CxSpace.sm),
          Text(value,
              style: CxType.numM
                  .copyWith(color: c.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: CxType.caption.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}

class _ProUpsellCard extends StatelessWidget {
  const _ProUpsellCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CxPastelCard(
      tint: CxPastelTint.lilac,
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: cxPastelInk(), size: 32),
          const SizedBox(width: CxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Go Pro',
                    style: CxType.titleSmall.copyWith(color: cxPastelInk())),
                Text(
                  'Unlimited coach, advanced analytics, program library.',
                  style: CxType.caption
                      .copyWith(color: cxPastelInk(opacity: 0.75)),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: cxPastelInk()),
        ],
      ),
    );
  }
}

class _ProActiveCard extends StatelessWidget {
  const _ProActiveCard({this.expiresAt});

  final DateTime? expiresAt;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Play requires a way to reach subscription management from inside the app,
  /// and people look for it here before they look in the Play Store.
  Future<void> _manage() async {
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?package=com.cruxapp.crux',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final renews = expiresAt;
    return CxCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: c.ember, size: 28),
              const SizedBox(width: CxSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Crux Pro is active',
                        style:
                            CxType.titleSmall.copyWith(color: c.textPrimary)),
                    Text(
                      renews == null
                          ? 'Thanks for supporting the app.'
                          : 'Renews ${renews.day} ${_months[renews.month - 1]} '
                              '${renews.year}',
                      style: CxType.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          CxButton(
            label: 'Manage subscription',
            variant: CxButtonVariant.secondary,
            expand: true,
            icon: Icons.open_in_new_rounded,
            onPressed: _manage,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final color = destructive ? c.danger : c.textPrimary;
    return CxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(CxSpace.lg),
      child: Row(
        children: [
          Icon(icon, color: destructive ? c.danger : c.textSecondary),
          const SizedBox(width: CxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: CxType.titleSmall.copyWith(color: color)),
                Text(subtitle,
                    style: CxType.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}
