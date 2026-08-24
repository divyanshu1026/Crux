import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase/supabase_config.dart';
import '../../../core/providers/providers.dart';

/// The Pro entitlement, as the server understands it.
///
/// The client never decides this. It asks, and caches the answer.
@immutable
class Entitlement {
  const Entitlement({required this.isPro, this.expiresAt, this.status});

  const Entitlement.none() : isPro = false, expiresAt = null, status = null;

  final bool isPro;
  final DateTime? expiresAt;

  /// Provider status when known — 'active', 'in_grace_period', 'on_hold'…
  /// Worth surfacing: "on hold" means their card failed, which is fixable.
  final String? status;
}

/// Thrown when a purchase can't be confirmed. [message] is safe to show.
class VerificationException implements Exception {
  VerificationException(this.message, this.code);
  final String message;
  final String code;

  /// True when the purchase is real but we couldn't record it — the user has
  /// paid, so the app must not tell them the purchase failed.
  bool get isTransient =>
      code == 'unavailable' || code == 'upstream' || code == 'write_failed';
}

/// Calls the `verify-purchase` Edge Function, which asks Google Play whether a
/// purchase token is real before granting anything.
class PurchaseVerifier {
  /// Sends a store purchase token for verification. Returns what the server
  /// granted.
  Future<Entitlement> verify({
    required String purchaseToken,
    required String productId,
  }) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || client.auth.currentSession == null) {
      throw VerificationException(
        'Sign in to activate Pro on this account.',
        'auth',
      );
    }

    try {
      final res = await client.functions.invoke(
        'verify-purchase',
        body: {'purchaseToken': purchaseToken, 'productId': productId},
      );
      final data = res.data;
      if (data is! Map) {
        throw VerificationException(
          "We couldn't confirm your purchase. Tap Restore in a moment.",
          'bad_response',
        );
      }
      return Entitlement(
        isPro: data['pro'] == true,
        expiresAt: DateTime.tryParse((data['expiresAt'] as String?) ?? ''),
        status: data['status'] as String?,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] is String)
          ? details['error'] as String
          : "We couldn't confirm your purchase. Tap Restore in a moment.";
      final code = (details is Map && details['code'] is String)
          ? details['code'] as String
          : 'failed';
      throw VerificationException(message, code);
    } on VerificationException {
      rethrow;
    } catch (e) {
      debugPrint('verify-purchase failed: $e');
      throw VerificationException(
        "We couldn't reach our servers to confirm your purchase. "
        'It will activate automatically once we can.',
        'offline',
      );
    }
  }

  /// Reads the entitlement the server currently holds for this account —
  /// used on launch so a renewal (or a cancellation) that happened while the
  /// app was closed is reflected without a purchase round trip.
  Future<Entitlement?> current() async {
    final client = SupabaseConfig.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    try {
      final row = await client
          .from('profiles')
          .select('is_pro, pro_expires_at')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return Entitlement(
        isPro: row['is_pro'] == true,
        expiresAt: DateTime.tryParse((row['pro_expires_at'] as String?) ?? ''),
      );
    } catch (e) {
      debugPrint('entitlement read failed: $e');
      return null;
    }
  }
}

final purchaseVerifierProvider =
    Provider<PurchaseVerifier>((ref) => PurchaseVerifier());

/// Pulls the server's entitlement into the app on launch and whenever the
/// signed-in account changes.
///
/// Subscriptions change while the app is closed — they renew, lapse, get
/// refunded, go on hold when a card fails. Without this the cached flag drifts
/// from the truth, in both directions: a paying user locked out after a
/// reinstall, or a cancelled one keeping Pro until they happen to open the
/// paywall.
final entitlementSyncProvider = Provider<void>((ref) {
  // Re-runs on sign-in/sign-out; a different account has a different
  // entitlement, and the previous one must not linger.
  ref.watch(authProvider);

  Future<void>(() async {
    final entitlement = await ref.read(purchaseVerifierProvider).current();
    if (entitlement == null) return; // offline or signed out — keep the cache
    ref.read(userProfileProvider.notifier).applyServerEntitlement(
          isPro: entitlement.isPro,
          expiresAt: entitlement.expiresAt,
        );
  });
});
