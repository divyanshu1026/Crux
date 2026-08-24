import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../providers/providers.dart';
import 'supabase_config.dart';

/// Deep-link scheme used for OAuth return (must match AndroidManifest / Info.plist
/// and be allow-listed under Supabase Auth → URL Configuration → Redirect URLs).
const kAuthRedirectUri = 'io.supabase.crux://login-callback/';

/// Where the provider should send the browser back to.
///
/// On mobile that's the custom scheme above, caught by the deep-link
/// intent-filter. On web a custom scheme is a dead end — the browser has
/// nothing to open — so we let Supabase return to the page that started the
/// flow instead.
String? get authRedirectUri => kIsWeb ? null : kAuthRedirectUri;

/// Which sign-in methods the Supabase project actually has switched on.
///
/// Fetched rather than assumed: a button for a provider that is disabled in
/// the dashboard doesn't fail politely — it opens a browser tab showing
/// `"Unsupported provider: provider is not enabled"`, which reads as the app
/// being broken. Hiding it is honest, and it reappears on its own the moment
/// the provider is enabled — no app update needed.
class AuthProviders {
  const AuthProviders({required this.google, required this.apple});

  /// What to show before the answer arrives, and if it never does: assume the
  /// provider works. Failing open means a flaky network hides nothing; failing
  /// closed would remove sign-in options from people who can use them.
  const AuthProviders.unknown() : google = true, apple = true;

  final bool google;
  final bool apple;
}

/// Reads `/auth/v1/settings`, which reports the enabled providers publicly.
final authProvidersProvider = FutureProvider<AuthProviders>((ref) async {
  if (!SupabaseConfig.isConfigured) {
    return const AuthProviders(google: false, apple: false);
  }
  try {
    final res = await http.get(
      Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
      headers: {'apikey': SupabaseConfig.anonKey},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const AuthProviders.unknown();
    final external =
        (jsonDecode(res.body) as Map<String, dynamic>)['external'];
    if (external is! Map) return const AuthProviders.unknown();
    return AuthProviders(
      google: external['google'] == true,
      apple: external['apple'] == true,
    );
  } catch (e) {
    debugPrint('auth settings lookup failed: $e');
    return const AuthProviders.unknown();
  }
});

/// Wraps Supabase auth. When cloud is unconfigured every method is a no-op and
/// the [AuthNotifier] keeps its local-mock behavior, so the app signs in
/// instantly and offline exactly as before.
class AuthRepository {
  sb.SupabaseClient? get _client => SupabaseConfig.clientOrNull;

  /// True only when a real Supabase project is wired.
  bool get isCloud => _client != null;

  /// Maps a Supabase session to the app's [AuthState].
  AuthState _fromSession(sb.Session? session) {
    final user = session?.user;
    if (user == null) return const AuthState(isAuthenticated: false);
    final name = (user.userMetadata?['name'] as String?) ??
        (user.email?.split('@').first) ??
        'Athlete';
    return AuthState(
      isAuthenticated: true,
      email: user.email,
      name: name,
      userId: user.id,
    );
  }

  AuthState currentAuthState() => _fromSession(_client?.auth.currentSession);

  /// Emits an [AuthState] on every sign-in/out/refresh.
  Stream<AuthState> authStateChanges() =>
      _client!.auth.onAuthStateChange.map((e) => _fromSession(e.session));

  Future<sb.AuthResponse> signInWithPassword(
          String email, String password) =>
      _client!.auth.signInWithPassword(email: email, password: password);

  Future<sb.AuthResponse> signUpWithPassword(
          String name, String email, String password) =>
      _client!.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
        emailRedirectTo: kAuthRedirectUri,
      );

  /// Guest access — anonymous sign-in so a device can sync without an email.
  Future<sb.AuthResponse> signInAnonymously() =>
      _client!.auth.signInAnonymously();

  /// Opens the system browser / Custom Tab for Google OAuth. Session arrives
  /// via [authStateChanges] after the deep-link callback.
  Future<bool> signInWithGoogle() => _client!.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: authRedirectUri,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );

  Future<bool> signInWithApple() => _client!.auth.signInWithOAuth(
        sb.OAuthProvider.apple,
        redirectTo: authRedirectUri,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );

  Future<void> signOut() => _client!.auth.signOut();
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());
