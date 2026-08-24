import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/supabase/plan_repository.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/core/providers/providers.dart';

/// A repository whose edit() we control, so we can hold a request open and
/// cancel it mid-flight the way a user hitting Stop does.
class _FakePlanRepository implements PlanRepository {
  final completer = Completer<PlanOutcome>();
  int editCalls = 0;

  @override
  Future<PlanOutcome> edit({
    required UserProfile profile,
    required Program program,
    required String instruction,
  }) {
    editCalls++;
    return completer.future;
  }

  @override
  Future<PlanOutcome> generate(UserProfile profile) => completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakePlanRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _FakePlanRepository();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        planRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  const profile = UserProfile(
    name: 'Tester',
    sex: 'Male',
    age: 28,
    height: 175,
    weight: 75,
    goal: 'Build Muscle',
    experience: '6–24 months',
    daysPerWeek: ['Mon', 'Wed', 'Fri'],
    equipment: 'Full gym',
    injuries: [],
    notificationPermission: false,
    avatar: '',
  );

  Program aDifferentPlan() => Program(
        id: 'ai-replacement',
        name: 'Replacement Plan',
        description: 'What the AI sent back.',
        whyFitsParagraph: 'Because.',
        days: [
          WorkoutDay(
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
          ),
        ],
        dayAssignments: const {'Mon': 'd1'},
      );

  test('a cancelled edit never overwrites the program', () async {
    final container = makeContainer();
    final notifier = container.read(programProvider.notifier);
    notifier.generateProgram(profile);
    final original = container.read(programProvider)!;

    var cancelled = false;
    final future = notifier.applyAiScheduleEdit(
      'make everything one rep',
      profile,
      isCancelled: () => cancelled,
    );

    // User hits Stop while the request is still in flight...
    cancelled = true;
    // ...and only then does the server reply.
    repo.completer.complete(
      PlanUpdated(program: aDifferentPlan(), note: 'Rewrote your week.'),
    );

    await expectLater(
      future,
      throwsA(isA<PlanException>()
          .having((e) => e.code, 'code', 'cancelled')),
    );

    // The whole point: the late reply did not land.
    expect(container.read(programProvider)!.id, original.id);
    expect(container.read(programProvider)!.name, original.name);
  });

  test('an uncancelled edit returns a proposal without applying it', () async {
    final container = makeContainer();
    final notifier = container.read(programProvider.notifier);
    notifier.generateProgram(profile);
    final original = container.read(programProvider)!;

    final future = notifier.applyAiScheduleEdit(
      'more glute work',
      profile,
      isCancelled: () => false,
    );
    repo.completer.complete(
      PlanUpdated(program: aDifferentPlan(), note: 'Added glute volume.'),
    );

    final outcome = await future;
    expect(outcome, isA<PlanUpdated>());
    expect((outcome as PlanUpdated).note, 'Added glute volume.');

    // Coach proposes, the user disposes. Nothing is written until the preview
    // sheet is accepted, so someone's training week is never rewritten behind
    // their back by a model reply.
    expect(container.read(programProvider)!.id, original.id);
  });

  test('accepting a proposal is what actually applies it', () async {
    final container = makeContainer();
    final notifier = container.read(programProvider.notifier);
    notifier.generateProgram(profile);

    final future = notifier.applyAiScheduleEdit('more glute work', profile);
    repo.completer.complete(
      PlanUpdated(program: aDifferentPlan(), note: 'Added glute volume.'),
    );
    final outcome = await future as PlanUpdated;

    // What the preview sheet does on "Apply this change".
    notifier.loadProgram(outcome.program);
    expect(container.read(programProvider)!.id, 'ai-replacement');
  });

  test('a proposal carries Coach\'s objection when it has one', () async {
    final container = makeContainer();
    final notifier = container.read(programProvider.notifier);
    notifier.generateProgram(profile);

    final future = notifier.applyAiScheduleEdit('add 3 more curls', profile);
    repo.completer.complete(
      PlanUpdated(
        program: aDifferentPlan(),
        note: 'Added the curls.',
        concern: 'That is more direct arm work than most people recover from.',
      ),
    );
    final outcome = await future as PlanUpdated;
    expect(outcome.concern, contains('recover from'));
  });

  test('a clarifying question leaves the program untouched', () async {
    final container = makeContainer();
    final notifier = container.read(programProvider.notifier);
    notifier.generateProgram(profile);
    final original = container.read(programProvider)!;

    final future = notifier.applyAiScheduleEdit('I want to focus', profile);
    repo.completer.complete(
      const PlanNeedsInfo('Focus on what — a muscle group, a lift, or fewer days?'),
    );

    final outcome = await future;
    expect(outcome, isA<PlanNeedsInfo>());
    expect(
      (outcome as PlanNeedsInfo).question,
      contains('Focus on what'),
    );
    // Coach asked instead of guessing, so nothing changed.
    expect(container.read(programProvider)!.id, original.id);
  });
}
