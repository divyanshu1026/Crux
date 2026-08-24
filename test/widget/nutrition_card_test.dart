import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/program_templates.dart';
import 'package:crux/core/theme/app_theme.dart';
import 'package:crux/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.profile': jsonEncode({
        'name': 'Test',
        'sex': 'Male',
        'age': 24,
        'height': 180.0,
        'weight': 72.0,
        'goal': 'Build Muscle',
        'hasCompletedOnboarding': true,
      }),
      'rq.program':
          jsonEncode(ProgramTemplates.pplppHypertrophy().toJson()),
    });
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: CxTheme.dark,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard shows goal-aware nutrition targets', (tester) async {
    await pumpDashboard(tester);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('NUTRITION'), findsOneWidget);
    // Lean-gain framing for Build Muscle.
    expect(find.textContaining('Lean gain'), findsOneWidget);
    // Protein target from 72 kg × 1.9 g/kg ≈ 137 g.
    expect(find.textContaining('/ 137 g'), findsOneWidget);
    expect(find.text(' kcal/day'), findsOneWidget);
  });

  testWidgets('protein quick-log adds grams and persists in provider',
      (tester) async {
    await pumpDashboard(tester);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets); // today's grams start at 0

    await tester.tap(find.text('+25 g'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+40 g'));
    await tester.pumpAndSettle();

    expect(find.text('65'), findsOneWidget); // 25 + 40 logged
  });
}
