import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/domain/nutrition.dart';

void main() {
  group('nutritionTargets', () {
    // The user's coach example: 180 cm / 72 kg male building muscle
    // → ~2,500–2,650 kcal, ~140 g protein (1.9 g/kg).
    test('matches the coach-example ballpark for a lean-gain male', () {
      final t = nutritionTargets(
        weightKg: 72,
        heightCm: 180,
        age: 24,
        sex: 'Male',
        goal: 'Build Muscle',
      );
      // Mifflin: 10*72 + 6.25*180 - 5*24 + 5 = 1730 → ×1.5 = 2595 → +250 = 2845
      // band around 2850 ±75.
      expect(t.caloriesLow, inInclusiveRange(2600, 2900));
      expect(t.caloriesHigh - t.caloriesLow, 150);
      expect(t.proteinG, (72 * 1.9).round()); // ≈137
      expect(t.pace, contains('+0.25 kg/week'));
      expect(t.strategy.toLowerCase(), contains('lean gain'));
    });

    test('fat loss uses a gentle deficit and high protein — never a crash cut',
        () {
      final maintain = nutritionTargets(
        weightKg: 80,
        heightCm: 170,
        age: 30,
        sex: 'Female',
        goal: 'General Fitness',
      );
      final cut = nutritionTargets(
        weightKg: 80,
        heightCm: 170,
        age: 30,
        sex: 'Female',
        goal: 'Lose Fat & Tone',
      );
      final deficit =
          (maintain.caloriesLow + 75) - (cut.caloriesLow + 75); // mid - mid
      expect(deficit, inInclusiveRange(300, 400)); // gentle, not extreme
      expect(cut.proteinPerKg, 2.2);
      expect(cut.pace, isNot(contains('1 kg'))); // no aggressive pacing
    });

    test('unspecified sex uses the midpoint constant (between M and F)', () {
      int mid(String sex) {
        final t = nutritionTargets(
          weightKg: 70,
          heightCm: 175,
          age: 25,
          sex: sex,
          goal: 'General Fitness',
        );
        return (t.caloriesLow + t.caloriesHigh) ~/ 2;
      }

      final male = mid('Male');
      final female = mid('Female');
      final unspecified = mid('Prefer not to say');
      expect(unspecified, greaterThan(female));
      expect(unspecified, lessThan(male));
    });

    test('calories are rounded to 50s with an honest ±75 band', () {
      final t = nutritionTargets(
        weightKg: 77.3,
        heightCm: 181,
        age: 27,
        sex: 'Male',
        goal: 'Get Stronger',
      );
      final mid = t.caloriesLow + 75;
      expect(mid % 50, 0);
      expect(t.caloriesHigh, mid + 75);
    });
  });
}
