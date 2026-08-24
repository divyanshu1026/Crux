import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/features/design_gallery/presentation/design_gallery_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUpAll(loadCruxFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpGallery(WidgetTester tester, ThemeMode mode) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 4600);
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      wrapApp(const DesignGalleryScreen(), themeMode: mode, prefs: prefs),
    );
    // The gallery contains an intentional infinite spinner (loading button),
    // so settle in fixed frames rather than waiting for all animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('design gallery — dark', (tester) async {
    await pumpGallery(tester, ThemeMode.dark);
    await expectLater(
      find.byType(DesignGalleryScreen),
      matchesGoldenFile('goldens/design_gallery_dark.png'),
    );
  });

  testWidgets('design gallery — light', (tester) async {
    await pumpGallery(tester, ThemeMode.light);
    await expectLater(
      find.byType(DesignGalleryScreen),
      matchesGoldenFile('goldens/design_gallery_light.png'),
    );
  });
}
