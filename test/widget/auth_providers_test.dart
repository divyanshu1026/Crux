import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/supabase/auth_repository.dart';
import 'package:crux/core/theme/app_theme.dart';
import 'package:crux/features/auth/presentation/auth_screen.dart';

/// A social button for a provider that is switched off in the Supabase project
/// doesn't fail politely — it opens a browser page reading "Unsupported
/// provider: provider is not enabled", which looks like a broken app. The
/// screen only offers what the project actually has.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'rq.profile': jsonEncode({})});
  });

  Future<void> pumpAuth(
    WidgetTester tester,
    AuthProviders providers, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvidersProvider.overrideWith((ref) async => providers),
        ],
        child: MaterialApp(
          theme: CxTheme.dark.copyWith(platform: platform),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Apple is hidden on Android even when enabled', (tester) async {
    await pumpAuth(tester, const AuthProviders(google: true, apple: true));
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('Google is hidden when the project has it disabled',
      (tester) async {
    await pumpAuth(tester, const AuthProviders(google: false, apple: false));
    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Sign in with Apple'), findsNothing);
    // Email is always there, so sign-in is never a dead end.
    expect(find.text('Continue with Email'), findsOneWidget);
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });

  testWidgets('an unknown answer still offers Google (fails open)',
      (tester) async {
    await pumpAuth(tester, const AuthProviders.unknown());
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('there is no way into the app without an account',
      (tester) async {
    await pumpAuth(tester, const AuthProviders(google: true, apple: false));
    // Guest access was removed deliberately — every account is a real account.
    expect(find.textContaining('Skip'), findsNothing);
  });

  testWidgets('Apple shows on iOS, above Google', (tester) async {
    await pumpAuth(
      tester,
      const AuthProviders(google: true, apple: true),
      platform: TargetPlatform.iOS,
    );
    final apple = tester.getTopLeft(find.text('Sign in with Apple')).dy;
    final google = tester.getTopLeft(find.text('Sign in with Google')).dy;
    expect(apple, lessThan(google));
  });
}
