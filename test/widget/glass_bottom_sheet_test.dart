import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/theme/theme.dart';
import 'package:crux/core/widgets/widgets.dart';

import '../helpers/test_harness.dart';

/// The sheet's own padded body — identified by its horizontal screen padding,
/// which nothing else in the tree uses.
EdgeInsets _sheetPadding(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final c in containers) {
    final p = c.padding;
    if (p is EdgeInsets && p.left == CxSpace.screen && p.right == CxSpace.screen) {
      return p;
    }
  }
  fail('Could not find the sheet body padding');
}

Future<void> _pumpSheet(WidgetTester tester, double keyboardHeight) async {
  await tester.pumpWidget(
    wrapApp(
      Builder(
        builder: (context) => MediaQuery(
          // Simulate the on-screen keyboard.
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            // A real modal sheet is a route above the Scaffold, so it sees the
            // raw viewInsets. Keep them here instead of letting Scaffold
            // absorb them.
            resizeToAvoidBottomInset: false,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CxGlassBottomSheet(
                title: 'Delete your account?',
                child: TextField(controller: TextEditingController()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet reserves room for the keyboard so fields stay visible',
      (tester) async {
    await _pumpSheet(tester, 0);
    final closed = _sheetPadding(tester).bottom;

    await _pumpSheet(tester, 320);
    final open = _sheetPadding(tester).bottom;

    // With the keyboard up the sheet must clear its full height, otherwise the
    // confirm field sits underneath it (the delete-account bug).
    expect(open, greaterThanOrEqualTo(320));
    expect(open, greaterThan(closed));
  });
}
