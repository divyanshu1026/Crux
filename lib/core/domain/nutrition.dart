/// Goal-aware nutrition targets (plan Phase 12.1, ethics rules §5).
///
/// Deliberately NOT a food database — one calorie band, one protein number,
/// and honest pacing advice, computed from the user's own stats. Framing
/// rules baked in: lean-gain first, no crash-cut messaging, gentle deficits
/// only, and "the mirror + scale decide" feedback loops.
library;

class NutritionTargets {
  /// Daily calorie guidance band (kcal).
  final int caloriesLow;
  final int caloriesHigh;

  /// Daily protein target in grams — the priority number.
  final int proteinG;

  /// Grams of protein per kg used for the calc (for the "why" copy).
  final double proteinPerKg;

  /// Expected body-weight pace, e.g. "+0.25 kg/week max".
  final String pace;

  /// One-line strategy framing for this goal.
  final String strategy;

  /// The self-correction rule ("if the scale does X, adjust Y").
  final String adjustRule;

  const NutritionTargets({
    required this.caloriesLow,
    required this.caloriesHigh,
    required this.proteinG,
    required this.proteinPerKg,
    required this.pace,
    required this.strategy,
    required this.adjustRule,
  });
}

/// Mifflin-St Jeor BMR × moderate-training activity, then a goal adjustment.
/// Sex uses the profile's three options; "prefer not to say" takes the
/// midpoint constant so nobody gets a wrong-by-design number.
NutritionTargets nutritionTargets({
  required double weightKg,
  required double heightCm,
  required int age,
  required String sex, // 'Male' | 'Female' | anything else = midpoint
  required String goal, // profile goal strings
}) {
  final sexConstant = switch (sex) {
    'Male' => 5.0,
    'Female' => -161.0,
    _ => -78.0,
  };
  final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexConstant;
  // Lifting 3-5x/week ≈ moderate activity.
  final maintenance = bmr * 1.5;

  double delta;
  double proteinPerKg;
  String pace;
  String strategy;
  String adjustRule;

  switch (goal) {
    case 'Build Muscle':
      delta = 250;
      proteinPerKg = 1.9;
      pace = 'Gain slowly — about +0.25 kg/week max.';
      strategy =
          'Lean gain, not a bulk: a small surplus builds muscle while staying lean.';
      adjustRule =
          'Scale climbing faster than ~0.25 kg/week? Drop ~150 kcal. Not moving after 3 weeks? Add ~150.';
      break;
    case 'Get Stronger':
      delta = 150;
      proteinPerKg = 1.8;
      pace = 'Roughly maintain, drifting up ~0.1–0.2 kg/week.';
      strategy =
          'Strength grows best fed: eat at or just above maintenance and let the bar speed guide you.';
      adjustRule =
          'Lifts stalling for 2+ weeks with good sleep? Add ~150 kcal before blaming the program.';
      break;
    case 'Lose Fat & Tone':
      // Gentle deficit only (ethics: no crash-cut messaging).
      delta = -350;
      proteinPerKg = 2.2;
      pace = 'Lose slowly — about −0.25 to −0.5 kg/week.';
      strategy =
          'A modest deficit with high protein keeps muscle while fat comes off — slow is what sticks.';
      adjustRule =
          'Losing faster than ~0.5 kg/week or training feels flat? Add ~150 kcal back. This is a marathon setting.';
      break;
    default: // General Fitness
      delta = 0;
      proteinPerKg = 1.6;
      pace = 'Hold steady — weight roughly stable week to week.';
      strategy =
          'Eat at maintenance, hit your protein, and let training drive body composition.';
      adjustRule =
          'Re-check the 7-day weight average monthly and nudge ±150 kcal if it drifts.';
  }

  final target = maintenance + delta;
  // Round to 50s and present an honest ±75 band — precision theater helps no one.
  final mid = (target / 50).round() * 50;
  final protein = (weightKg * proteinPerKg).round();

  return NutritionTargets(
    caloriesLow: mid - 75,
    caloriesHigh: mid + 75,
    proteinG: protein,
    proteinPerKg: proteinPerKg,
    pace: pace,
    strategy: strategy,
    adjustRule: adjustRule,
  );
}
