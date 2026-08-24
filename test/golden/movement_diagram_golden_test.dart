import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crux/core/theme/theme.dart';
import 'package:crux/features/exercise_guide/domain/movement_pose.dart';
import 'package:crux/features/exercise_guide/presentation/movement_diagram.dart';

import '../helpers/test_harness.dart';

/// Renders the movement diagrams at several points through the rep so the
/// poses can be reviewed as pictures. The animation is time-based, so each
/// frame is pumped to a fixed offset rather than settled.
void main() {
  setUpAll(loadCruxFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    ThemeMode mode, {
    required Duration at,
  }) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(880, 1180);
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) {
            final c = context.cx;
            return Scaffold(
              backgroundColor: c.canvas,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(CxSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final pattern in MovementPatterns.all) ...[
                      Text(
                        pattern.name,
                        style: CxType.titleSmall.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: CxSpace.sm),
                      MovementDiagram(pattern: pattern, height: 230),
                      const SizedBox(height: CxSpace.lg),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        themeMode: mode,
        prefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(at);
  }

  // 0ms = top of the rep, 1300ms = bottom (the controller runs 2600ms).
  for (final (name, at) in [
    ('top', Duration.zero),
    ('mid', Duration(milliseconds: 650)),
    ('bottom', Duration(milliseconds: 1300)),
  ]) {
    testWidgets('movement diagrams — dark — $name', (tester) async {
      await pumpSheet(tester, ThemeMode.dark, at: at);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/movement_${name}_dark.png'),
      );
    });
  }

  testWidgets('movement diagram — squat, large', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(900, 760);
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.cx.canvas,
            body: const Padding(
              padding: EdgeInsets.all(CxSpace.lg),
              child: MovementDiagram(
                pattern: MovementPatterns.squat,
                height: 330,
              ),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
        prefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/movement_squat_large.png'),
    );
  });

  testWidgets('movement diagrams — light — bottom', (tester) async {
    await pumpSheet(tester, ThemeMode.light,
        at: const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/movement_bottom_light.png'),
    );
  });
}
