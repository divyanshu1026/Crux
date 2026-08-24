import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/utils/units.dart';

void main() {
  group('unit conversion', () {
    test('kg formats without conversion', () {
      expect(formatWeightValue(60, 'kg'), '60');
      expect(formatWeight(62.5, 'kg'), '62.5 kg');
    });

    test('lbs converts from stored kg', () {
      // 100 kg ≈ 220.5 lbs
      expect(formatWeightValue(100, 'lbs'), '220.5');
      expect(unitLabel('lbs'), 'lbs');
    });
  });
}
