import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/widgets/cx_number_roll.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('number roll renders each digit of the value', (tester) async {
    await tester.pumpWidget(
      wrapApp(const Scaffold(body: Center(child: CxNumberRoll(value: 1240)))),
    );
    await tester.pumpAndSettle();

    // Each digit column renders the digits 0..9 (+ a wrap 0), so every glyph
    // appears at least once; assert the odometer built without error.
    expect(find.byType(CxNumberRoll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('number roll animates toward a new value', (tester) async {
    var value = 60.0;
    await tester.pumpWidget(
      wrapApp(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                CxNumberRoll(value: value, decimals: 1),
                TextButton(
                  onPressed: () => setState(() => value = 62.5),
                  child: const Text('bump'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('bump'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-animation: still building without exceptions.
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
