import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_verifier.dart';

/// Play Console product ids. These must match the subscription ids created in
/// the Play Console exactly, or `queryProductDetails` returns them as "not
/// found" and the paywall shows nothing.
const kProMonthlyId = 'crux_pro_monthly';
const kProAnnualId = 'crux_pro_annual';
const kProProductIds = {kProMonthlyId, kProAnnualId};

/// A subscription plan as the store describes it.
///
/// Price comes from the store, never from us: Play requires the user's own
/// currency and local price, and hardcoding "$4.99" is both wrong for most of
/// the world and a policy problem.
@immutable
class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    this.subtext,
    this.highlighted = false,
  });

  final String id;
  final String title;
  final String price;
  final String period;
  final String? subtext;
  final bool highlighted;
}

/// What came back from a checkout attempt.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// Payment cleared and the server granted Pro.
class PurchaseGranted extends PurchaseOutcome {
  const PurchaseGranted(this.entitlement);
  final Entitlement entitlement;
}

/// The user backed out. Not an error — say nothing.
class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// Payment is still clearing (UPI mandates, slow cards, "pending" purchases).
/// Pro is not granted yet and will arrive on its own.
class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

/// Something went wrong. [message] is safe to show; [alreadyPaid] is true when
/// the money moved but we couldn't confirm it — never tell those users the
/// purchase failed.
class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed(this.message, {this.alreadyPaid = false});
  final String message;
  final bool alreadyPaid;
}

/// Provider-agnostic billing surface. The store SDK lives behind this so the
/// paywall never imports it.
abstract interface class BillingService {
  /// True when this build can actually sell anything.
  bool get isSupported;

  /// Plans for this user's region, priced by the store.
  Future<List<BillingPlan>> plans();

  /// Starts checkout for [planId].
  Future<PurchaseOutcome> purchase(String planId);

  /// Re-checks the store for an existing subscription (new device, reinstall).
  Future<PurchaseOutcome> restore();

  /// Releases any store listeners.
  void dispose();
}

/// Google Play Billing.
///
/// The shape that matters: a purchase is only ever granted by the server. The
/// store tells us money moved; `verify-purchase` tells Google's API to confirm
/// it and writes the entitlement. The client's opinion is never consulted.
class PlayBillingService implements BillingService {
  PlayBillingService(this._verifier) {
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('purchaseStream error: $e'),
    );
  }

  final PurchaseVerifier _verifier;
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  /// Resolves the checkout the user is currently waiting on.
  Completer<PurchaseOutcome>? _pending;

  List<ProductDetails>? _products;

  @override
  bool get isSupported => true;

  @override
  Future<List<BillingPlan>> plans() async {
    if (!await _iap.isAvailable()) return const [];

    final response = await _iap.queryProductDetails(kProProductIds);
    if (response.error != null) {
      debugPrint('queryProductDetails failed: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      // Almost always a Play Console problem: ids mismatched, or the app isn't
      // published to a track the tester's account can see.
      debugPrint('Play products not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;

    final plans = <BillingPlan>[];
    for (final id in [kProAnnualId, kProMonthlyId]) {
      final product = _products!.where((p) => p.id == id).firstOrNull;
      if (product == null) continue;
      final annual = id == kProAnnualId;
      plans.add(BillingPlan(
        id: id,
        title: annual ? 'Annual' : 'Monthly',
        price: product.price,
        period: annual ? '/year' : '/month',
        subtext: annual ? 'Best value' : 'Billed monthly',
        highlighted: annual,
      ));
    }
    return plans;
  }

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    if (_pending != null && !_pending!.isCompleted) {
      return const PurchaseFailed('A purchase is already in progress.');
    }
    final product = _products?.where((p) => p.id == planId).firstOrNull;
    if (product == null) {
      return const PurchaseFailed(
        "That plan isn't available on this device right now.",
      );
    }

    final completer = Completer<PurchaseOutcome>();
    _pending = completer;
    try {
      // Subscriptions are non-consumable in the plugin's vocabulary.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _pending = null;
      debugPrint('buyNonConsumable failed: $e');
      return const PurchaseFailed("We couldn't open Google Play checkout.");
    }

    // The store UI can sit open indefinitely; the timeout only bounds our
    // waiting, and a late purchase is still handled by the stream listener.
    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () => const PurchasePending(),
    );
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!await _iap.isAvailable()) {
      return const PurchaseFailed('Google Play is not available here.');
    }
    final completer = Completer<PurchaseOutcome>();
    _pending = completer;
    await _iap.restorePurchases();
    // restorePurchases replays past purchases through the same stream; if
    // there are none, nothing arrives, so don't wait forever.
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => const PurchaseFailed('No previous subscription found.'),
    );
  }

  /// Every purchase event lands here — including ones that complete while the
  /// paywall is closed (a pending UPI mandate clearing, say).
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _resolve(const PurchasePending());

        case PurchaseStatus.canceled:
          _resolve(const PurchaseCancelled());
          await _complete(purchase);

        case PurchaseStatus.error:
          debugPrint('purchase error: ${purchase.error}');
          _resolve(PurchaseFailed(
            purchase.error?.message.isNotEmpty == true
                ? purchase.error!.message
                : "The payment didn't go through.",
          ));
          await _complete(purchase);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndGrant(purchase);
      }
    }
  }

  Future<void> _verifyAndGrant(PurchaseDetails purchase) async {
    try {
      final entitlement = await _verifier.verify(
        purchaseToken: purchase.verificationData.serverVerificationData,
        productId: purchase.productID,
      );
      // Acknowledge only after the server has recorded it. Play auto-refunds
      // any purchase left unacknowledged for three days, which is the right
      // outcome if we could never record what they bought.
      await _complete(purchase);
      _resolve(entitlement.isPro
          ? PurchaseGranted(entitlement)
          : const PurchaseFailed('That subscription is no longer active.'));
    } on VerificationException catch (e) {
      // Deliberately not acknowledged: leaving it pending means Play retries
      // delivery, and an unrecoverable one refunds rather than charging for
      // something we never turned on.
      _resolve(PurchaseFailed(e.message, alreadyPaid: e.isTransient));
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('completePurchase failed: $e');
    }
  }

  void _resolve(PurchaseOutcome outcome) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    // A pending payment isn't the end of the flow — keep waiting for it to
    // clear rather than closing the checkout on the first event.
    if (outcome is PurchasePending) {
      return;
    }
    _pending = null;
    pending.complete(outcome);
  }

  @override
  void dispose() => _subscription.cancel();
}

/// Used where no store exists — the web preview, desktop, iOS before StoreKit
/// is wired. It sells nothing, deliberately: a stub that returns success would
/// hand out Pro for free, which is exactly the bug we are fixing.
class UnavailableBillingService implements BillingService {
  const UnavailableBillingService();

  @override
  bool get isSupported => false;

  @override
  Future<List<BillingPlan>> plans() async => const [];

  @override
  Future<PurchaseOutcome> purchase(String planId) async => const PurchaseFailed(
        'Crux Pro can be purchased in the Android app.',
      );

  @override
  Future<PurchaseOutcome> restore() async => const PurchaseFailed(
        'Crux Pro can be purchased in the Android app.',
      );

  @override
  void dispose() {}
}

final billingServiceProvider = Provider<BillingService>((ref) {
  // Android only for now. iOS goes through the same interface once StoreKit
  // and an App Store Server API verifier exist.
  final supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final service = supported
      ? PlayBillingService(ref.read(purchaseVerifierProvider))
      : const UnavailableBillingService();
  ref.onDispose(service.dispose);
  return service;
});
