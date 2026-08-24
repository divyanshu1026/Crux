import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux/features/legal/domain/legal_docs.dart';
import 'package:crux/features/legal/presentation/legal_doc_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUpAll(loadCruxFonts);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapApp(child, themeMode: ThemeMode.light));
    await tester.pumpAndSettle();
  }

  testWidgets('privacy policy — light', (tester) async {
    await pump(tester, const LegalDocScreen(doc: LegalDocs.privacy));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/legal_privacy.png'),
    );
  });
}
