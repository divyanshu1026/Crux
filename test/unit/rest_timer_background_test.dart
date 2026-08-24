import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/core/providers/app_lifecycle.dart';
import 'package:crux/core/providers/providers.dart';

/// Regression cover for the two background bugs:
///   * rest finishing while the app was backgrounded silently swallowed the
///     alert, because the ticker assumed running == foregrounded;
///   * the workout clock restarted from zero whenever the screen was rebuilt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith({required bool foreground}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appIsForegroundProvider.overrideWith(() => _FixedLifecycle(foreground)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  WorkoutDay aDay() => WorkoutDay(
        id: 'd1',
        name: 'Day 1',
        exercises: [
          Exercise(
            id: 'e1',
            name: 'Back Squat',
            muscleGroup: 'Legs',
            equipment: 'Barbell',
            targetSets: 3,
            targetReps: '8-12',
            restTimeSeconds: 90,
            suggestedWeight: 60,
          ),
        ],
      );

  group('workout clock', () {
    test('start time is recorded on the session, not the widget', () {
      final c = containerWith(foreground: true);
      final notifier = c.read(activeWorkoutProvider.notifier);
      notifier.startWorkout(aDay(), 'p1', const {});

      final session = c.read(activeWorkoutProvider)!;
      expect(session.startedAt, isNotNull,
          reason: 'the clock anchor has to outlive the screen');
      expect(
        DateTime.now().difference(session.startedAt!).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('start time survives a round trip through storage', () {
      final c = containerWith(foreground: true);
      c.read(activeWorkoutProvider.notifier).startWorkout(aDay(), 'p1', const {});
      final original = c.read(activeWorkoutProvider)!;

      // What the app does on relaunch.
      final restored = WorkoutSession.fromJson(original.toJson());
      expect(restored.startedAt, isNotNull);
      expect(
        restored.startedAt!.toIso8601String(),
        original.startedAt!.toIso8601String(),
      );
    });

    test('backdated sessions still time from now, not the logged date', () {
      final c = containerWith(foreground: true);
      final lastWeek = DateTime.now().subtract(const Duration(days: 7));
      c.read(activeWorkoutProvider.notifier).startWorkout(
            aDay(),
            'p1',
            const {},
            forDate: lastWeek,
          );

      final session = c.read(activeWorkoutProvider)!;
      expect(session.date.day, lastWeek.day);
      // A week-long elapsed timer would be absurd.
      expect(
        DateTime.now().difference(session.startedAt!).inMinutes,
        lessThan(1),
      );
    });
  });

  group('rest alert', () {
    test('does not fire the in-app alert while backgrounded', () async {
      final c = containerWith(foreground: false);
      final notifier = c.read(activeWorkoutProvider.notifier);
      notifier.startWorkout(aDay(), 'p1', const {});
      c.read(appSettingsProvider.notifier).setRestCompleteSound(true);

      notifier.debugCompleteRestNow();

      expect(
        notifier.restCompleteAlert,
        isFalse,
        reason: 'the OS notification owns this case; an in-app chime that '
            'cannot be heard must not suppress it',
      );
    });

    test('fires the in-app alert when foregrounded', () async {
      final c = containerWith(foreground: true);
      final notifier = c.read(activeWorkoutProvider.notifier);
      notifier.startWorkout(aDay(), 'p1', const {});
      c.read(appSettingsProvider.notifier).setRestCompleteSound(true);

      notifier.debugCompleteRestNow();

      expect(notifier.restCompleteAlert, isTrue);
    });

    test('a long-overdue finish does not ring late', () async {
      final c = containerWith(foreground: true);
      final notifier = c.read(activeWorkoutProvider.notifier);
      notifier.startWorkout(aDay(), 'p1', const {});
      c.read(appSettingsProvider.notifier).setRestCompleteSound(true);

      // Rest ended while the phone was in a pocket; the user reopens later.
      notifier.debugCompleteRestNow(
        endedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );

      expect(
        notifier.restCompleteAlert,
        isFalse,
        reason: 'rest ended three minutes ago — the notification already said so',
      );
    });
  });

}

class _FixedLifecycle extends AppLifecycleNotifier {
  _FixedLifecycle(this._value);
  final bool _value;

  @override
  bool build() => _value;
}
