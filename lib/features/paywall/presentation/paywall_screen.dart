import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/billing_service.dart';

/// Paywall (Phase 8.3). Honest annual-vs-monthly anchoring, no countdown timers,
/// no fake scarcity. Plain math, clear value, one tap to subscribe.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = kProAnnualId;
  bool _busy = false;

  /// Plans come from the store, so they load asynchronously and can come back
  /// empty (no Play services, products not published to this track, a device
  /// that can't buy anything).
  late Future<List<BillingPlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = ref.read(billingServiceProvider).plans();
  }

  static const _features = [
    ('Unlimited AI coaching', Icons.chat_bubble_rounded),
    ('Full history & advanced analytics', Icons.insights_rounded),
    ('Unlimited routines', Icons.list_alt_rounded),
    ('Program library', Icons.grid_view_rounded),
    ('Exclusive avatar gear', Icons.auto_awesome_rounded),
    ('AI weekly review', Icons.summarize_rounded),
  ];

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final outcome = await ref.read(billingServiceProvider).purchase(_selected);
    if (!mounted) return;
    setState(() => _busy = false);
    _handle(outcome);
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final outcome = await ref.read(billingServiceProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    _handle(outcome, restoring: true);
  }

  /// One place for every ending, because each one needs different words and
  /// only one of them is a success.
  void _handle(PurchaseOutcome outcome, {bool restoring = false}) {
    switch (outcome) {
      case PurchaseGranted(:final entitlement):
        // The server said yes; the app is only mirroring that.
        ref.read(userProfileProvider.notifier).applyServerEntitlement(
              isPro: entitlement.isPro,
              expiresAt: entitlement.expiresAt,
            );
        CxHaptics.fire(CxHaptic.prSlam);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(restoring
              ? 'Your Crux Pro subscription is back'
              : 'Welcome to Crux Pro'),
        ));

      case PurchaseCancelled():
        // They changed their mind. Saying anything would be nagging.
        break;

      case PurchasePending():
        _say(
          "Your payment is still going through. Pro unlocks by itself the "
          'moment it clears — no need to pay again.',
        );

      case PurchaseFailed(:final message, :final alreadyPaid):
        _say(alreadyPaid
            // Never imply a charged customer wasn't charged.
            ? '$message You have not been charged twice.'
            : message);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  /// Shown when the store has nothing to sell here — the web preview, a device
  /// without Play services, or products that aren't live on this track yet.
  /// Better to say so than to show a Subscribe button that can't work.
  Widget _unavailable(CxColorsExt c, BillingService billing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CxSpace.lg),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: CxRadii.brLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_rounded, color: c.textTertiary),
          const SizedBox(height: CxSpace.sm),
          Text(
            billing.isSupported
                ? "Google Play isn't offering the subscription on this device "
                    'right now. Check you\'re signed in to the Play Store and '
                    'try again.'
                : 'Crux Pro is purchased in the Android app.',
            textAlign: TextAlign.center,
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final billing = ref.read(billingServiceProvider);

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _restore,
            child: Text('Restore',
                style: CxType.label.copyWith(color: c.textSecondary)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: CxSpace.screen),
                children: [
                  const Center(
                    child: YorhartWidget(
                        expression: 'celebrating', size: 120, animate: true),
                  ),
                  const SizedBox(height: CxSpace.lg),
                  Text('Coach in your pocket',
                      textAlign: TextAlign.center,
                      style: CxType.displayL.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  Text(
                    'The whole app works free. Pro unlocks the coach and the '
                    'deep analytics that keep you progressing for years.',
                    textAlign: TextAlign.center,
                    style: CxType.bodySmall.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: CxSpace.x2l),

                  // Feature list
                  CxCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < _features.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: CxSpace.md),
                          Row(
                            children: [
                              Icon(_features[i].$2, color: c.ember, size: 20),
                              const SizedBox(width: CxSpace.lg),
                              Expanded(
                                child: Text(_features[i].$1,
                                    style: CxType.bodySmall
                                        .copyWith(color: c.textPrimary)),
                              ),
                              Icon(Icons.check_rounded,
                                  color: c.success, size: 20),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpace.x2l),

                  // Plans, priced by the store in the user's own currency.
                  FutureBuilder<List<BillingPlan>>(
                    future: _plansFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(CxSpace.xl),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final plans = snapshot.data ?? const <BillingPlan>[];
                      if (plans.isEmpty) return _unavailable(c, billing);
                      return Column(
                        children: [
                          for (final p in plans) ...[
                            _PlanTile(
                              plan: p,
                              selected: _selected == p.id,
                              onTap: () {
                                CxHaptics.fire(CxHaptic.selection);
                                setState(() => _selected = p.id);
                              },
                            ),
                            const SizedBox(height: CxSpace.md),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: CxSpace.sm),
                  Text(
                    'Billed through Google Play. Cancel anytime in Play Store → '
                    'Subscriptions. Renews automatically until you cancel.',
                    textAlign: TextAlign.center,
                    style: CxType.caption.copyWith(color: c.textTertiary),
                  ),
                  const SizedBox(height: CxSpace.xl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CxSpace.screen),
              child: FutureBuilder<List<BillingPlan>>(
                future: _plansFuture,
                builder: (context, snapshot) {
                  final canBuy = (snapshot.data ?? const []).isNotEmpty;
                  return CxButton(
                    label: _selected == kProAnnualId
                        ? 'Start annual plan'
                        : 'Start monthly plan',
                    expand: true,
                    loading: _busy,
                    haptic: CxHaptic.success,
                    // No point offering checkout the store can't open.
                    onPressed: (_busy || !canBuy) ? null : _subscribe,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  final BillingPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CxDuration.fast,
        padding: const EdgeInsets.all(CxSpace.lg),
        decoration: BoxDecoration(
          color: selected ? c.surfaceHighest : c.surface,
          borderRadius: CxRadii.brLg,
          border: Border.all(
            color: selected ? c.ember : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? c.ember : c.textTertiary,
            ),
            const SizedBox(width: CxSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.title,
                          style: CxType.titleSmall
                              .copyWith(color: c.textPrimary)),
                      if (plan.highlighted) ...[
                        const SizedBox(width: CxSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: CxSpace.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.ember.withValues(alpha: 0.15),
                            borderRadius: CxRadii.brPill,
                          ),
                          child: Text('SAVE 42%',
                              style: CxType.caption.copyWith(
                                  color: c.ember, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  if (plan.subtext != null)
                    Text(plan.subtext!,
                        style:
                            CxType.caption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(plan.price,
                    style: CxType.numM.copyWith(
                        color: c.textPrimary, fontWeight: FontWeight.bold)),
                Text(plan.period,
                    style: CxType.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
