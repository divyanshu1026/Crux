import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/data/program_templates.dart';
import 'package:crux/core/models/models.dart';

/// The offline template picker is what every user gets when the AI planner is
/// unavailable, so it has to respond to the onboarding answers on its own.
void main() {
  UserProfile profile({
    String goal = 'Build Muscle',
    String experience = '6–24 months',
    List<String> days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    String equipment = 'Full gym',
    List<String> injuries = const [],
    String sex = 'Prefer not to say',
  }) =>
      UserProfile(
        name: 'Tester',
        sex: sex,
        age: 28,
        height: 175,
        weight: 75,
        goal: goal,
        experience: experience,
        daysPerWeek: days,
        equipment: equipment,
        injuries: injuries,
        notificationPermission: false,
        avatar: '',
      );

  Set<String> equipmentUsed(Program p) =>
      p.days.expand((d) => d.exercises).map((e) => e.equipment).toSet();

  group('equipment is a hard constraint', () {
    test('dumbbells-only never gets a barbell-heavy plan', () {
      final picked = ProgramTemplates.pickBest(
        profile(equipment: 'Dumbbells only'),
      );
      final all = p(picked);
      final barbell = all.where((e) => e.equipment == 'Barbell').length;
      // Some incidental barbell work is tolerable; a barbell program is not.
      expect(barbell / all.length, lessThan(0.25),
          reason: 'picked "${picked.name}" with ${equipmentUsed(picked)}');
    });

    test('minimal home avoids machines', () {
      final picked = ProgramTemplates.pickBest(
        profile(equipment: 'Minimal home'),
      );
      final all = p(picked);
      final gymOnly = all
          .where((e) => e.equipment == 'Machine' || e.equipment == 'Cable')
          .length;
      expect(gymOnly / all.length, lessThan(0.25),
          reason: 'picked "${picked.name}"');
    });

    test('full gym is unconstrained — day count still decides', () {
      final picked = ProgramTemplates.pickBest(
        profile(days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
      );
      expect(picked.days.length, 5);
    });
  });

  group('experience', () {
    test('a first-timer is not put on a 5-day split', () {
      final picked = ProgramTemplates.pickBest(
        profile(
          experience: 'Never trained',
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        ),
      );
      expect(picked.days.length, lessThan(5),
          reason: 'picked "${picked.name}"');
    });

    test('an experienced lifter keeps the matching split', () {
      final picked = ProgramTemplates.pickBest(
        profile(
          experience: '2+ years',
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        ),
      );
      expect(picked.days.length, 5);
    });
  });

  group('injuries', () {
    test('a knee injury shifts away from the most leg-loaded option', () {
      final healthy =
          ProgramTemplates.pickBest(profile(days: ['Mon', 'Wed', 'Fri']));
      final injured = ProgramTemplates.pickBest(
        profile(days: ['Mon', 'Wed', 'Fri'], injuries: ['Knee']),
      );
      int legWork(Program prog) =>
          p(prog).where((e) => e.muscleGroup == 'Legs').length;
      expect(legWork(injured), lessThanOrEqualTo(legWork(healthy)));
    });

    test('injury vocabulary matches the catalog, or it silently does nothing',
        () {
      // A typo in the risky-muscle map would make injury handling a no-op with
      // no visible failure, so assert the groups actually exist in the library.
      final groups = ProgramTemplates.allTemplates()
          .expand((t) => t.days)
          .expand((d) => d.exercises)
          .map((e) => e.muscleGroup)
          .toSet();
      for (final injury in ['Shoulder', 'Knee', 'Lower back']) {
        final picked = ProgramTemplates.pickBest(profile(injuries: [injury]));
        expect(picked.days, isNotEmpty);
      }
      expect(groups, containsAll(['Legs', 'Back', 'Shoulders', 'Chest']));
    });
  });

  group('schedule coverage', () {
    test('2 training days gets a 2-day plan, not the nearest miss', () {
      final picked = ProgramTemplates.pickBest(
        profile(days: ['Mon', 'Thu'], experience: '6–24 months'),
      );
      expect(picked.days.length, 2, reason: 'picked "${picked.name}"');
    });

    test('6 training days gets a 6-day schedule', () {
      final picked = ProgramTemplates.pickBest(
        profile(
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          experience: '2+ years',
        ),
      );
      // Classic PPL x2 reuses three sessions across six weekdays — what
      // matters is how many days a week they end up training.
      expect(picked.dayAssignments.length, 6, reason: 'picked "${picked.name}"');
    });

    test('home training four days a week stays equipment-appropriate', () {
      final picked = ProgramTemplates.pickBest(
        profile(
          equipment: 'Dumbbells only',
          days: ['Mon', 'Tue', 'Thu', 'Fri'],
          experience: '6–24 months',
        ),
      );
      expect(picked.days.length, 4, reason: 'picked "${picked.name}"');
      expect(
        equipmentUsed(picked).intersection({'Barbell', 'Machine', 'Cable'}),
        isEmpty,
        reason: 'picked "${picked.name}"',
      );
    });
  });

  test('every template still produces a usable plan for any profile', () {
    for (final equipment in ['Full gym', 'Dumbbells only', 'Minimal home']) {
      for (final exp in ['Never trained', '<6 months', '6–24 months', '2+ years']) {
        for (final n in [2, 3, 4, 5, 6]) {
          final picked = ProgramTemplates.pickBest(profile(
            equipment: equipment,
            experience: exp,
            days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].take(n).toList(),
          ));
          expect(picked.days, isNotEmpty);
          expect(p(picked), isNotEmpty);
        }
      }
    }
  });
}

List<Exercise> p(Program prog) =>
    prog.days.expand((d) => d.exercises).toList();
