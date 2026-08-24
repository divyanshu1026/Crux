import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Thrown when account deletion can't complete. [code] distinguishes
/// "nothing to delete in the cloud" from a real failure.
class AccountDeletionException implements Exception {
  AccountDeletionException(this.message, this.code);
  final String message;
  final String code;
}

/// Permanent account deletion (Google Play User Data policy).
///
/// The app must offer an in-app route to delete the account *and* its
/// server-side data. This calls the `delete-account` Edge Function, which
/// verifies the caller's JWT and removes their rows plus the auth identity.
class AccountRepository {
  /// Deletes the signed-in user's cloud account and all server data.
  ///
  /// Returns normally when there is nothing to delete (offline/local-only
  /// build, or a user who never signed in) — the caller then just wipes the
  /// device, which is the whole of "their data" in that case.
  Future<void> deleteCloudAccount() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || client.auth.currentSession == null) {
      return; // Local-only install: no cloud account exists.
    }

    try {
      await client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      final details = e.details;
      debugPrint(
        'delete-account failed: status=${e.status} details=$details',
      );

      // 404 = the Edge Function was never deployed to this project. Nothing the
      // user can do about it, and "try again" would be a lie — say so plainly
      // and point support at it. Deploy with:
      //   supabase functions deploy delete-account
      if (e.status == 404) {
        throw AccountDeletionException(
          'Account deletion is temporarily unavailable. Please contact '
          'support@crux.app and we will delete your account for you.',
          'not_deployed',
        );
      }

      final msg = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'We could not delete your account just now. Please try again.';
      final code = (details is Map && details['code'] is String)
          ? details['code'] as String
          : 'failed';
      throw AccountDeletionException(msg, code);
    } catch (_) {
      throw AccountDeletionException(
        'We could not reach the server. Check your connection and try again.',
        'network',
      );
    }
  }
}

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository());
