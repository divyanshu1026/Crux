import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/program_templates.dart';
import 'package:crux/core/theme/app_theme.dart';
import 'package:crux/features/onboarding/presentation/schedule_confirm_screen.dart';
import 'package:crux/features/schedule/presentation/schedule_chat_sheet.dart';

/// The onboarding review screen used to carry its own copy of the schedule
/// chat. That copy lost the conversation whenever the sheet was dismissed, and
/// — worse — announced plan rewrites it never applied, because
/// `applyAiScheduleEdit` returns a proposal and the reply only printed its
/// note. It now opens the shared chat, which applies changes properly.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.profile': jsonEncode({
        'name': 'Test',
        'daysPerWeek': ['Mon', 'Wed', 'Fri'],
        'hasCompletedOnboarding': false,
      }),
      'rq.program': jsonEncode(ProgramTemplates.fullBodyBeginner().toJson()),
    });
  });

  testWidgets('onboarding opens the shared schedule chat', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: CxTheme.dark,
          home: const ScheduleConfirmScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask Coach to change it'));
    await tester.pumpAndSettle();

    // The shared chat's greeting, and its always-present suggestion strip.
    expect(
      find.textContaining('Tell me what you want different about your week'),
      findsOneWidget,
    );
    expect(find.text('Schedule Coach'), findsOneWidget);
  });

  testWidgets('the conversation survives closing and reopening the sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    // Put a turn in the shared conversation, as a send would.
    await container.read(scheduleChatProvider.notifier).send('hi');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: CxTheme.dark,
          home: const ScheduleConfirmScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask Coach to change it'));
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsOneWidget);

    // Dismiss, reopen — the transcript is still there. It used to live in the
    // sheet's State, so this is exactly what erased it.
    Navigator.of(tester.element(find.text('hi'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Coach to change it'));
    await tester.pumpAndSettle();

    expect(find.text('hi'), findsOneWidget);
  });
}
