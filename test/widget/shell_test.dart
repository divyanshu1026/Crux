import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/app/app.dart';
import 'package:crux/core/data/local_store.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.auth': '{"isAuthenticated":true,"email":"test@example.com","name":"test"}',
      'rq.profile': '{"hasCompletedOnboarding":true}',
      // A finished setup always has a program — the shell is only reachable
      // with one (see the router's onboarding gate).
      'rq.program': seededProgramJson(),
    });
  });

  /// Pumps the app. [settle] must be false for screens with looping animations
  /// (onboarding), which never reach a settled frame.
  Future<void> pumpApp(WidgetTester tester, {bool settle = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CruxApp(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('shell shows all five tabs and starts on Today', (tester) async {
    await pumpApp(tester);

    // Tab labels are present in the bottom nav.
    expect(find.text('Today'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Starts on Today with the real plan, not the "no program" placeholder.
    expect(find.text('Your plan for today shows up here.'), findsNothing);
  });

  testWidgets('tapping a tab navigates to that screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    // Fresh installs start with an empty history (no seeded workouts).
    expect(find.text('No workouts yet'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Your rank, streak, and trends live here.'), findsNothing);

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ask your coach about training, form, or your plan.'),
      findsNothing,
    );
  });

  testWidgets('onboarded profile with no program goes to onboarding',
      (tester) async {
    // Reinstall / new device: the cloud profile restores
    // `onboarding_complete = true`, but programs don't sync yet. Setting up a
    // program is onboarding's job, so the user must land there — not in a
    // shell of empty placeholders with no route out.
    SharedPreferences.setMockInitialValues({
      'rq.auth':
          '{"isAuthenticated":true,"email":"test@example.com","name":"test"}',
      'rq.profile': '{"hasCompletedOnboarding":true}',
    });
    await pumpApp(tester, settle: false);

    expect(find.text('Walk in knowing\nexactly what to do'), findsOneWidget);
    // And definitely not the empty shell.
    expect(find.text('Your plan for today shows up here.'), findsNothing);
  });

  testWidgets('profile can open the design gallery', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Design gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Night Gym'), findsOneWidget);
  });

  testWidgets('profile sign out redirects to auth screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Email'), findsOneWidget);
  });
}
