import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/theme/theme.dart';
import 'package:crux/core/widgets/widgets.dart';

/// Progress photos point at files the OS may have cleared (and, on web, blob
/// URLs that die on reload). A missing photo must degrade to a placeholder —
/// the whole Dashboard used to go down with it.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: CxTheme.dark,
        home: Scaffold(body: Center(child: SizedBox(width: 92, height: 120, child: child))),
      );

  testWidgets('a missing file renders the placeholder, not an exception',
      (tester) async {
    await tester.pumpWidget(host(
      const CxLocalImage(path: '/definitely/not/a/real/photo.jpg'),
    ));
    // FileImage does real I/O, which needs the real clock to fail — a plain
    // pump inside the fake-async zone never gets there.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
  });

  testWidgets('a custom placeholder is used when supplied', (tester) async {
    await tester.pumpWidget(host(
      const CxLocalImage(
        path: '/definitely/not/a/real/photo.jpg',
        placeholder: Text('gone'),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('gone'), findsOneWidget);
  });
}
