import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/app/app.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/providers/providers.dart';

import '../helpers/test_harness.dart';

void main() {
  setUpAll(loadCruxFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.auth': '{"isAuthenticated":true,"email":"test@example.com","name":"test"}',
      'rq.profile': '{"hasCompletedOnboarding":true}',
      // The shell is only reachable with a program (router onboarding gate).
      'rq.program': seededProgramJson(),
    });
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Pin the clock: Today's greeting and highlighted weekday follow the
          // wall clock, so without this the golden passes in the evening and
          // fails the next morning. Wednesday 08:30.
          clockProvider.overrideWithValue(() => DateTime(2026, 8, 5, 8, 30)),
        ],
        child: const CruxApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shell — Today tab', (tester) async {
    await pumpShell(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_today.png'),
    );
  });

  testWidgets('shell — Profile tab', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_profile.png'),
    );
  });
}
