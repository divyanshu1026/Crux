import '../models/models.dart';

/// A browsable catalog of exercises for the "add exercise" picker. Each entry
/// carries a sensible default sets/reps/weight so a freshly-added exercise is
/// immediately loggable. Grouped by muscle for the picker UI.
class CatalogEntry {
  final String name;
  final String muscleGroup;
  final String equipment;
  final double defaultWeight;
  final String defaultReps;
  const CatalogEntry(
    this.name,
    this.muscleGroup,
    this.equipment,
    this.defaultWeight,
    this.defaultReps,
  );

  Exercise toExercise() => Exercise(
        id: 'cat_${name.hashCode}',
        name: name,
        muscleGroup: muscleGroup,
        equipment: equipment,
        targetSets: 3,
        targetReps: defaultReps,
        suggestedWeight: defaultWeight,
      );
}

abstract final class ExerciseCatalog {
  static const all = <CatalogEntry>[
    // Chest
    CatalogEntry('Bench Press', 'Chest', 'Barbell', 60, '6-8'),
    CatalogEntry('Incline Barbell Press', 'Chest', 'Barbell', 50, '8-10'),
    CatalogEntry('Incline Dumbbell Press', 'Chest', 'Dumbbell', 22, '8-12'),
    CatalogEntry('Dumbbell Bench Press', 'Chest', 'Dumbbell', 24, '8-12'),
    CatalogEntry('Decline Bench Press', 'Chest', 'Barbell', 55, '8-10'),
    CatalogEntry('Machine Chest Press', 'Chest', 'Machine', 40, '10-12'),
    CatalogEntry('Pec Deck', 'Chest', 'Machine', 40, '12-15'),
    CatalogEntry('Cable Chest Fly', 'Chest', 'Cable', 15, '12-15'),
    CatalogEntry('Cable Crossover', 'Chest', 'Cable', 15, '12-15'),
    CatalogEntry('Dips', 'Chest', 'Bodyweight', 0, '8-12'),
    CatalogEntry('Push-up', 'Chest', 'Bodyweight', 0, '10-20'),
    // Back
    CatalogEntry('Deadlift', 'Back', 'Barbell', 90, '4-6'),
    CatalogEntry('Rack Pull', 'Back', 'Barbell', 100, '5-8'),
    CatalogEntry('Barbell Row', 'Back', 'Barbell', 50, '6-8'),
    CatalogEntry('Pendlay Row', 'Back', 'Barbell', 50, '6-8'),
    CatalogEntry('T-Bar Row', 'Back', 'Barbell', 45, '8-10'),
    CatalogEntry('Lat Pulldown', 'Back', 'Cable', 45, '8-10'),
    CatalogEntry('Straight-Arm Pulldown', 'Back', 'Cable', 25, '12-15'),
    CatalogEntry('Chest-Supported Row', 'Back', 'Machine', 40, '10-12'),
    CatalogEntry('Seated Cable Row', 'Back', 'Cable', 45, '10-12'),
    CatalogEntry('Single-Arm Dumbbell Row', 'Back', 'Dumbbell', 24, '10-12'),
    CatalogEntry('Pull-up', 'Back', 'Bodyweight', 0, '6-10'),
    CatalogEntry('Chin-up', 'Back', 'Bodyweight', 0, '6-10'),
    CatalogEntry('Face Pull', 'Back', 'Cable', 15, '15-20'),
    CatalogEntry('Back Extension', 'Back', 'Bodyweight', 0, '12-15'),
    CatalogEntry('Barbell Shrug', 'Back', 'Barbell', 60, '10-12'),
    // Legs (quads / hamstrings / calves)
    CatalogEntry('Back Squat', 'Legs', 'Barbell', 70, '6-8'),
    CatalogEntry('Front Squat', 'Legs', 'Barbell', 50, '8-10'),
    CatalogEntry('Goblet Squat', 'Legs', 'Dumbbell', 24, '8-12'),
    CatalogEntry('Bulgarian Split Squat', 'Legs', 'Dumbbell', 14, '8-12'),
    CatalogEntry('Hack Squat', 'Legs', 'Machine', 80, '10-12'),
    CatalogEntry('Leg Press', 'Legs', 'Machine', 120, '10-12'),
    CatalogEntry('Romanian Deadlift', 'Legs', 'Barbell', 60, '8-10'),
    CatalogEntry('Dumbbell RDL', 'Legs', 'Dumbbell', 22, '10-12'),
    CatalogEntry('Sumo Deadlift', 'Legs', 'Barbell', 80, '5-8'),
    CatalogEntry('Good Morning', 'Legs', 'Barbell', 40, '8-10'),
    CatalogEntry('Seated Leg Curl', 'Legs', 'Machine', 35, '12-15'),
    CatalogEntry('Lying Leg Curl', 'Legs', 'Machine', 30, '10-12'),
    CatalogEntry('Leg Extension', 'Legs', 'Machine', 35, '12-15'),
    CatalogEntry('Walking Lunge', 'Legs', 'Dumbbell', 14, '10-12'),
    CatalogEntry('Step-up', 'Legs', 'Dumbbell', 12, '10-12'),
    CatalogEntry('Standing Calf Raise', 'Legs', 'Machine', 40, '12-15'),
    CatalogEntry('Seated Calf Raise', 'Legs', 'Machine', 30, '15-20'),
    // Glutes (first-class per the plan)
    CatalogEntry('Hip Thrust', 'Glutes', 'Barbell', 60, '8-12'),
    CatalogEntry('Glute Bridge', 'Glutes', 'Bodyweight', 0, '15-20'),
    CatalogEntry('Hip Abduction', 'Glutes', 'Machine', 35, '12-15'),
    CatalogEntry('Cable Glute Kickback', 'Glutes', 'Cable', 10, '12-15'),
    CatalogEntry('Cable Pull-Through', 'Glutes', 'Cable', 25, '12-15'),
    // Shoulders
    CatalogEntry('Overhead Press', 'Shoulders', 'Barbell', 35, '6-8'),
    CatalogEntry('Seated Shoulder Press', 'Shoulders', 'Barbell', 35, '8-10'),
    CatalogEntry('Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell', 16, '10-12'),
    CatalogEntry('Arnold Press', 'Shoulders', 'Dumbbell', 14, '10-12'),
    CatalogEntry('Lateral Raise', 'Shoulders', 'Dumbbell', 8, '12-15'),
    CatalogEntry('Cable Lateral Raise', 'Shoulders', 'Cable', 7, '12-15'),
    CatalogEntry('Front Raise', 'Shoulders', 'Dumbbell', 8, '12-15'),
    CatalogEntry('Rear Delt Fly', 'Shoulders', 'Dumbbell', 8, '12-15'),
    CatalogEntry('Reverse Pec Deck', 'Shoulders', 'Machine', 35, '12-15'),
    CatalogEntry('Upright Row', 'Shoulders', 'Barbell', 30, '10-12'),
    // Arms
    CatalogEntry('EZ-Bar Curl', 'Arms', 'Barbell', 25, '8-10'),
    CatalogEntry('Barbell Curl', 'Arms', 'Barbell', 25, '8-10'),
    CatalogEntry('Incline Dumbbell Curl', 'Arms', 'Dumbbell', 10, '10-12'),
    CatalogEntry('Hammer Curl', 'Arms', 'Dumbbell', 10, '12-15'),
    CatalogEntry('Concentration Curl', 'Arms', 'Dumbbell', 10, '10-12'),
    CatalogEntry('Preacher Curl', 'Arms', 'Cable', 20, '12-15'),
    CatalogEntry('Cable Curl', 'Arms', 'Cable', 20, '10-12'),
    CatalogEntry('Triceps Pushdown', 'Arms', 'Cable', 25, '10-12'),
    CatalogEntry('Overhead Triceps Extension', 'Arms', 'Dumbbell', 15, '10-12'),
    CatalogEntry('Skullcrusher', 'Arms', 'Barbell', 20, '10-12'),
    CatalogEntry('Close-Grip Bench Press', 'Arms', 'Barbell', 45, '8-10'),
    CatalogEntry('Wrist Curl', 'Arms', 'Dumbbell', 8, '15-20'),
    // Core
    CatalogEntry('Hanging Leg Raise', 'Core', 'Bodyweight', 0, '10-15'),
    CatalogEntry('Cable Crunch', 'Core', 'Cable', 25, '12-15'),
    CatalogEntry('Crunch', 'Core', 'Bodyweight', 0, '15-20'),
    CatalogEntry('Plank', 'Core', 'Bodyweight', 0, '45-60'),
    CatalogEntry('Side Plank', 'Core', 'Bodyweight', 0, '30-45'),
    CatalogEntry('Ab Wheel Rollout', 'Core', 'Bodyweight', 0, '8-12'),
    CatalogEntry('Russian Twist', 'Core', 'Dumbbell', 10, '15-20'),
    CatalogEntry('Dead Bug', 'Core', 'Bodyweight', 0, '10-12'),
    CatalogEntry('Farmer\'s Carry', 'Core', 'Dumbbell', 24, '30-40'),
  ];

  static const muscleGroups = [
    'Chest',
    'Back',
    'Legs',
    'Glutes',
    'Shoulders',
    'Arms',
    'Core',
  ];

  static List<CatalogEntry> byMuscle(String muscle) =>
      all.where((e) => e.muscleGroup == muscle).toList();
}
