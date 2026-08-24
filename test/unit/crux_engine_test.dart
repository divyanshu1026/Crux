import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/core/providers/providers.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/program_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('XP Engine / Level-up logic Tests', () {
    test('addXp correctly increases levels and rolls over remaining XP', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Verify initial level and XP
      var profile = container.read(userProfileProvider);
      expect(profile.level, equals(1));
      expect(profile.xp, equals(0));

      // Plan curve: XP to advance from level L = 100 × L^1.5.
      // Level 1 → 2 needs 100 XP. Let's add 160 XP.
      final leveledUp = container.read(userProfileProvider.notifier).addXp(160);
      profile = container.read(userProfileProvider);

      expect(leveledUp, isTrue);
      expect(profile.level, equals(2));
      expect(profile.xp, equals(60)); // 160 - 100 = 60 XP remaining
    });

    test('addXp multi-level increases work correctly', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Plan curve 100 × L^1.5: level 1 needs 100, level 2 needs 283.
      // 500 XP → level 3 with 500 - 100 - 283 = 117 remaining.
      final leveledUp = container.read(userProfileProvider.notifier).addXp(500);
      final profile = container.read(userProfileProvider);

      expect(leveledUp, isTrue);
      expect(profile.level, equals(3));
      expect(profile.xp, equals(117));
    });
  });

  group('Program Generator logic Tests', () {
    test('Picks a 3-day male template for 3 training days', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final user = const UserProfile(
        name: 'Tester',
        sex: 'Male',
        age: 25,
        height: 175,
        weight: 75,
        goal: 'General Fitness',
        experience: 'Never trained',
        daysPerWeek: ['Mon', 'Wed', 'Fri'],
        equipment: 'Full gym',
        injuries: [],
        notificationPermission: false,
        avatar: '',
      );

      container.read(programProvider.notifier).generateProgram(user);
      final program = container.read(programProvider);

      expect(program, isNotNull);
      expect(program!.days.length, equals(3));
      expect(program.dayAssignments.length, equals(3));
      expect(program.dayAssignments.keys, containsAll(['Mon', 'Wed', 'Fri']));
    });

    test('Female catalog is used for Female profiles', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final user = const UserProfile(
        name: 'Tester',
        sex: 'Female',
        age: 28,
        height: 165,
        weight: 60,
        goal: 'Build Muscle',
        experience: '6–24 months',
        daysPerWeek: ['Mon', 'Tue', 'Thu', 'Fri'],
        equipment: 'Full gym',
        injuries: [],
        notificationPermission: false,
        avatar: '',
      );

      container.read(programProvider.notifier).generateProgram(user);
      final program = container.read(programProvider);

      expect(program, isNotNull);
      final femaleIds =
          ProgramTemplates.femaleCatalog().map((p) => p.id).toSet();
      expect(femaleIds.contains(program!.id), isTrue);
      expect(program.days.isNotEmpty, isTrue);
    });

    test('Male strength goal prefers a strength-oriented template', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final user = const UserProfile(
        name: 'Tester',
        sex: 'Male',
        age: 25,
        height: 175,
        weight: 75,
        goal: 'Get Stronger',
        experience: '2+ years',
        daysPerWeek: ['Mon', 'Tue', 'Thu', 'Fri'],
        equipment: 'Full gym',
        injuries: [],
        notificationPermission: false,
        avatar: '',
      );

      container.read(programProvider.notifier).generateProgram(user);
      final program = container.read(programProvider);

      expect(program, isNotNull);
      final name = program!.name.toLowerCase();
      expect(
        name.contains('strength') || name.contains('power'),
        isTrue,
      );
    });
  });

  group('Progressive Overload Engine logic Tests', () {
    test('Suggests +5kg on leg compound if all sets hit top reps (12)', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final day = const WorkoutDay(
        id: 'day_1',
        name: 'Day 1',
        exercises: [
          Exercise(
            id: 'l1',
            name: 'Barbell Squat',
            muscleGroup: 'Legs', // Lower body compound
            equipment: 'Full gym',
            targetSets: 3,
            targetReps: '8-12',
            suggestedWeight: 70.0,
          ),
        ],
      );

      // Start the workout
      container.read(activeWorkoutProvider.notifier).startWorkout(day, 'prog_1', {});

      // Log all sets at 12 reps (top rep target)
      container.read(activeWorkoutProvider.notifier).updateSetReps('l1', 0, 12);
      container.read(activeWorkoutProvider.notifier).updateSetReps('l1', 1, 12);
      container.read(activeWorkoutProvider.notifier).updateSetReps('l1', 2, 12);

      container.read(activeWorkoutProvider.notifier).logSet('l1', 0);
      container.read(activeWorkoutProvider.notifier).logSet('l1', 1);
      container.read(activeWorkoutProvider.notifier).logSet('l1', 2);

      final completedSession = container.read(activeWorkoutProvider.notifier).finishWorkout();

      final squatSuggestion = completedSession.overloadSuggestions['Barbell Squat'];
      expect(squatSuggestion, contains('Suggest increasing weight by +5.0kg'));
    });
  });
}
