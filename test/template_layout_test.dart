import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/core/providers/providers.dart';

/// Loading a plan from the library must produce the week the plan's card
/// promises. A "3 days" plan that lands as a five-day week (two sessions run
/// twice) is the bug this covers.
void main() {
  WorkoutDay day(String id) => WorkoutDay(id: id, name: id, exercises: const []);

  Program template({
    required List<String> dayIds,
    required Map<String, String> layout,
  }) =>
      Program(
        id: 't',
        name: 'T',
        description: '',
        whyFitsParagraph: '',
        days: [for (final id in dayIds) day(id)],
        dayAssignments: layout,
      );

  group('weeklyFrequency', () {
    test('counts days trained, not sessions written', () {
      // PPL x 2: three sessions across six weekdays.
      final ppl = template(
        dayIds: ['push', 'pull', 'legs'],
        layout: const {
          'Mon': 'push',
          'Tue': 'pull',
          'Wed': 'legs',
          'Thu': 'push',
          'Fri': 'pull',
          'Sat': 'legs',
        },
      );
      expect(ProgramNotifier.weeklyFrequency(ppl), 6);
    });

    test('falls back to session count when the plan has no layout', () {
      final bare = template(dayIds: ['a', 'b'], layout: const {});
      expect(ProgramNotifier.weeklyFrequency(bare), 2);
    });
  });

  group('fitTemplateToWeek', () {
    final fullBody3 = template(
      dayIds: ['a', 'b', 'c'],
      layout: const {'Mon': 'a', 'Wed': 'b', 'Fri': 'c'},
    );

    test('keeps a 3-day plan at 3 days even when the profile trains 5', () {
      final fitted = ProgramNotifier.fitTemplateToWeek(
        fullBody3,
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
      expect(fitted.dayAssignments.length, 3);
      expect(fitted.dayAssignments.values.toSet(), {'a', 'b', 'c'});
    });

    test('spreads those days out rather than stacking them', () {
      final fitted = ProgramNotifier.fitTemplateToWeek(
        fullBody3,
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
      expect(fitted.dayAssignments.keys.toList(), ['Mon', 'Wed', 'Fri']);
    });

    test('uses the days the user actually chose', () {
      final fitted = ProgramNotifier.fitTemplateToWeek(
        fullBody3,
        const ['Tue', 'Thu', 'Sat'],
      );
      expect(fitted.dayAssignments.keys.toList(), ['Tue', 'Thu', 'Sat']);
    });

    test('keeps the plan\'s own week when the user offers too few days', () {
      final fitted =
          ProgramNotifier.fitTemplateToWeek(fullBody3, const ['Mon', 'Tue']);
      expect(fitted.dayAssignments, fullBody3.dayAssignments);
    });

    test('repeats sessions only when the plan itself does', () {
      final ppl = template(
        dayIds: ['push', 'pull', 'legs'],
        layout: const {
          'Mon': 'push',
          'Tue': 'pull',
          'Wed': 'legs',
          'Thu': 'push',
          'Fri': 'pull',
          'Sat': 'legs',
        },
      );
      final fitted = ProgramNotifier.fitTemplateToWeek(
        ppl,
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
      expect(fitted.dayAssignments.length, 6);
    });
  });
}
