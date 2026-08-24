import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud configuration, supplied at build time via --dart-define. When these
/// are absent the whole Supabase layer stays dormant and the app runs fully
/// local/offline (plan: "everything except AI chat works in airplane mode").
///
/// Run with cloud enabled:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only when both values were provided at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initializes Supabase if configured. Safe to call unconditionally; a no-op
  /// when running without cloud credentials.
  static Future<void> initIfConfigured() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// The Supabase client, or null when not configured. Callers must handle null
  /// and fall back to local behavior.
  static SupabaseClient? get clientOrNull =>
      isConfigured ? Supabase.instance.client : null;
}
