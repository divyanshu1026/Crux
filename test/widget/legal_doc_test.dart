import 'package:crux/app/router.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux/features/legal/domain/legal_docs.dart';
import 'package:crux/features/legal/presentation/legal_doc_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('privacy policy renders in-app with no network', (tester) async {
    await tester.pumpWidget(
      wrapApp(const LegalDocScreen(doc: LegalDocs.privacy)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.textContaining('Last updated'), findsOneWidget);

    // Sections further down exist but are off-screen in the lazy ListView.
    await tester.scrollUntilVisible(
      find.text('7. Deleting your data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('7. Deleting your data'), findsOneWidget);
  });

  testWidgets('terms of use renders in-app', (tester) async {
    await tester.pumpWidget(
      wrapApp(const LegalDocScreen(doc: LegalDocs.terms)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('5. The AI Coach'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('5. The AI Coach'), findsOneWidget);
  });

  test('both documents carry a contact address and a last-updated date', () {
    for (final doc in [LegalDocs.privacy, LegalDocs.terms]) {
      expect(doc.lastUpdated, isNotEmpty);
      final text = doc.blocks
          .whereType<LegalParagraph>()
          .map((b) => b.text)
          .join(' ');
      expect(text, contains(LegalDocs.contactEmail));
    }
  });

  testWidgets('unauthenticated users can navigate to terms and privacy from router',
      (tester) async {
    final prefs = await initMockPrefs();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.push(Routes.privacy);
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);

    router.push(Routes.terms);
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsOneWidget);
  });
}
