import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/coach/coach_api.dart';
import '../data/coach/coach_snapshot.dart';
import '../data/coach/coach_text.dart';
import '../data/local_store.dart';
import '../data/program_templates.dart';
import '../data/supabase/auth_repository.dart';
import '../data/supabase/plan_repository.dart';
import '../data/supabase/sync_service.dart';
import '../domain/gamification.dart';
import '../domain/nutrition.dart';
import '../domain/progression.dart';
import '../domain/schedule_request.dart';
import '../services/notification_service.dart';
import '../models/models.dart';
import 'app_lifecycle.dart';
import '../theme/theme.dart';

// ---------------------------------------------------------------------------
// 0. Clock
// ---------------------------------------------------------------------------

/// The current time, as a provider.
///
/// Screens that change with the wall clock — the Today greeting, which weekday
/// is highlighted, which session is "today's" — read time through this so tests
/// can pin an instant. Without it a golden generated in the evening fails the
/// next morning for reasons that have nothing to do with the code.
///
/// Override in tests: `clockProvider.overrideWithValue(() => DateTime(...))`.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// ---------------------------------------------------------------------------
// 1. User Profile Provider
// ---------------------------------------------------------------------------

class UserProfileNotifier extends Notifier<UserProfile> {
  static const _default = UserProfile(
    name: '',
    sex: 'Prefer not to say',
    age: 25,
    height: 175,
    weight: 75.0,
    goal: 'Build Muscle',
    experience: 'Never trained',
    daysPerWeek: ['Mon', 'Wed', 'Fri'],
    equipment: 'Full gym',
    injuries: [],
    notificationPermission: false,
    avatar: 'assets/images/yorhart_neutral.png',
    level: 1,
    xp: 0,
    streak: 0,
    hasCompletedOnboarding: false,
  );

  @override
  UserProfile build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kProfile, next.toJson()));
    final saved = store.getMap(LocalStore.kProfile);
    final profile = saved != null ? UserProfile.fromJson(saved) : _default;

    // Legacy / demo data could leave a fake streak with no workouts. Clear it.
    if (profile.streak > 0) {
      Future.microtask(() {
        final history = ref.read(workoutHistoryProvider);
        final real = history.where((s) => s.completed && !s.id.startsWith('past_'));
        if (real.isEmpty && state.streak != 0) {
          state = state.copyWith(streak: 0);
        }
      });
    }
    return profile;
  }

  void updateProfile(UserProfile profile) {
    state = profile;
  }

  void reset() {
    state = _default;
  }

  void completeOnboarding() {
    state = state.copyWith(
      hasCompletedOnboarding: true,
      // Brand-new athletes start at zero streak — never inherit demo values.
      streak: 0,
    );
    // Persist to cloud so the next login / restore keeps onboarding done.
    if (ref.read(authRepositoryProvider).isCloud) {
      unawaited(() async {
        try {
          await ref.read(syncServiceProvider).backup(ref.read);
        } catch (_) {}
      }());
    }
  }

  bool addXp(int amount) {
    int newXp = state.xp + amount;
    int newLevel = state.level;
    bool leveledUp = false;

    // Plan level curve: XP to advance from level L = 100 × L^1.5.
    while (newXp >= levelXpThreshold(newLevel)) {
      newXp -= levelXpThreshold(newLevel);
      newLevel++;
      leveledUp = true;
    }

    state = state.copyWith(xp: newXp, level: newLevel);
    return leveledUp;
  }

  void setAvatar(String avatarPath) {
    state = state.copyWith(avatar: avatarPath);
  }

  void incrementStreak() {
    state = state.copyWith(streak: state.streak + 1);
  }

  /// Daily streak guard (plan Phase 5.3): once per calendar day, checks whether
  /// a planned training day was missed since the last workout. One Rest Pass
  /// per month auto-absorbs a single miss; otherwise the streak resets.
  /// Returns a user-facing message only when something changed.
  String? runDailyStreakCheck(List<WorkoutSession> history) {
    final store = ref.read(localStoreProvider);
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (store.getString(LocalStore.kStreakCheckedOn) == todayKey) return null;
    store.setString(LocalStore.kStreakCheckedOn, todayKey);

    DateTime? lastWorkout;
    for (final s in history) {
      if (s.completed && (lastWorkout == null || s.date.isAfter(lastWorkout))) {
        lastWorkout = s.date;
      }
    }

    final verdict = StreakGuard.evaluate(
      today: today,
      lastWorkout: lastWorkout,
      plannedWeekdays: state.daysPerWeek,
      currentStreak: state.streak,
      restPassesRemaining: state.restPassesRemaining,
      lastRestPassMonth: state.lastRestPassMonth,
    );
    state = state.copyWith(
      streak: verdict.streak,
      restPassesRemaining: verdict.restPassesRemaining,
      lastRestPassMonth: verdict.lastRestPassMonth,
    );
    return verdict.message;
  }

  void setUnits(String units) {
    state = state.copyWith(units: units);
  }

  void toggleZenMode() {
    state = state.copyWith(zenMode: !state.zenMode);
  }

  /// Mirrors the entitlement the **server** granted.
  ///
  /// Deliberately named for where the answer comes from. The old `setPro(true)`
  /// was called straight from the paywall's success handler, which meant the
  /// client decided who had paid — anyone tapping the button got Pro. Only
  /// billing code that has just heard from the server should call this.
  void applyServerEntitlement({required bool isPro, DateTime? expiresAt}) {
    state = UserProfile(
      name: state.name,
      sex: state.sex,
      age: state.age,
      height: state.height,
      weight: state.weight,
      goal: state.goal,
      experience: state.experience,
      daysPerWeek: state.daysPerWeek,
      equipment: state.equipment,
      injuries: state.injuries,
      notificationPermission: state.notificationPermission,
      avatar: state.avatar,
      level: state.level,
      xp: state.xp,
      streak: state.streak,
      hasCompletedOnboarding: state.hasCompletedOnboarding,
      units: state.units,
      zenMode: state.zenMode,
      isPro: isPro,
      // Rebuilt rather than copyWith'd because copyWith cannot clear a
      // nullable field, and an expiry that survives a downgrade would keep
      // granting access after the subscription ended.
      proExpiresAt: expiresAt,
      restPassesRemaining: state.restPassesRemaining,
      lastRestPassMonth: state.lastRestPassMonth,
    );
  }

  /// Wipes the profile back to a fresh, pre-onboarding state (Settings →
  /// delete data). Callers should also invalidate the other data providers.
  void resetToDefault() {
    state = _default;
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);

// ---------------------------------------------------------------------------
// 2. Program Provider & Rule-Based Program Generator
// ---------------------------------------------------------------------------

class ProgramNotifier extends Notifier<Program?> {
  @override
  Program? build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) {
      if (next != null) {
        store.setJson(LocalStore.kProgram, next.toJson());
      } else {
        store.remove(LocalStore.kProgram);
      }
    });
    final saved = store.getMap(LocalStore.kProgram);
    if (saved == null) return null;

    // Heal on restore, not just on write. Anyone already carrying a program
    // whose sessions aren't all scheduled — from a malformed AI reply before
    // the server-side check existed — gets their week put back together on the
    // next launch instead of staying stuck on it forever.
    final restored = Program.fromJson(saved);
    final repaired = repairAssignments(restored, ref.read(userProfileProvider));
    if (!identical(repaired, restored)) {
      // The profile's training days were derived from the broken layout, so
      // they need putting back too — deferred because we're inside build().
      Future<void>.microtask(
          () => _syncProfileTrainingDays(repaired.dayAssignments));
    }
    return repaired;
  }

  /// Builds the user's starting schedule from the sex-specific template catalog
  /// (coach-authored plans), remapped onto their chosen training days.
  void generateProgram(UserProfile profile) {
    final template = ProgramTemplates.pickBest(profile);
    final injuryText =
        profile.injuries.isEmpty ? 'none flagged' : profile.injuries.join(', ');
    final sexLabel = switch (profile.sex) {
      'Male' => 'men',
      'Female' => 'women',
      _ => 'your goals',
    };

    final why =
        '${template.whyFitsParagraph} We picked this from the $sexLabel schedule library to match your goal (${profile.goal.toLowerCase()}), ${profile.daysPerWeek.length} training days, and ${profile.equipment.toLowerCase()}. Injuries considered: $injuryText. Edit any day before you confirm.';

    final days = template.days;
    final assignments = profile.daysPerWeek.isEmpty
        ? template.dayAssignments
        : buildAutoAssignments(profile.daysPerWeek, days);

    state = Program(
      id: template.id,
      name: template.name,
      description: template.description,
      days: days,
      whyFitsParagraph: why,
      dayAssignments: assignments,
    );
  }

  /// Distributes program days across the selected weekdays in week order —
  /// the deterministic "coach builds your week" logic used at generation time
  /// and by the schedule screen's auto-build.
  static Map<String, String> buildAutoAssignments(
      List<String> selectedWeekdays, List<WorkoutDay> days) {
    if (days.isEmpty) return const {};
    final ordered =
        Program.weekdays.where(selectedWeekdays.contains).toList();
    final map = <String, String>{};
    for (var i = 0; i < ordered.length; i++) {
      map[ordered[i]] = days[i % days.length].id;
    }
    return map;
  }

  /// How many days a week [program] is designed to train.
  ///
  /// Sessions written ≠ days trained: "Classic PPL × 2" is three sessions run
  /// across six weekdays, and "Full Body Beginner" is three sessions on three
  /// days. The layout the plan ships with is the honest answer, so it is what
  /// the library shows and what loading the plan produces.
  static int weeklyFrequency(Program program) =>
      program.dayAssignments.isNotEmpty
          ? program.dayAssignments.length
          : program.days.length;

  /// Lays [template] onto the user's preferred weekdays **without changing how
  /// many days it trains**.
  ///
  /// The old behaviour spread every template across every day the profile said
  /// the user trains, so picking a plan labelled "3 days" while the profile
  /// held five training days produced a five-day week with two sessions run
  /// twice. The card promised three days; the schedule delivered five.
  static Program fitTemplateToWeek(
      Program template, List<String> preferredDays) {
    if (template.days.isEmpty) return template;
    final wanted = weeklyFrequency(template);
    final pool = Program.weekdays.where(preferredDays.contains).toList();

    // Not enough days offered to hold the plan → keep the plan's own layout,
    // which is always a sane week.
    final List<String> chosen;
    if (pool.length < wanted) {
      chosen = template.dayAssignments.isNotEmpty
          ? Program.weekdays
              .where(template.dayAssignments.containsKey)
              .toList()
          : Program.weekdays.take(wanted).toList();
    } else {
      chosen = _spreadAcross(pool, wanted);
    }

    // Sessions follow the template's own order, cycling when it runs fewer
    // sessions than days (that repetition is the design in PPL × 2).
    final map = <String, String>{};
    for (var i = 0; i < chosen.length; i++) {
      map[chosen[i]] = template.days[i % template.days.length].id;
    }
    return template.copyWith(dayAssignments: map);
  }

  /// Picks [n] weekdays out of [pool], spread as evenly as the pool allows —
  /// three out of Mon–Fri gives Mon/Wed/Fri, not Mon/Tue/Wed.
  static List<String> _spreadAcross(List<String> pool, int n) {
    if (n >= pool.length) return pool;
    if (n <= 1) return [pool.first];
    final picked = <String>{};
    for (var i = 0; i < n; i++) {
      picked.add(pool[((pool.length - 1) * i / (n - 1)).round()]);
    }
    // Rounding can collide on short pools; top up in order so the count is
    // always exactly what the plan asked for.
    for (final day in pool) {
      if (picked.length >= n) break;
      picked.add(day);
    }
    return Program.weekdays.where(picked.contains).toList();
  }

  /// Assigns [dayId] to a weekday (null = make it a rest day). Keeps the
  /// profile's training days in sync so streaks/Today logic stay consistent.
  void assignWorkoutToWeekday(String weekday, String? dayId) {
    if (state == null) return;
    final map = Map<String, String>.from(state!.dayAssignments);
    if (dayId == null) {
      map.remove(weekday);
    } else {
      map[weekday] = dayId;
    }
    state = state!.copyWith(dayAssignments: map);
    _syncProfileTrainingDays(map);
  }

  /// Rebuilds the whole week from the currently selected training days.
  void autoAssignSchedule(List<String> selectedWeekdays) {
    if (state == null) return;
    final map = buildAutoAssignments(selectedWeekdays, state!.days);
    state = state!.copyWith(dayAssignments: map);
    _syncProfileTrainingDays(map);
  }

  void _syncProfileTrainingDays(Map<String, String> assignments) {
    final trainingDays =
        Program.weekdays.where(assignments.containsKey).toList();
    final profile = ref.read(userProfileProvider);
    ref
        .read(userProfileProvider.notifier)
        .updateProfile(profile.copyWith(daysPerWeek: trainingDays));

    // Keep training-day reminders aligned with the new schedule.
    if (ref.read(appSettingsProvider).remindersEnabled) {
      unawaited(NotificationService.instance
          .scheduleTrainingReminders(trainingDays));
    }
  }

  void swapExercise(String dayId, String oldExerciseId, Exercise newExercise) {
    if (state == null) return;
    final updatedDays = state!.days.map((day) {
      if (day.id != dayId) return day;
      final updatedExercises = day.exercises.map((ex) {
        if (ex.id != oldExerciseId) return ex;
        return newExercise.copyWith(id: oldExerciseId);
      }).toList();
      return day.copyWith(exercises: updatedExercises);
    }).toList();
    state = state!.copyWith(days: updatedDays);
  }

  // ---- Day editing (day detail screen) ----------------------------------

  void _mutateDay(String dayId, WorkoutDay Function(WorkoutDay) update) {
    if (state == null) return;
    final updatedDays = state!.days
        .map((day) => day.id == dayId ? update(day) : day)
        .toList();
    state = state!.copyWith(days: updatedDays);
  }

  void renameDay(String dayId, String name) =>
      _mutateDay(dayId, (day) => day.copyWith(name: name));

  void addExerciseToDay(String dayId, Exercise ex) {
    _mutateDay(dayId, (day) {
      // Give the new exercise a unique id within the day.
      final newEx = ex.copyWith(
          id: '${dayId}_add_${DateTime.now().millisecondsSinceEpoch}');
      return day.copyWith(exercises: [...day.exercises, newEx]);
    });
  }

  void removeExerciseFromDay(String dayId, String exerciseId) {
    _mutateDay(
        dayId,
        (day) => day.copyWith(
            exercises:
                day.exercises.where((e) => e.id != exerciseId).toList()));
  }

  void updateExerciseInDay(
    String dayId,
    String exerciseId, {
    int? targetSets,
    String? targetReps,
    int? restTimeSeconds,
    double? suggestedWeight,
  }) {
    _mutateDay(dayId, (day) {
      final updated = day.exercises.map((ex) {
        if (ex.id != exerciseId) return ex;
        return ex.copyWith(
          targetSets: targetSets,
          targetReps: targetReps,
          restTimeSeconds: restTimeSeconds,
          suggestedWeight: suggestedWeight,
        );
      }).toList();
      return day.copyWith(exercises: updated);
    });
  }

  void reorderExercisesInDay(String dayId, int oldIndex, int newIndex) {
    _mutateDay(dayId, (day) {
      final list = List<Exercise>.from(day.exercises);
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      return day.copyWith(exercises: list);
    });
  }

  /// Replaces the entire program (used by template import / coach swaps).
  void loadProgram(Program program) {
    state = repairAssignments(program, ref.read(userProfileProvider));
    _syncProfileTrainingDays(state!.dayAssignments);
  }

  /// Guarantees every session in [program] is actually scheduled on a weekday.
  ///
  /// The app derives the user's training days *from* these assignments, so a
  /// program that only places some of its sessions doesn't just look wrong —
  /// it rewrites the profile to match, and every template loaded afterwards is
  /// then laid out across that shrunken week. One malformed reply was enough
  /// to leave someone on "5 workouts across 1 training day" permanently.
  ///
  /// Repairing here as well as on the server is deliberate: this also heals
  /// programs already saved on the device from before the server was fixed.
  @visibleForTesting
  static Program repairAssignments(Program program, UserProfile profile) {
    if (program.days.isEmpty) return program;
    final placed = program.dayAssignments.values.toSet();
    final everySessionPlaced =
        program.days.every((d) => placed.contains(d.id));
    if (everySessionPlaced && program.dayAssignments.isNotEmpty) {
      return program;
    }

    // Prefer the days the user actually said they train, as long as there are
    // enough of them to fit the program; otherwise spread from Monday.
    final preferred = profile.daysPerWeek.length >= program.days.length
        ? profile.daysPerWeek
        : Program.weekdays.take(program.days.length).toList();
    return program.copyWith(
      dayAssignments: buildAutoAssignments(preferred, program.days),
    );
  }

  /// Replaces the program with one Coach built for [profile].
  ///
  /// Returns the note to show, or null when the AI wasn't available and the
  /// caller should stay on the template plan. Never throws and never leaves
  /// the user without a program — [generateProgram] has already run by the
  /// time this is called, so failure just means "keep what you have".
  Future<String?> generateProgramWithAI(UserProfile profile) async {
    try {
      final result = await ref.read(planRepositoryProvider).generate(profile);
      // The server never asks a clarifying question when building from
      // scratch — there is no instruction to be ambiguous about — but if one
      // ever arrives, keep the template rather than stranding the user.
      if (result is! PlanUpdated) return null;
      loadProgram(result.program);
      return result.note;
    } on PlanException catch (e) {
      debugPrint('AI plan generation skipped: ${e.code}');
      return null;
    }
  }

  /// Sends a schedule change to Coach and applies the plan it returns.
  ///
  /// Unlike [applyCoachScheduleEdit] this understands anything, because a model
  /// reads it. Throws [PlanException] so the UI can tell the user why nothing
  /// happened instead of silently doing nothing.
  ///
  /// Returns [PlanNeedsInfo] when the request was too vague to act on — the
  /// program is left untouched and the caller shows the question.
  ///
  /// [isCancelled] is polled once, immediately before the new plan is written.
  /// A user who hits stop after sending the wrong thing must not have their
  /// week rewritten by it — the request cannot be recalled from the server,
  /// but its result can be thrown away, and that is the part they care about.
  Future<PlanOutcome> applyAiScheduleEdit(
    String instruction,
    UserProfile profile, {
    bool Function()? isCancelled,
  }) async {
    final current = state;
    if (current == null) {
      throw PlanException('Generate a schedule first.', 'no_program');
    }
    final result = await ref.read(planRepositoryProvider).edit(
          profile: profile,
          program: current,
          instruction: instruction,
        );
    if (isCancelled?.call() ?? false) {
      throw PlanException('Cancelled.', 'cancelled');
    }
    // Deliberately NOT applied here. Coach proposes; the user decides. The
    // caller shows the diff and Coach's reasoning, and calls [loadProgram]
    // only if they accept. Rewriting someone's training week the instant a
    // model replies is not something to do behind their back.
    return result;
  }

  /// Applies a natural-language schedule tweak using deterministic keyword
  /// matching — instant, free, and works offline.
  ///
  /// This is the fast path only. It recognises a fixed vocabulary; anything
  /// else returns null so the caller can hand the request to
  /// [applyAiScheduleEdit], which actually understands English.
  String? applyCoachScheduleEdit(String userMessage, UserProfile profile) {
    final msg = userMessage.toLowerCase().trim();
    if (msg.isEmpty) return null;

    // Day-count requests
    final dayMatch = RegExp(r'(\d)\s*-?\s*day').firstMatch(msg);
    if (dayMatch != null ||
        msg.contains('three day') ||
        msg.contains('four day') ||
        msg.contains('five day') ||
        msg.contains('six day')) {
      var n = dayMatch != null ? int.tryParse(dayMatch.group(1)!) ?? 0 : 0;
      if (msg.contains('three')) n = 3;
      if (msg.contains('four')) n = 4;
      if (msg.contains('five')) n = 5;
      if (msg.contains('six')) n = 6;
      n = n.clamp(2, 6);
      const presets = <int, List<String>>{
        2: ['Tue', 'Fri'],
        3: ['Mon', 'Wed', 'Fri'],
        4: ['Mon', 'Tue', 'Thu', 'Fri'],
        5: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        6: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      };
      final days = presets[n]!;
      final updated = profile.copyWith(daysPerWeek: days);
      ref.read(userProfileProvider.notifier).updateProfile(updated);
      generateProgram(updated);
      return 'Got it — rebuilt your week around $n training days (${days.join(', ')}). Tweak any day below if you want.';
    }

    // Goal / focus → pick a matching template
    Program? pick;
    final catalog = ProgramTemplates.allTemplates();
    bool hit(String s) => msg.contains(s);
    Program? firstWhereName(bool Function(String name) test) {
      for (final t in catalog) {
        if (test(t.name.toLowerCase())) return t;
      }
      return null;
    }

    if (hit('glute') || hit('booty') || hit('lower body')) {
      pick = firstWhereName((n) => n.contains('glute'));
    } else if (hit('strength') || hit('stronger') || hit('power')) {
      pick = firstWhereName(
          (n) => n.contains('strength') || n.contains('power'));
    } else if (hit('full body') || hit('full-body') || hit('beginner')) {
      pick = firstWhereName((n) => n.contains('full body'));
    } else if ((hit('push') && hit('pull')) || hit('ppl')) {
      pick = firstWhereName((n) => n.contains('ppl'));
    } else if (hit('home') || hit('dumbbell')) {
      pick = firstWhereName(
          (n) => n.contains('home') || n.contains('dumbbell'));
    } else if (hit('tone') || hit('sculpt') || hit('fat')) {
      pick =
          firstWhereName((n) => n.contains('tone') || n.contains('sculpt'));
    }

    if (pick != null) {
      final assigned = Program(
        id: pick.id,
        name: pick.name,
        description: pick.description,
        days: pick.days,
        whyFitsParagraph: pick.whyFitsParagraph,
        dayAssignments: buildAutoAssignments(profile.daysPerWeek, pick.days),
      );
      loadProgram(assigned);
      return 'Switched you to “${pick.name}”. Scroll the week and sessions to review — or ask for another change.';
    }

    if (hit('rest') && (hit('more') || hit('extra'))) {
      if (state == null) return null;
      final map = Map<String, String>.from(state!.dayAssignments);
      // Drop the last training day to add rest.
      if (map.length > 2) {
        final last = Program.weekdays.lastWhere(map.containsKey);
        map.remove(last);
        state = state!.copyWith(dayAssignments: map);
        _syncProfileTrainingDays(map);
        return 'Added an extra rest day ($last is now rest). You can tap any day to fine-tune.';
      }
    }

    if (hit('rebuild') || hit('reset') || hit('start over') || hit('again')) {
      generateProgram(profile);
      return 'Rebuilt your schedule from scratch based on your profile. Take a look.';
    }

    // Not a recognised shortcut — the caller escalates to the AI.
    return null;
  }
}

final programProvider =
    NotifierProvider<ProgramNotifier, Program?>(ProgramNotifier.new);

// ---------------------------------------------------------------------------
// 3. PR Celebration & Overlay State Provider
// ---------------------------------------------------------------------------

class PRCelebrationInfo {
  final String exerciseName;
  final double weight;
  final int reps;
  final bool isEpleyPR;

  PRCelebrationInfo({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.isEpleyPR,
  });
}

class PRCelebrationNotifier extends Notifier<PRCelebrationInfo?> {
  @override
  PRCelebrationInfo? build() => null;

  void triggerCelebration(String exerciseName, double weight, int reps, bool isEpley) {
    state = PRCelebrationInfo(
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      isEpleyPR: isEpley,
    );
    // Auto-clear after 1.8 seconds (can also be tapped to skip)
    Future.delayed(const Duration(milliseconds: 1800), () {
      clearCelebration();
    });
  }

  void clearCelebration() {
    state = null;
  }
}

final prCelebrationProvider =
    NotifierProvider<PRCelebrationNotifier, PRCelebrationInfo?>(PRCelebrationNotifier.new);

// ---------------------------------------------------------------------------
// 4. Level-up Ceremony Provider
// ---------------------------------------------------------------------------

class LevelUpNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void triggerLevelUp(int level) {
    state = level;
  }

  void clearLevelUp() {
    state = null;
  }
}

final levelUpProvider = NotifierProvider<LevelUpNotifier, int?>(LevelUpNotifier.new);

// ---------------------------------------------------------------------------
// 4b. Week-Complete Celebration Provider
// ---------------------------------------------------------------------------

/// Everything the summary screen needs to celebrate finishing the week —
/// triggered once, the moment the last required training day for the week
/// gets logged (whether on schedule or via a missed-day catch-up).
class WeekCompleteInfo {
  final int workoutsThisWeek;
  final int trainingDaysPlanned;
  final double thisWeekVolumeKg;
  final double lastWeekVolumeKg;
  final int prsThisWeek;
  final int weeksStreak;
  final String message;

  const WeekCompleteInfo({
    required this.workoutsThisWeek,
    required this.trainingDaysPlanned,
    required this.thisWeekVolumeKg,
    required this.lastWeekVolumeKg,
    required this.prsThisWeek,
    required this.weeksStreak,
    required this.message,
  });
}

class WeekCompleteNotifier extends Notifier<WeekCompleteInfo?> {
  @override
  WeekCompleteInfo? build() => null;

  void trigger(WeekCompleteInfo info) => state = info;
  void clear() => state = null;
}

final weekCompleteProvider =
    NotifierProvider<WeekCompleteNotifier, WeekCompleteInfo?>(WeekCompleteNotifier.new);

/// Date-key ('yyyy-M-d') for which the missed-day catch-up nudge was
/// dismissed. Persisted so "not today" is respected across restarts; the
/// nudge naturally resurfaces tomorrow because the key no longer matches.
class MissedDayDismissalNotifier extends Notifier<String?> {
  @override
  String? build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) {
      if (next != null) {
        store.setString(LocalStore.kMissedDayDismissedOn, next);
      } else {
        store.remove(LocalStore.kMissedDayDismissedOn);
      }
    });
    return store.getString(LocalStore.kMissedDayDismissedOn);
  }

  void dismissForToday() {
    final now = DateTime.now();
    state = '${now.year}-${now.month}-${now.day}';
  }

  bool get isDismissedToday {
    final now = DateTime.now();
    return state == '${now.year}-${now.month}-${now.day}';
  }
}

final missedDayDismissalProvider =
    NotifierProvider<MissedDayDismissalNotifier, String?>(
        MissedDayDismissalNotifier.new);

// ---------------------------------------------------------------------------
// 5. Active Workout Provider
// ---------------------------------------------------------------------------

class ActiveWorkoutNotifier extends Notifier<WorkoutSession?> {
  @override
  WorkoutSession? build() {
    // Persist the in-progress session so kill-and-reopen resumes exactly
    // (plan §3.2: "Set-by-set instant persistence; kill-and-reopen resumes").
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) {
      if (next != null && !next.completed) {
        store.setJson(LocalStore.kActiveWorkout, next.toJson());
      } else {
        store.remove(LocalStore.kActiveWorkout);
      }
    });
    final saved = store.getMap(LocalStore.kActiveWorkout);
    final restored = saved != null ? WorkoutSession.fromJson(saved) : null;

    // Restore the rest timer too — a wall-clock end time, so it's correct
    // regardless of how long the app was backgrounded or killed for.
    if (restored != null) {
      final rt = store.getMap(LocalStore.kRestTimer);
      if (rt != null) {
        _restEndsAt = DateTime.tryParse(rt['endsAt'] as String? ?? '');
        _restTimerExerciseName = rt['exerciseName'] as String? ?? '';
        _restTimerTotalSeconds = (rt['totalSeconds'] as num?)?.toInt() ?? 0;
        if (_restEndsAt != null) _startTicker();
      }
    } else {
      store.remove(LocalStore.kRestTimer);
    }
    return restored;
  }

  // Rest timer — wall-clock based (an absolute end time, not a tick counter)
  // so it reads correctly no matter how long the app was backgrounded,
  // suspended, or killed for. A ticker just wakes the UI up once a second
  // while in the foreground; the *truth* is always `_restEndsAt - now`.
  Timer? _timer;
  DateTime? _restEndsAt;
  int _restTimerTotalSeconds = 0;
  String _restTimerExerciseName = '';
  bool _restCompleteAlert = false;

  int get restTimerSecondsRemaining {
    if (_restEndsAt == null) return 0;
    final diff = _restEndsAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get restTimerActive => _restEndsAt != null;
  int get restTimerTotalSeconds => _restTimerTotalSeconds;
  String get restTimerExerciseName => _restTimerExerciseName;
  bool get restCompleteAlert => _restCompleteAlert;

  /// Starts a session for [day]. Pass [forDate] to backfill a missed day —
  /// the session is dated to that day and lands correctly in history,
  /// heatmaps and the week strip.
  void startWorkout(WorkoutDay day, String programId, Map<String, dynamic> pastExercisesData, {DateTime? forDate}) {
    // Ask for what the rest-timer notification needs, before the first rest
    // period of the session. Notification permission is idempotent to
    // request; exact-alarm access is asked once ever (see AppSettings).
    unawaited(NotificationService.instance.requestPermission());
    if (!ref.read(appSettingsProvider).exactAlarmRequested) {
      ref.read(appSettingsProvider.notifier).markExactAlarmRequested();
      unawaited(NotificationService.instance.requestExactAlarmPermission());
    }

    final history = ref.read(workoutHistoryProvider);

    final exercisesLog = day.exercises.map((ex) {
      // Apply double progression from the last time this exercise was trained.
      final lastSets = _lastWorkingSets(history, ex.name);
      final suggestion = ProgressionEngine.suggest(
        exercise: ex,
        lastWorkingSets: lastSets,
      );
      final sets = List.generate(ex.targetSets, (idx) {
        return SetLog(
          id: 'set_${idx + 1}',
          weight: suggestion.weight,
          reps: suggestion.reps,
          completed: false,
          isWarmup: false,
        );
      });
      return ExerciseLog(
        exerciseId: ex.id,
        exerciseName: ex.name,
        sets: sets,
        muscleGroup: ex.muscleGroup,
        targetReps: ex.targetReps,
        progressionReason: suggestion.reason,
      );
    }).toList();

    state = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      programId: programId,
      workoutDayName: day.name,
      date: forDate ?? DateTime.now(),
      // Always the real clock, even when [forDate] backdates the session —
      // the on-screen timer measures how long you have been training now, not
      // how long ago the workout you are logging happened.
      startedAt: DateTime.now(),
      durationSeconds: 0,
      completed: false,
      exercises: exercisesLog,
    );

    _stopRestTimer();
    _restCompleteAlert = false;
  }

  void resumeWorkout() {
    // If state is not null and completed is false, do nothing, it's already running.
  }

  /// The completed, non-warmup sets from the most recent session that included
  /// [exerciseName] — the input the progression engine reasons over.
  List<SetLog> _lastWorkingSets(
      List<WorkoutSession> history, String exerciseName) {
    for (final session in history.reversed) {
      for (final exLog in session.exercises) {
        if (exLog.exerciseName == exerciseName) {
          final working =
              exLog.sets.where((s) => s.completed && !s.isWarmup).toList();
          if (working.isNotEmpty) return working;
        }
      }
    }
    return const [];
  }

  void logSet(String exerciseId, int setIndex) {
    if (state == null) return;

    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;

      final updatedSets = List<SetLog>.from(exLog.sets);
      final setLog = updatedSets[setIndex];
      final wasCompleted = setLog.completed;

      // Toggle or log completion
      final updatedSet = setLog.copyWith(completed: !wasCompleted);
      updatedSets[setIndex] = updatedSet;

      // Trigger rest timer on initial completion
      if (!wasCompleted) {
        _startRestTimer(
            exLog.exerciseName, ref.read(appSettingsProvider).restTimerSeconds);
        
        // Haptic feedback for Logging
        CxHaptics.fire(CxHaptic.logSet);

        // PR detection
        // Look through workout history to find past PRs for this exercise
        final history = ref.read(workoutHistoryProvider);
        double maxPastWeight = 0;
        double maxPastEpley = 0;

        for (var session in history) {
          for (var pastEx in session.exercises) {
            if (pastEx.exerciseName == exLog.exerciseName) {
              for (var pastSet in pastEx.sets) {
                if (pastSet.completed) {
                  if (pastSet.weight > maxPastWeight) maxPastWeight = pastSet.weight;
                  final pastEpleyVal = pastSet.weight * (1 + pastSet.reps / 30.0);
                  if (pastEpleyVal > maxPastEpley) maxPastEpley = pastEpleyVal;
                }
              }
            }
          }
        }

        // Current Epley e1RM
        final currentEpley = updatedSet.weight * (1 + updatedSet.reps / 30.0);

        bool isWeightPR = false;
        bool isEpleyPR = false;

        if (maxPastWeight > 0 && updatedSet.weight > maxPastWeight) {
          isWeightPR = true;
        }
        if (maxPastEpley > 0 && currentEpley > maxPastEpley) {
          isEpleyPR = true;
        }

        // If we hit a PR (either Weight or Epley), trigger theatrical overlay
        if (isWeightPR || isEpleyPR) {
          CxHaptics.fire(CxHaptic.prSlam);
          ref.read(prCelebrationProvider.notifier).triggerCelebration(
            exLog.exerciseName,
            updatedSet.weight,
            updatedSet.reps,
            isEpleyPR,
          );
          updatedSets[setIndex] = updatedSet.copyWith(isPR: isWeightPR, isEpleyPR: isEpleyPR);
        }
      }

      return exLog.copyWith(sets: updatedSets);
    }).toList();

    state = state!.copyWith(exercises: updatedExercises);
  }

  void updateSetWeight(String exerciseId, int setIndex, double weight) {
    if (state == null) return;
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;
      final updatedSets = List<SetLog>.from(exLog.sets);
      updatedSets[setIndex] = updatedSets[setIndex].copyWith(weight: weight);
      return exLog.copyWith(sets: updatedSets);
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  void updateSetReps(String exerciseId, int setIndex, int reps) {
    if (state == null) return;
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;
      final updatedSets = List<SetLog>.from(exLog.sets);
      updatedSets[setIndex] = updatedSets[setIndex].copyWith(reps: reps);
      return exLog.copyWith(sets: updatedSets);
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  /// Sets (or clears, when empty) the note on one set.
  void setSetNote(String exerciseId, int setIndex, String note) {
    if (state == null) return;
    final trimmed = note.trim();
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;
      final updatedSets = List<SetLog>.from(exLog.sets);
      updatedSets[setIndex] = trimmed.isEmpty
          ? updatedSets[setIndex].withoutNote()
          : updatedSets[setIndex].copyWith(note: trimmed);
      return exLog.copyWith(sets: updatedSets);
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  void toggleWarmup(String exerciseId, int setIndex) {
    if (state == null) return;
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;
      final updatedSets = List<SetLog>.from(exLog.sets);
      updatedSets[setIndex] = updatedSets[setIndex].copyWith(isWarmup: !updatedSets[setIndex].isWarmup);
      return exLog.copyWith(sets: updatedSets);
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  void addSet(String exerciseId) {
    if (state == null) return;
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != exerciseId) return exLog;
      final lastSet = exLog.sets.isNotEmpty
          ? exLog.sets.last
          : const SetLog(id: 'set_1', weight: 20, reps: 10);
      final newSet = SetLog(
        id: 'set_${exLog.sets.length + 1}',
        weight: lastSet.weight,
        reps: lastSet.reps,
        completed: false,
      );
      return exLog.copyWith(sets: [...exLog.sets, newSet]);
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  void addExercise(Exercise ex) {
    if (state == null) return;
    final sets = List.generate(ex.targetSets, (idx) {
      return SetLog(
        id: 'set_${idx + 1}',
        weight: ex.suggestedWeight,
        reps: 10,
        completed: false,
      );
    });
    final exLog = ExerciseLog(
      exerciseId: '${ex.id}_added',
      exerciseName: ex.name,
      sets: sets,
      muscleGroup: ex.muscleGroup,
    );
    state = state!.copyWith(exercises: [...state!.exercises, exLog]);
  }

  void swapExercise(String oldExerciseId, Exercise newEx) {
    if (state == null) return;
    final updatedExercises = state!.exercises.map((exLog) {
      if (exLog.exerciseId != oldExerciseId) return exLog;
      final sets = List.generate(newEx.targetSets, (idx) {
        return SetLog(
          id: 'set_${idx + 1}',
          weight: newEx.suggestedWeight,
          reps: 10,
          completed: false,
        );
      });
      return ExerciseLog(
        exerciseId: oldExerciseId,
        exerciseName: newEx.name,
        sets: sets,
        muscleGroup: newEx.muscleGroup,
      );
    }).toList();
    state = state!.copyWith(exercises: updatedExercises);
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (state == null) return;
    final list = List<ExerciseLog>.from(state!.exercises);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state!.copyWith(exercises: list);
  }

  // ---------------------------------------------------------------------------
  // Rest Timer Internal Operations
  // ---------------------------------------------------------------------------
  //
  // The timer's source of truth is `_restEndsAt` (an absolute DateTime), never
  // a decrementing counter. A local `Timer.periodic` just wakes the UI up
  // once a second while the app is in the foreground; if the OS suspends that
  // ticker while the app is backgrounded/locked, nothing drifts — the very
  // next read of `restTimerSecondsRemaining` recomputes from wall-clock time,
  // so reopening the app (or hitting Resume) always shows the true remaining
  // time instead of a stale/reset value.
  //
  // Actually ringing while backgrounded is a separate concern: Dart timers
  // (and any in-app sound/haptics tied to widget rebuilds) simply do not run
  // while the app isn't in the foreground. So on top of the wall-clock fix, a
  // real OS notification is scheduled for the exact end time — the OS fires
  // it regardless of app state, which is the only reliable way to alert the
  // user when the screen is locked or the app is backgrounded.

  void _startRestTimer(String exerciseName, int duration) {
    _restCompleteAlert = false;
    _restTimerExerciseName = exerciseName;
    _restTimerTotalSeconds = duration;
    _restEndsAt = DateTime.now().add(Duration(seconds: duration));
    _persistRestTimer();
    _scheduleBackgroundAlert();
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restTimerSecondsRemaining <= 0) {
        _onRestComplete();
      } else {
        state = state; // wake listeners so the countdown UI redraws
      }
    });
  }

  /// How late an in-app alert can be and still be worth ringing. Past this,
  /// rest ended while the user was elsewhere, the OS notification already told
  /// them, and a chime now is just confusing noise.
  static const _staleAlertThreshold = Duration(seconds: 5);

  void _onRestComplete() {
    _timer?.cancel();
    _timer = null;
    // How overdue this is tells us whether we watched it finish or merely
    // noticed afterwards — so read it before clearing the end time.
    final overdue = _restEndsAt == null
        ? Duration.zero
        : DateTime.now().difference(_restEndsAt!);
    _restEndsAt = null;
    _clearPersistedRestTimer();

    // Reaching this line does NOT mean the app is on screen. Android keeps a
    // backgrounded isolate running, so this ticker fires with the screen off
    // — and the old code cancelled the scheduled notification here on the
    // assumption it was redundant. It wasn't: the in-app tone can't play
    // without a frame, so the user got nothing at all and only heard the
    // alert once they reopened the app. That was the bug.
    //
    // Two things have to be true before we take over from the OS: the app is
    // actually foregrounded, and rest ended just now rather than while the
    // phone was in a pocket.
    final foreground = ref.read(appIsForegroundProvider);
    final fresh = overdue <= _staleAlertThreshold;
    if (foreground && fresh) {
      unawaited(NotificationService.instance.cancelRestComplete());
    }
    final soundOn = ref.read(appSettingsProvider).restCompleteSoundEnabled;
    _restCompleteAlert = soundOn && foreground && fresh;
    state = state;
  }

  /// Test-only: runs the rest-completion path as if the timer had just hit
  /// zero, optionally pretending it ended at [endedAt] so the stale-alert
  /// branch can be exercised without a three-minute test.
  @visibleForTesting
  void debugCompleteRestNow({DateTime? endedAt}) {
    _restEndsAt = endedAt ?? DateTime.now();
    _onRestComplete();
  }

  void _stopRestTimer() {
    _timer?.cancel();
    _timer = null;
    _restEndsAt = null;
    _clearPersistedRestTimer();
    unawaited(NotificationService.instance.cancelRestComplete());
    state = state;
  }

  void skipRestTimer() {
    _stopRestTimer();
    dismissRestCompleteAlert();
  }

  void dismissRestCompleteAlert() {
    if (!_restCompleteAlert) return;
    _restCompleteAlert = false;
    state = state;
  }

  void addTimeToRestTimer(int seconds) {
    if (_restEndsAt == null) return;
    _restEndsAt = _restEndsAt!.add(Duration(seconds: seconds));
    _restTimerTotalSeconds += seconds;
    _persistRestTimer();
    _scheduleBackgroundAlert();
    state = state;
  }

  void _scheduleBackgroundAlert() {
    if (_restEndsAt == null) return;
    unawaited(NotificationService.instance
        .scheduleRestComplete(_restEndsAt!, exerciseName: _restTimerExerciseName));
  }

  void _persistRestTimer() {
    if (_restEndsAt == null) return;
    ref.read(localStoreProvider).setJson(LocalStore.kRestTimer, {
      'endsAt': _restEndsAt!.toIso8601String(),
      'exerciseName': _restTimerExerciseName,
      'totalSeconds': _restTimerTotalSeconds,
    });
  }

  void _clearPersistedRestTimer() {
    ref.read(localStoreProvider).remove(LocalStore.kRestTimer);
  }

  WorkoutSession finishWorkout({int mockDurationMinutes = 45}) {
    if (state == null) return WorkoutSession(id: '', programId: '', workoutDayName: '', date: DateTime(2026), exercises: []);

    // Calculate Volume and PRs
    double totalVol = 0;
    List<String> hits = [];
    final Map<String, String> suggestions = {};
    var anyMissedInSession = false;

    for (var ex in state!.exercises) {
      double exVol = 0;
      bool allSetsTopReps = true;
      bool missedAnySet = false;

      for (var set in ex.sets) {
        if (set.completed) {
          exVol += set.weight * set.reps;
          if (set.isPR) {
            hits.add("${ex.exerciseName} ${set.weight}kg x ${set.reps} (Weight PR!)");
          }
          if (set.isEpleyPR) {
            hits.add("${ex.exerciseName} ${set.weight}kg x ${set.reps} (e1RM PR!)");
          }

          // Check if top rep range hit (e.g. 12 reps if range is 8-12)
          if (set.reps < 12) {
            allSetsTopReps = false;
          }
        } else {
          missedAnySet = true;
          allSetsTopReps = false;
        }
      }

      totalVol += exVol;
      if (missedAnySet) anyMissedInSession = true;

      // Progressive Overload Engine logic
      if (allSetsTopReps && ex.sets.isNotEmpty) {
        final isLower = ex.muscleGroup == 'Legs';
        final increase = isLower ? 5.0 : 2.5;
        suggestions[ex.exerciseName] = "All sets completed at top rep range. Suggest increasing weight by +${increase}kg next session to trigger progressive overload.";
      } else if (missedAnySet) {
        suggestions[ex.exerciseName] = "Some sets were missed. Suggest holding the current weight or a minor -10% deload to consolidate form.";
      } else {
        suggestions[ex.exerciseName] = "Consistent performance. Keep matching targets to build work capacity.";
      }
    }

    // Award XP (plan Phase 5.1): workout +50, all planned sets +25,
    // PR +100 each, plus an occasional deterministic Coach's bonus.
    int xpEarned = XpValues.workoutComplete;
    if (!anyMissedInSession && state!.exercises.isNotEmpty) {
      xpEarned += XpValues.allPlannedSets;
    }
    xpEarned += hits.length * XpValues.perPr;

    final historyBeforeThis = ref.read(workoutHistoryProvider);
    final completedBefore =
        historyBeforeThis.where((s) => s.completed).length;
    final bonus = coachBonus(completedBefore + 1);
    xpEarned += bonus.xp;

    // Add session to History
    final finalized = state!.copyWith(
      completed: true,
      durationSeconds: mockDurationMinutes * 60,
      totalVolume: totalVol,
      prsHit: hits,
      xpEarned: xpEarned,
      overloadSuggestions: suggestions,
      coachBonusXp: bonus.xp,
      coachBonusReason: bonus.reason,
    );

    // Snapshot week progress *before* this session lands, so we can detect
    // the exact moment the week's training-day target gets hit (whether on
    // schedule or via a missed-day catch-up) and celebrate once, not repeat.
    final program = ref.read(programProvider);
    final profile = ref.read(userProfileProvider);
    final assignedWeekdays = (program != null && program.dayAssignments.isNotEmpty)
        ? program.dayAssignments.keys.toSet()
        : profile.daysPerWeek.toSet();
    final progressBefore = computeWeekProgress(
      now: finalized.date,
      assignedWeekdays: assignedWeekdays,
      completedWorkoutDates:
          historyBeforeThis.where((s) => s.completed).map((s) => s.date).toList(),
    );

    ref.read(workoutHistoryProvider.notifier).addSession(finalized);

    if (!progressBefore.isComplete) {
      _maybeCelebrateWeekComplete(
        assignedWeekdays: assignedWeekdays,
        referenceDate: finalized.date,
      );
    }

    // Add Quest progress for logging workout
    ref.read(questProvider.notifier).incrementQuestProgress('log_workout_weekly', 1);
    ref.read(questProvider.notifier).incrementQuestProgress('log_workout_milestone', 1);
    ref.read(questProvider.notifier).incrementQuestProgress('hit_muscle_weekly', 1);
    if (hits.isNotEmpty) {
      ref.read(questProvider.notifier).incrementQuestProgress('hit_pr_milestone', 1);
    }

    // Update profile level/XP
    final didLevelUp = ref.read(userProfileProvider.notifier).addXp(xpEarned);
    if (didLevelUp) {
      ref.read(levelUpProvider.notifier).triggerLevelUp(ref.read(userProfileProvider).level);
    }

    // Trigger streak increment
    ref.read(userProfileProvider.notifier).incrementStreak();

    _stopRestTimer();
    state = null; // Clear active workout
    return finalized;
  }

  /// Called right after a session lands in history, only when the week was
  /// NOT yet complete before it. If that session was the one that hit the
  /// week's training-day target, build the recap and fire the celebration —
  /// guarded by a per-week store key so it shows exactly once even if the
  /// user logs extra sessions afterwards.
  void _maybeCelebrateWeekComplete({
    required Set<String> assignedWeekdays,
    required DateTime referenceDate,
  }) {
    final history = ref.read(workoutHistoryProvider);
    final completed = history.where((s) => s.completed).toList();

    final progress = computeWeekProgress(
      now: referenceDate,
      assignedWeekdays: assignedWeekdays,
      completedWorkoutDates: completed.map((s) => s.date).toList(),
    );
    if (!progress.isComplete) return;

    // Once per week, ever — survives restarts.
    final store = ref.read(localStoreProvider);
    final monday = mondayOfWeek(referenceDate);
    final weekKey = '${monday.year}-${monday.month}-${monday.day}';
    if (store.getString(LocalStore.kWeekCompleteShownFor) == weekKey) return;
    store.setString(LocalStore.kWeekCompleteShownFor, weekKey);

    // Recap stats: this week vs last week, PRs, consecutive complete weeks.
    final lastMonday = monday.subtract(const Duration(days: 7));
    double thisWeekVol = 0, lastWeekVol = 0;
    var workoutsThisWeek = 0, prsThisWeek = 0;
    for (final s in completed) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (!d.isBefore(monday) && d.difference(monday).inDays < 7) {
        thisWeekVol += s.totalVolume;
        workoutsThisWeek++;
        prsThisWeek += s.prsHit.length;
      } else if (!d.isBefore(lastMonday) && d.isBefore(monday)) {
        lastWeekVol += s.totalVolume;
      }
    }
    final weeksStreak = consecutiveCompletedWeeks(
      now: referenceDate,
      assignedWeekdays: assignedWeekdays,
      completedWorkoutDates: completed.map((s) => s.date).toList(),
    );

    ref.read(weekCompleteProvider.notifier).trigger(WeekCompleteInfo(
          workoutsThisWeek: workoutsThisWeek,
          trainingDaysPlanned: progress.targetDays,
          thisWeekVolumeKg: thisWeekVol,
          lastWeekVolumeKg: lastWeekVol,
          prsThisWeek: prsThisWeek,
          weeksStreak: weeksStreak,
          message: weeklyRecapMessage(
            thisWeekVolumeKg: thisWeekVol,
            lastWeekVolumeKg: lastWeekVol,
            prsThisWeek: prsThisWeek,
            weeksStreak: weeksStreak,
            seed: completed.length,
          ),
        ));
  }

  void cancelWorkout() {
    _stopRestTimer();
    _restCompleteAlert = false;
    state = null;
  }
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutNotifier, WorkoutSession?>(ActiveWorkoutNotifier.new);

// ---------------------------------------------------------------------------
// 6. Workout History Provider
// ---------------------------------------------------------------------------

class WorkoutHistoryNotifier extends Notifier<List<WorkoutSession>> {
  @override
  List<WorkoutSession> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) =>
        store.setJson(LocalStore.kHistory, next.map((s) => s.toJson()).toList()));
    final saved = store.getList(LocalStore.kHistory);
    if (saved == null) {
      // Empty for new accounts — never seed fake workouts (that looked like
      // "another user's" week checkmarks + streak).
      return const [];
    }

    final sessions = saved
        .map((s) => WorkoutSession.fromJson(s as Map<String, dynamic>))
        .toList();
    // Legacy first-run demo sessions used ids past_1 / past_2 / past_3.
    final cleaned =
        sessions.where((s) => !s.id.startsWith('past_')).toList();
    if (cleaned.length != sessions.length) {
      store.setJson(
        LocalStore.kHistory,
        cleaned.map((s) => s.toJson()).toList(),
      );
      // Demo history was inflating the streak — reset when nothing real remains.
      if (cleaned.isEmpty) {
        Future.microtask(() {
          final p = ref.read(userProfileProvider);
          if (p.streak != 0) {
            ref
                .read(userProfileProvider.notifier)
                .updateProfile(p.copyWith(streak: 0));
          }
        });
      }
    }
    return cleaned;
  }

  void addSession(WorkoutSession session) {
    state = [...state, session];
  }
}

final workoutHistoryProvider =
    NotifierProvider<WorkoutHistoryNotifier, List<WorkoutSession>>(WorkoutHistoryNotifier.new);

// ---------------------------------------------------------------------------
// 7. Bodyweight & Daily Weigh-in Provider
// ---------------------------------------------------------------------------

class BodyweightNotifier extends Notifier<List<WeighIn>> {
  @override
  List<WeighIn> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(
        LocalStore.kBodyweight, next.map((w) => w.toJson()).toList()));
    final saved = store.getList(LocalStore.kBodyweight);
    if (saved != null) {
      return saved
          .map((w) => WeighIn.fromJson(w as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  /// Replaces the whole series (used when restoring from cloud sync).
  void replaceAll(List<WeighIn> weighIns) {
    final sorted = [...weighIns]..sort((a, b) => a.date.compareTo(b.date));
    state = sorted;
  }

  void logWeighIn(double weight, {required WidgetRef ref}) {
    final now = DateTime.now();
    state = [...state, WeighIn(date: now, weight: weight)];
    ref.read(userProfileProvider.notifier).updateProfile(
      ref.read(userProfileProvider).copyWith(weight: weight)
    );

    // Update quest + award weigh-in XP (plan: +5)
    ref.read(questProvider.notifier).incrementQuestProgress('weigh_in_weekly', 1);
    ref.read(userProfileProvider.notifier).addXp(XpValues.weighIn);
  }

  double get rollingAverage7Day {
    if (state.isEmpty) return 0;
    final last7 = state.length > 7 ? state.sublist(state.length - 7) : state;
    final sum = last7.map((w) => w.weight).reduce((a, b) => a + b);
    return double.parse((sum / last7.length).toStringAsFixed(1));
  }
}

final bodyweightProvider =
    NotifierProvider<BodyweightNotifier, List<WeighIn>>(BodyweightNotifier.new);

// ---------------------------------------------------------------------------
// 7b. Body measurements + progress photos (Phase 4)
// ---------------------------------------------------------------------------

/// The optional circumference measurements the user can track. Stored in cm.
const kMeasurementKeys = ['Waist', 'Chest', 'Arms', 'Thighs', 'Hips'];

class MeasurementsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kMeasurements, next));
    final saved = store.getMap(LocalStore.kMeasurements);
    return saved != null
        ? saved.map((k, v) => MapEntry(k, (v as num).toDouble()))
        : const {};
  }

  void setMeasurement(String key, double valueCm) {
    state = {...state, key: valueCm};
  }

  void removeMeasurement(String key) {
    final next = Map<String, double>.from(state)..remove(key);
    state = next;
  }
}

final measurementsProvider =
    NotifierProvider<MeasurementsNotifier, Map<String, double>>(
        MeasurementsNotifier.new);

/// A local-only progress photo (file path stays on device; never uploaded
/// unless the user explicitly opts into cloud backup).
class ProgressPhoto {
  final String path;
  final DateTime date;
  const ProgressPhoto({required this.path, required this.date});

  Map<String, dynamic> toJson() =>
      {'path': path, 'date': date.toIso8601String()};

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
        path: json['path'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}

class ProgressPhotosNotifier extends Notifier<List<ProgressPhoto>> {
  @override
  List<ProgressPhoto> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(
        LocalStore.kPhotos, next.map((p) => p.toJson()).toList()));
    final saved = store.getList(LocalStore.kPhotos);
    return saved != null
        ? saved
            .map((p) => ProgressPhoto.fromJson(p as Map<String, dynamic>))
            .toList()
        : <ProgressPhoto>[];
  }

  void addPhoto(String path) {
    state = [
      ...state,
      ProgressPhoto(path: path, date: DateTime.now()),
    ];
  }

  void removePhoto(String path) {
    state = state.where((p) => p.path != path).toList();
  }
}

final progressPhotosProvider =
    NotifierProvider<ProgressPhotosNotifier, List<ProgressPhoto>>(
        ProgressPhotosNotifier.new);

// ---------------------------------------------------------------------------
// 7c. Hydration Provider (daily water intake)
// ---------------------------------------------------------------------------

/// Daily water intake in ml, keyed by 'yyyy-MM-dd'. The goal derives from
/// bodyweight (~35 ml/kg, see [hydrationGoalMl]). Crossing the goal once per
/// day advances the weekly hydration quest and awards a small XP tick.
class HydrationNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kHydration, next));
    final saved = store.getMap(LocalStore.kHydration);
    return saved != null
        ? saved.map((k, v) => MapEntry(k, (v as num).toInt()))
        : const {};
  }

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get todayMl => state[dayKey(DateTime.now())] ?? 0;

  int get goalMl =>
      hydrationGoalMl(ref.read(userProfileProvider).weight);

  /// Adds (or removes, when negative) water for today. Clamped at 0.
  void log(int ml, {required WidgetRef ref}) {
    final key = dayKey(DateTime.now());
    final before = state[key] ?? 0;
    final after = (before + ml).clamp(0, 20000);
    state = {...state, key: after};

    // Crossing the goal (once per day) advances the quest + tiny XP.
    final goal = goalMl;
    if (before < goal && after >= goal) {
      ref.read(questProvider.notifier).incrementQuestProgress('hydration_weekly', 1);
      ref.read(userProfileProvider.notifier).addXp(XpValues.hydrationGoal);
      CxHaptics.fire(CxHaptic.success);
    }
  }
}

final hydrationProvider =
    NotifierProvider<HydrationNotifier, Map<String, int>>(HydrationNotifier.new);

// ---------------------------------------------------------------------------
// 7d. Protein Provider (daily grams — the one nutrition number that matters)
// ---------------------------------------------------------------------------

/// Daily protein intake in grams, keyed by 'yyyy-MM-dd'. The goal comes from
/// the goal-aware nutrition engine (see [nutritionTargets]) — explicitly NOT
/// a food database (plan Phase 12.1): quick-log the grams, hit the number.
class ProteinNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kProtein, next));
    final saved = store.getMap(LocalStore.kProtein);
    return saved != null
        ? saved.map((k, v) => MapEntry(k, (v as num).toInt()))
        : const {};
  }

  int get todayG => state[HydrationNotifier.dayKey(DateTime.now())] ?? 0;

  NutritionTargets get targets {
    final p = ref.read(userProfileProvider);
    return nutritionTargets(
      weightKg: p.weight,
      heightCm: p.height,
      age: p.age,
      sex: p.sex,
      goal: p.goal,
    );
  }

  /// Adds (or removes, when negative) grams for today. Clamped at 0.
  void log(int grams) {
    final key = HydrationNotifier.dayKey(DateTime.now());
    final before = state[key] ?? 0;
    final after = (before + grams).clamp(0, 1000);
    state = {...state, key: after};

    // Crossing the goal (once per day) → the same small tick as hydration.
    final goal = targets.proteinG;
    if (before < goal && after >= goal) {
      ref.read(userProfileProvider.notifier).addXp(XpValues.hydrationGoal);
      CxHaptics.fire(CxHaptic.success);
    }
  }
}

final proteinProvider =
    NotifierProvider<ProteinNotifier, Map<String, int>>(ProteinNotifier.new);

// ---------------------------------------------------------------------------
// 8. Quest & Gamification Provider
// ---------------------------------------------------------------------------

class QuestNotifier extends Notifier<List<Quest>> {
  @override
  List<Quest> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) =>
        store.setJson(LocalStore.kQuests, next.map((q) => q.toJson()).toList()));

    final saved = store.getList(LocalStore.kQuests);
    var quests = saved != null
        ? saved.map((q) => Quest.fromJson(q as Map<String, dynamic>)).toList()
        : [..._seedWeeklies(endowed: true), ..._seedMilestones()];

    // Fresh-start effect (plan Phase 5.4): weekly quests reset every Monday.
    // Milestones persist. Also migrates in any newly-added weekly quest ids.
    final weekKey = _mondayKey(DateTime.now());
    if (store.getString(LocalStore.kQuestsWeekKey) != weekKey) {
      store.setString(LocalStore.kQuestsWeekKey, weekKey);
      if (saved != null) {
        quests = [
          ..._seedWeeklies(),
          ...quests.where((q) => q.isMilestone),
        ];
      }
    } else if (saved != null) {
      // Migration: add weekly quests introduced after this save (e.g. hydration).
      final ids = quests.map((q) => q.id).toSet();
      quests = [
        ...quests,
        ..._seedWeeklies().where((q) => !ids.contains(q.id)),
      ];
    }
    return quests;
  }

  /// ISO-ish week marker: the date of this week's Monday.
  static String _mondayKey(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  List<Quest> _seedWeeklies({bool endowed = false}) {
    return [
      Quest(
        id: 'log_workout_weekly',
        title: 'Weekly Iron Ritual',
        description: 'Complete 3 custom workouts this week.',
        targetValue: 3,
        // Endowed progress on first run only (credited from onboarding).
        currentValue: endowed ? 1 : 0,
        xpReward: 100,
      ),
      Quest(
        id: 'hit_muscle_weekly',
        title: 'Anabolic Balance',
        description: 'Hit at least 2 distinct muscle groups.',
        targetValue: 2,
        currentValue: endowed ? 1 : 0,
        xpReward: 50,
      ),
      Quest(
        id: 'weigh_in_weekly',
        title: 'Steady Tracker',
        description: 'Log weight on 5 separate days.',
        targetValue: 5,
        currentValue: endowed ? 3 : 0,
        xpReward: 60,
      ),
      const Quest(
        id: 'hydration_weekly',
        title: 'Well Watered',
        description: 'Hit your daily water goal on 3 days.',
        targetValue: 3,
        currentValue: 0,
        xpReward: 40,
      ),
    ];
  }

  List<Quest> _seedMilestones() {
    return [
      // Milestone Quests
      const Quest(
        id: 'log_workout_milestone',
        title: 'Sacred Beginnings',
        description: 'Complete your first formal program workout.',
        targetValue: 1,
        currentValue: 0,
        xpReward: 200,
        isMilestone: true,
      ),
      const Quest(
        id: 'hit_pr_milestone',
        title: 'Ember Breaker',
        description: 'Smash through any Weight or Epley e1RM PR.',
        targetValue: 1,
        currentValue: 0,
        xpReward: 150,
        isMilestone: true,
      ),
      const Quest(
        id: 'streak_milestone',
        title: 'Iron Consistency',
        description: 'Maintain a streak of 5+ days.',
        targetValue: 5,
        currentValue: 3, // Current streak is 3
        xpReward: 300,
        isMilestone: true,
      ),
    ];
  }

  void incrementQuestProgress(String id, int delta) {
    state = state.map((q) {
      if (exceedsOrEquals(q.id, id)) {
        final newVal = (q.currentValue + delta).clamp(0, q.targetValue);
        return q.copyWith(currentValue: newVal);
      }
      return q;
    }).toList();
  }

  bool exceedsOrEquals(String id1, String id2) => id1 == id2;

  void claimQuest(String id, {required WidgetRef ref}) {
    state = state.map((q) {
      if (q.id == id && q.isCompleted && !q.isClaimed) {
        // Award XP
        final didLevelUp = ref.read(userProfileProvider.notifier).addXp(q.xpReward);
        if (didLevelUp) {
          ref.read(levelUpProvider.notifier).triggerLevelUp(ref.read(userProfileProvider).level);
        }
        CxHaptics.fire(CxHaptic.success);
        return q.copyWith(isClaimed: true);
      }
      return q;
    }).toList();
  }
}

final questProvider =
    NotifierProvider<QuestNotifier, List<Quest>>(QuestNotifier.new);

// ---------------------------------------------------------------------------
// 9. AI Coach Chat Provider
// ---------------------------------------------------------------------------

class CoachChatNotifier extends Notifier<List<ChatMessage>> {
  static final _welcome = ChatMessage(
    id: 'welcome',
    text:
        "Hey! I'm Yorhart, your AI strength coach. I track your progressive overload, analyze your training history, and optimize your routine. Ask me anything about your current program!",
    isUser: false,
    timestamp: DateTime(2026),
  );

  @override
  List<ChatMessage> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) =>
        store.setJson(LocalStore.kChat, next.map((m) => m.toJson()).toList()));
    final saved = store.getList(LocalStore.kChat);
    if (saved != null) {
      return saved
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    return [_welcome];
  }

  void sendMessage(String text, {required WidgetRef ref}) {
    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_user',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    // A new question retires any standing offer — it belonged to the previous
    // one, and applying it now would change the plan from a request the user
    // has already moved on from.
    ref.read(scheduleOfferProvider.notifier).clear();
    _pendingScheduleRequest =
        looksLikeScheduleRequest(text) && this.ref.read(programProvider) != null
            ? text
            : null;

    // Small talk ("hi", "thanks", "who are you") is answered locally —
    // instant for the user, zero AI spend, and it can't be abused to burn
    // credits with chatter.
    final smallTalk = _smallTalkReply(text, ref.read(userProfileProvider));
    if (smallTalk != null) {
      _appendAssistant(smallTalk);
      return;
    }

    // Try the real cloud coach; gracefully fall back to the offline heuristic
    // reply when Supabase isn't configured / the user isn't signed in.
    unawaited(_respond(text, ref));
  }

  /// Bumped by [stopResponding]. A reply is only appended while it still
  /// belongs to the current generation.
  int _generation = 0;

  /// The message Coach is answering, when it read like a request to change the
  /// training plan. Kept so the reply can carry an "apply this to my plan"
  /// action — advice about the week is worth little if acting on it means
  /// re-typing it somewhere else.
  String? _pendingScheduleRequest;

  /// Abandons the reply Coach is currently writing.
  ///
  /// The request is already with the provider and will finish there — this
  /// cannot un-spend it. What it does is stop the answer arriving in the
  /// thread, which is what someone who just sent the wrong message wants.
  void stopResponding(WidgetRef ref) {
    if (!ref.read(coachThinkingProvider)) return;
    _generation++;
    _pendingScheduleRequest = null;
    ref.read(coachThinkingProvider.notifier).set(false);
  }

  Future<void> _respond(String text, WidgetRef ref) async {
    final api = ref.read(coachApiProvider);
    final generation = ++_generation;
    bool cancelled() => _generation != generation;

    ref.read(coachThinkingProvider.notifier).set(true);
    try {
      final snapshot = _coachSnapshot(ref);
      final reply = await api.sendMessage(
        text,
        state,
        today: snapshot['today'] as Map<String, dynamic>,
        snapshot: snapshot,
      );
      if (cancelled()) return;
      _offerScheduleApply(_appendAssistant(reply));
    } on CoachException catch (e) {
      if (cancelled()) return;
      // Config/auth issues → this is expected offline; use the local reply.
      if (e.code == 'not_configured' || e.code == 'auth') {
        _offerScheduleApply(_appendAssistant(_mockReply(text, ref)));
      } else {
        // Server messages are already coach-voiced and friendly
        // (rate limits, cooldown, provider hiccups) — show them as-is.
        _appendAssistant(e.message);
      }
    } catch (e, st) {
      if (cancelled()) return;
      // This branch is the safety net for genuinely unexpected failures, and a
      // silent one hid a real bug for a long time: decoding the coach response
      // threw, so every reply quietly came from the offline mock while the
      // server was answering fine. Falling back is still right — the user gets
      // an answer — but it must be visible in the logs.
      debugPrint('coach: unexpected failure, using offline reply: $e\n$st');
      _offerScheduleApply(_appendAssistant(_mockReply(text, ref)));
    } finally {
      // Only the live request owns the thinking flag — a late reply from a
      // cancelled one must not clear the indicator for whatever replaced it.
      if (!cancelled()) ref.read(coachThinkingProvider.notifier).set(false);
    }
  }

  /// Everything Coach is given about this user — profile, the week as it
  /// actually stands, recent sessions with top sets and notes, adherence,
  /// bodyweight trend, nutrition targets, and today.
  ///
  /// Assembled on the device because that is the only place the data exists:
  /// workouts and programs are not synced, so the server's `coach_context()`
  /// sees a profile row and little else.
  Map<String, dynamic> _coachSnapshot(WidgetRef ref) => buildCoachSnapshot(
        profile: ref.read(userProfileProvider),
        program: ref.read(programProvider),
        history: ref.read(workoutHistoryProvider),
        weighIns: ref.read(bodyweightProvider),
        now: ref.read(clockProvider)(),
      );

  /// Just the "today" slice, for the offline coach.
  Map<String, dynamic> _todaySnapshot(WidgetRef ref) => todaySnapshot(
        profile: ref.read(userProfileProvider),
        program: ref.read(programProvider),
        history: ref.read(workoutHistoryProvider),
        now: ref.read(clockProvider)(),
      );

  /// Test-only window onto the small-talk filter (which messages stay local).
  String? debugSmallTalk(String text, UserProfile profile) =>
      _smallTalkReply(text, profile);

  /// Deterministic replies for greetings/acknowledgements — never worth an
  /// API round-trip. Returns null for anything that deserves the real coach.
  String? _smallTalkReply(String text, UserProfile profile) {
    final t = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    if (t.isEmpty || t.split(RegExp(r'\s+')).length > 4) return null;
    final name = profile.name.trim().isEmpty ? '' : ', ${profile.name.trim()}';

    const greetings = {
      'hi', 'hii', 'hiii', 'hello', 'hey', 'heya', 'yo', 'sup', 'hola',
      'namaste', 'good morning', 'good afternoon', 'good evening', 'gm',
    };
    const thanks = {
      'thanks', 'thank you', 'thanks a lot', 'thank u', 'thx', 'ty',
      'thanks coach', 'thank you coach',
    };
    const acks = {
      'ok', 'okay', 'k', 'cool', 'nice', 'great', 'awesome', 'perfect',
      'got it', 'sounds good', 'alright', 'sure', 'done', 'okk',
    };
    const byes = {'bye', 'goodbye', 'see you', 'gn', 'good night', 'cya'};
    const whoAmI = {
      'who are you', 'what are you', 'what can you do', 'help', 'help me',
    };

    if (greetings.contains(t)) {
      return 'Hey$name! Ready when you are. Ask me about today\'s session, '
          'your program, or say "build me a nutrition plan" and I\'ll use your numbers.';
    }
    if (thanks.contains(t)) {
      return 'Anytime$name — that\'s what I\'m here for. Now go lift something heavy.';
    }
    if (acks.contains(t)) {
      return 'Good. Anything else about your training or food, I\'m right here.';
    }
    if (byes.contains(t)) {
      return 'See you at the next session$name. Rest well — that\'s where the growth happens.';
    }
    if (whoAmI.contains(t)) {
      return 'I\'m Yorhart, your AI strength coach. I read your logged workouts, '
          'bodyweight trend and program, and give advice grounded in *your* data — '
          'training, nutrition and recovery. Try "explain my program" or "build me a nutrition plan".';
    }
    return null;
  }

  /// Posts a coach line into the thread that didn't come from the model —
  /// the outcome of an action the user took from the chat, so the transcript
  /// stays an honest record of what happened.
  void noteFromCoach(String text) => _appendAssistant(text);

  /// Appends a coach reply and returns its message id.
  String _appendAssistant(String text) {
    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}_system';
    state = [
      ...state,
      ChatMessage(
        id: id,
        // Bubbles render plain text; a model writing markdown must not show
        // the user its pipes and asterisks.
        text: tidyCoachMarkdown(text),
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
    CxHaptics.fire(CxHaptic.selection);
    return id;
  }

  /// Attaches an apply-to-my-plan action under [messageId] when the question
  /// it answers was a request to change the training week.
  ///
  /// The offer only offers. Nothing about the program moves until the user taps
  /// it and accepts the diff that follows.
  void _offerScheduleApply(String messageId) {
    final request = _pendingScheduleRequest;
    _pendingScheduleRequest = null;
    if (request == null) return;
    ref.read(scheduleOfferProvider.notifier).set(
          ScheduleOffer(request: request, afterMessageId: messageId),
        );
  }

  /// Offline heuristic coach — deterministic, grounded in local profile/program.
  /// Used when the cloud coach is unavailable so chat always responds.
  /// Mirrors the cloud coach's behavior contract: check the user's data,
  /// personalize with their actual numbers, and ask a clarifying question
  /// instead of guessing when the request is too vague to personalize.
  String _mockReply(String text, WidgetRef ref) {
    final profile = ref.read(userProfileProvider);
    final currentProgram = ref.read(programProvider);
    final query = text.toLowerCase().trim();

    // What day it actually is, and what the plan says about it. Anything that
    // says "today" has to be answered from this, not from the first session in
    // the program — that is exactly how the old reply managed to prescribe leg
    // day on a rest day.
    final today = _todaySnapshot(ref);
    final weekdayLong = _longWeekday(today['weekday'] as String);
    final todaysSession = today['scheduledToday'] as String?;
    final trainedToday = today['alreadyTrainedToday'] as bool;
    final todaysExercises = (today['exercisesToday'] as List).cast<String>();

    // A request to change the week is about the week, not about today. It gets
    // answered from the schedule the user actually has, and the offer card
    // under this reply is what applies the change.
    if (looksLikeScheduleRequest(text) && currentProgram != null) {
      final layout = [
        for (final wd in Program.weekdays)
          if (currentProgram.dayAssignments[wd] != null)
            '$wd: ${currentProgram.dayForWeekday(wd, fallbackDays: profile.daysPerWeek)?.name ?? ''}',
      ];
      return "Here's your week as it stands — ${profile.daysPerWeek.length} training "
          "days on ${currentProgram.name}:\n\n"
          "${layout.map((l) => '• $l').join('\n')}\n\n"
          "I can rewrite this for what you asked. Tap “Update my plan” below and "
          "I'll show you exactly what changes before anything is saved — nothing "
          "moves until you accept it.";
    }

    // Anything about "today" gets the honest state of today first.
    final aboutToday = query.contains('today') ||
        query.contains('right now') ||
        query.contains('tonight');
    if (aboutToday && todaysSession == null) {
      return "Today is $weekdayLong — a rest day on your plan, and rest days are "
          "part of the program, not a gap in it. If you want to move, walk or do "
          "some easy mobility.\n\n"
          "If you'd rather train today, say so and I'll tell you which session to "
          "pull forward — but then take the rest later in the week instead.";
    }
    if (aboutToday && trainedToday) {
      return "You already logged $todaysSession today ($weekdayLong), so the work "
          "is done. Adding a second session on top won't add muscle — recovery is "
          "where the adaptation happens.\n\n"
          "If something felt off in that session, tell me what and I'll adjust the "
          "next one.";
    }

    // Vague ask → clarify rather than guess (good coaches ask first).
    final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length <= 2 &&
        !query.contains('program') &&
        !query.contains('nutrition') &&
        !query.contains('diet')) {
      return "Happy to help — give me one more detail so I can use your data properly. "
          "Are you asking about your training (program, weights, a specific lift), "
          "your nutrition, or recovery? And is this about today's session or the bigger picture?";
    }

    // Nutrition — personalized from their own stats via the nutrition engine.
    if (query.contains('nutrition') ||
        query.contains('diet') ||
        query.contains('protein') ||
        query.contains('calorie') ||
        query.contains('eat') ||
        query.contains('bulk') ||
        query.contains('lean')) {
      final t = nutritionTargets(
        weightKg: profile.weight,
        heightCm: profile.height,
        age: profile.age,
        sex: profile.sex,
        goal: profile.goal,
      );
      return "Here's your nutrition plan, built from your stats "
          "(${profile.weight.toStringAsFixed(0)} kg, ${profile.height.toStringAsFixed(0)} cm, goal: ${profile.goal.toLowerCase()}):\n\n"
          "• Calories: ${t.caloriesLow}–${t.caloriesHigh} kcal/day. ${t.pace}\n"
          "• Protein: ${t.proteinG} g/day (~${t.proteinPerKg} g/kg) — this is the priority number; hit it daily.\n"
          "• Strategy: ${t.strategy}\n"
          "• Self-correct: ${t.adjustRule}\n\n"
          "Track protein on your Dashboard and re-check the mirror + 7-day weight average every 4 weeks. "
          "Want me to break the protein into meals, or adjust for a specific food preference?";
    }

    // Aesthetics / physique goals — reweight advice around the V-taper.
    if (query.contains('aesthetic') ||
        query.contains('v-taper') ||
        query.contains('v taper') ||
        query.contains('physique') ||
        query.contains('beach')) {
      return "For an aesthetic look, the levers are shoulder width, lat width, upper chest, and a tight waist — proportions over raw size.\n\n"
          "• Prioritize side delts (~10-12 weekly sets spread over 2-3 days), lats (pulldowns/pull-ups for width), and incline pressing (~8 sets).\n"
          "• Protect the taper: core via planks and hanging leg raises 2×/week; skip heavy weighted side bends — thick obliques work against the V.\n"
          "• The tight-waist look is mostly leanness + not overbuilding obliques.\n"
          "• At ${profile.weight.toStringAsFixed(0)} kg your best move is almost always a slow lean gain, not a cut — build the frame first, then reveal it.\n\n"
          "Ask me for a nutrition plan and I'll give you exact numbers, or tell me which of these areas lags most and we'll bias your program toward it.";
    }

    if (query.contains('program') || query.contains('split')) {
      if (currentProgram != null) {
        return "Your '${currentProgram.name}' split is calibrated specifically for your '${profile.goal}' goal. Since you have '${profile.equipment.toLowerCase()}' equipment, we are emphasizing core movements like ${currentProgram.days.first.exercises.map((e) => e.name).take(2).join(' and ')} to build robust joint capacity without overloading.";
      }
      return "I see you haven't generated a custom program yet! Once we walk through Onboarding, I will build you a personalized progressive overload blueprint.";
    } else if (query.contains('weight') || query.contains('how heavy') || query.contains('why this weight')) {
      return "I suggest weights based on your experience (${profile.experience}) and your past performance. Your current target is designed to keep you in your strategic rep zone (${profile.goal == 'Get Stronger' ? '4-6 reps for strength' : '8-12 reps for hypertrophy'}) with a 2 RIR (Reps in Reserve) buffer.";
    } else if (query.contains('30 min') ||
        query.contains('cut') ||
        query.contains('short on time') ||
        query.contains('no time')) {
      // Answer about the session that is actually scheduled today, by name.
      if (todaysSession == null) {
        return "Nothing is scheduled for $weekdayLong — it's a rest day, so there's "
            "nothing to cut. Keep the rest; a short walk is plenty.\n\n"
            "If you'd rather train, tell me and I'll pick which session to bring "
            "forward.";
      }
      final keep = todaysExercises.take(2).toList();
      final drop = todaysExercises.skip(2).toList();
      return "Today ($weekdayLong) is $todaysSession. In 30 minutes, keep "
          "${keep.isEmpty ? 'the first two compounds' : keep.join(' and ')} — "
          "3 hard sets each, 2 minutes rest.\n\n"
          "${drop.isEmpty ? 'Drop anything left over.' : 'Drop ${drop.join(', ')}.'} "
          "The compounds carry most of the adaptation; the accessories are what a "
          "short day is for losing.\n\n"
          "Log it as normal — a short session logged beats a full one skipped.";
    } else if (query.contains('injury') || query.contains('pain')) {
      final injuries = profile.injuries.isNotEmpty
          ? profile.injuries.join(', ')
          : 'nothing on file';
      return "Sharp or joint pain means stop the movement — don't train through "
          "it. I can't diagnose, and if it persists past a few days or hurts "
          "outside the gym, see a physio.\n\n"
          "Your profile lists: $injuries. Tell me which movement hurts and where, "
          "and I'll swap it for something that trains the same muscle without "
          "loading that joint.";
    }

    // Nothing matched. Be honest about it instead of dressing a generic line up
    // as an answer — and say what this offline coach can actually do, so the
    // user isn't left guessing why the reply missed.
    final sessions = ref.read(workoutHistoryProvider).where((s) => s.completed);
    final logged = sessions.length;
    return "I'm running offline right now, so I'm working from your plan rather "
        "than thinking it through properly — say it another way and I'll try "
        "again.\n\n"
        "What I can answer offline: what's on today, what to cut when time is "
        "short, your nutrition numbers, and how your week is laid out. "
        "${logged == 0 ? 'Once you log a few sessions I can talk about your actual lifts too.' : "You've logged $logged sessions, and I read them when I'm connected."}";
  }

  static String _longWeekday(String abbrev) => const {
        'Mon': 'Monday',
        'Tue': 'Tuesday',
        'Wed': 'Wednesday',
        'Thu': 'Thursday',
        'Fri': 'Friday',
        'Sat': 'Saturday',
        'Sun': 'Sunday',
      }[abbrev] ??
      abbrev;
}

final coachChatProvider =
    NotifierProvider<CoachChatNotifier, List<ChatMessage>>(CoachChatNotifier.new);

/// True while the cloud coach call is in flight — drives the typing indicator
/// and disables double-sends.
class CoachThinkingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final coachThinkingProvider =
    NotifierProvider<CoachThinkingNotifier, bool>(CoachThinkingNotifier.new);

/// A standing "want me to actually change your plan?" action in the coach
/// chat, tied to the reply it appeared under.
///
/// This is an offer, not a change: the plan rewrite still goes through the
/// normal propose-review-apply path when the user takes it.
class ScheduleOffer {
  const ScheduleOffer({required this.request, required this.afterMessageId});

  /// What the user asked for, in their words — this is what gets sent to the
  /// plan editor, not Coach's prose answer.
  final String request;

  /// The reply this offer belongs to, so it renders in the right place and a
  /// later conversation can't inherit it.
  final String afterMessageId;
}

class ScheduleOfferNotifier extends Notifier<ScheduleOffer?> {
  @override
  ScheduleOffer? build() => null;

  void set(ScheduleOffer? offer) => state = offer;
  void clear() => state = null;
}

final scheduleOfferProvider =
    NotifierProvider<ScheduleOfferNotifier, ScheduleOffer?>(
        ScheduleOfferNotifier.new);

// ---------------------------------------------------------------------------
// 10. Authentication State Provider
// ---------------------------------------------------------------------------

class AuthState {
  final bool isAuthenticated;
  final String? email;
  final String? name;

  /// Stable account key: Supabase user id, or email in local/offline mode.
  final String? userId;

  const AuthState({
    required this.isAuthenticated,
    this.email,
    this.name,
    this.userId,
  });

  /// Identity used to detect account switches on this device.
  String? get accountKey =>
      userId ??
      (email != null && email!.isNotEmpty ? email!.toLowerCase() : null);

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? name,
    String? userId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      name: name ?? this.name,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() => {
        'isAuthenticated': isAuthenticated,
        'email': email,
        'name': name,
        'userId': userId,
      };

  factory AuthState.fromJson(Map<String, dynamic> json) => AuthState(
        isAuthenticated: json['isAuthenticated'] as bool? ?? false,
        email: json['email'] as String?,
        name: json['name'] as String?,
        userId: json['userId'] as String?,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  /// Serializes bind/restore so startup's initial session + auth stream
  /// don't race (double wipe / clobber onboarding).
  Future<void> _authApplyChain = Future.value();

  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);

    // Cloud mode: Supabase's session is the source of truth; mirror its stream
    // into our state (and it persists its own session under the hood).
    if (repo.isCloud) {
      final sub = repo.authStateChanges().listen((s) {
        unawaited(_enqueueAuthApply(s));
      });
      ref.onDispose(sub.cancel);
      // Bind immediately for an already-restored session (no wipe if same user).
      final initial = repo.currentAuthState();
      if (initial.isAuthenticated) {
        unawaited(_enqueueAuthApply(initial));
      }
      return initial;
    }

    // Local mode: persist our own mock auth so sign-in survives restarts.
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kAuth, next.toJson()));
    final saved = store.getMap(LocalStore.kAuth);
    return saved != null
        ? AuthState.fromJson(saved)
        : const AuthState(isAuthenticated: false);
  }

  Future<void> _enqueueAuthApply(AuthState next) {
    _authApplyChain = _authApplyChain
        .catchError((_) {})
        .then((_) => _applyAuthState(next));
    return _authApplyChain;
  }

  /// Clears local user data and rebuilds providers when [next] is a different
  /// account than the one last bound on this device. Then restores cloud
  /// profile (onboarding flag, XP, etc.) when available.
  Future<void> _applyAuthState(AuthState next) async {
    if (!next.isAuthenticated) {
      state = next;
      return;
    }
    final key = next.accountKey;
    if (key == null) {
      state = next;
      return;
    }

    final store = ref.read(localStoreProvider);
    final last = store.getString(LocalStore.kLastAccountId);
    // Only wipe on a real account switch. If [last] is null (first bind after
    // install / upgrade), keep local profile so completed onboarding survives.
    final switched = last != null && last != key;
    if (switched) {
      await store.clearUserData();
      _invalidateUserDataProviders();
    }
    if (last != key) {
      await store.setString(LocalStore.kLastAccountId, key);
    }
    state = next;

    // Seed name from auth if profile is still blank.
    final profile = ref.read(userProfileProvider);
    if (profile.name.trim().isEmpty &&
        next.name != null &&
        next.name!.trim().isNotEmpty) {
      ref
          .read(userProfileProvider.notifier)
          .updateProfile(profile.copyWith(name: next.name!.trim()));
    }

    // Pull latest cloud profile to ensure local cache is up to date (e.g. Pro status, onboarding, XP).
    if (ref.read(authRepositoryProvider).isCloud) {
      try {
        await ref.read(syncServiceProvider).restore(ref.read);
      } catch (_) {}
    }
    _healMissingProgram();
  }

  /// Rebuilds the training program when the profile says onboarding is done but
  /// no program exists locally.
  ///
  /// This is the reinstall / new-device case: `profiles.onboarding_complete`
  /// restores from Supabase, but programs don't sync yet (they still need UUID
  /// keys). Without this the router skips onboarding — the only place a program
  /// is ever created — and Today/Dashboard/Coach sit on empty placeholders
  /// forever with no way out.
  ///
  /// Generation is deterministic from the profile, so the rebuilt program is
  /// exactly what onboarding would have produced from the same answers.
  void _healMissingProgram() {
    final profile = ref.read(userProfileProvider);
    if (!profile.hasCompletedOnboarding) return;
    if (ref.read(programProvider) != null) return;
    ref.read(programProvider.notifier).generateProgram(profile);
  }

  void _invalidateUserDataProviders() {
    ref.invalidate(userProfileProvider);
    ref.invalidate(programProvider);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(activeWorkoutProvider);
    ref.invalidate(questProvider);
    ref.invalidate(bodyweightProvider);
    ref.invalidate(measurementsProvider);
    ref.invalidate(progressPhotosProvider);
    ref.invalidate(hydrationProvider);
    ref.invalidate(coachChatProvider);
    ref.invalidate(prCelebrationProvider);
    ref.invalidate(levelUpProvider);
  }

  Future<void> _wipeLocalSession() async {
    final store = ref.read(localStoreProvider);
    await store.clearUserData();
    await store.remove(LocalStore.kLastAccountId);
    _invalidateUserDataProviders();
  }

  void _syncFromCloud(AuthRepository repo) {
    unawaited(_enqueueAuthApply(repo.currentAuthState()));
  }

  /// Turns any auth failure into one short, human sentence.
  ///
  /// Order matters: connectivity is checked *before* reading
  /// `exception.message`, because for a `ClientException`/`SocketException`
  /// that field is the whole raw dump ("ClientException with SocketException:
  /// Failed host lookup … errno = 7") which must never reach a user.
  String _friendlyAuthError(Object e) {
    final raw = e.toString();

    // Keep the technical detail for logs/crash reports only.
    debugPrint('Auth error: $raw');

    // --- 1. Connectivity ---------------------------------------------------
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Network is unreachable') ||
        raw.contains('Connection refused') ||
        raw.contains('Connection closed') ||
        raw.contains('HandshakeException') ||
        raw.contains('TimeoutException') ||
        raw.contains('ClientException')) {
      return "Can't reach the server. Check your internet connection and try again.";
    }

    // --- 2. Known auth outcomes (match the raw text, not .message) ---------
    if (raw.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Confirm your email first — check your inbox and spam folder.';
    }
    if (raw.contains('User already registered')) {
      return 'That email is already registered. Try logging in instead.';
    }
    if (raw.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('Unable to validate email address') ||
        raw.contains('invalid format')) {
      return 'That email address doesn\'t look right.';
    }
    if (raw.contains('For security purposes') ||
        raw.contains('rate limit') ||
        raw.contains('Too many requests')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (raw.contains('Anonymous sign-ins are disabled')) {
      return 'Guest mode isn\'t available right now. Please sign up with email.';
    }
    // Provider (Google/Apple) not switched on in the Supabase dashboard.
    // Deliberately user-facing — a gym user can't act on "Supabase project".
    if (raw.contains('provider is not enabled') ||
        raw.contains('Unsupported provider')) {
      return 'That sign-in option isn\'t available yet. Please use email.';
    }

    // --- 3. A clean server message, if it is short enough to show ----------
    try {
      // ignore: avoid_dynamic_calls
      final msg = (e as dynamic).message;
      if (msg is String &&
          msg.trim().isNotEmpty &&
          msg.length < 120 &&
          !msg.contains('Exception')) {
        return msg;
      }
    } catch (_) {}

    // --- 4. Last resort — never leak a stack trace or URL ------------------
    return 'Something went wrong. Please try again.';
  }

  /// Returns null on success, or a user-facing error / info message.
  Future<String?> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo.isCloud) {
      try {
        final res = await repo.signInWithPassword(email, password);
        if (res.session == null) {
          return 'Signed in, but no session yet. Confirm your email if required.';
        }
        _syncFromCloud(repo);
        return null;
      } catch (e) {
        return _friendlyAuthError(e);
      }
    }
    final next = AuthState(
      isAuthenticated: true,
      email: email,
      name: email.split('@').first,
      userId: email.toLowerCase(),
    );
    await _enqueueAuthApply(next);
    return null;
  }

  /// Returns null on success, or a user-facing error / info message.
  /// When Supabase requires email confirmation, signup can succeed with no
  /// session — we return an info string so the UI can explain instead of
  /// appearing to do nothing.
  Future<String?> signup(String name, String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo.isCloud) {
      try {
        final res = await repo.signUpWithPassword(name, email, password);
        if (res.session == null) {
          return 'Account created. Check your email to confirm, then log in. '
              '(Or turn off “Confirm email” in Supabase Auth → Providers → Email.)';
        }
        _syncFromCloud(repo);
        return null;
      } catch (e) {
        return _friendlyAuthError(e);
      }
    }
    final next = AuthState(
      isAuthenticated: true,
      email: email,
      name: name,
      userId: email.toLowerCase(),
    );
    await _enqueueAuthApply(next);
    return null;
  }

  /// Guest access. Cloud → anonymous sign-in; local → an instant guest session
  /// (matches the previous behavior the onboarding save-prompt keys off).
  Future<String?> continueAsGuest() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo.isCloud) {
      try {
        final res = await repo.signInAnonymously();
        if (res.session == null) {
          return 'Guest sign-in failed (no session). Enable Anonymous auth in Supabase.';
        }
        _syncFromCloud(repo);
        return null;
      } catch (e) {
        return _friendlyAuthError(e);
      }
    }
    const next = AuthState(
      isAuthenticated: true,
      email: 'guest@crux.com',
      name: 'Guest',
      userId: 'local-guest',
    );
    await _enqueueAuthApply(next);
    return null;
  }

  /// Opens Google OAuth in the browser. Session arrives via deep link + stream.
  Future<String?> signInWithGoogle() async {
    final repo = ref.read(authRepositoryProvider);
    if (!repo.isCloud) {
      return continueAsGuest();
    }
    try {
      final launched = await repo.signInWithGoogle();
      if (!launched) {
        return 'Could not open Google sign-in. Check that Google is enabled in Supabase Auth → Providers.';
      }
      return null;
    } catch (e) {
      return _friendlyAuthError(e);
    }
  }

  Future<String?> signInWithApple() async {
    final repo = ref.read(authRepositoryProvider);
    if (!repo.isCloud) {
      return continueAsGuest();
    }
    try {
      final launched = await repo.signInWithApple();
      if (!launched) {
        return 'Could not open Apple sign-in. Check that Apple is enabled in Supabase Auth → Providers.';
      }
      return null;
    } catch (e) {
      return _friendlyAuthError(e);
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    // Wipe local user data first so the next account never inherits it.
    await _wipeLocalSession();
    if (repo.isCloud) {
      try {
        await repo.signOut();
      } catch (_) {}
    }
    state = const AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ---------------------------------------------------------------------------
// 11. App Settings Provider (rest-timer default, reminders)
// ---------------------------------------------------------------------------

class AppSettings {
  final int restTimerSeconds;
  final bool remindersEnabled;

  /// Play a repeating tone + haptic when the rest timer hits zero.
  /// User can silence it mid-alert from the workout screen.
  final bool restCompleteSoundEnabled;

  /// Hydration nudges (3 gentle daily notifications).
  final bool hydrationRemindersEnabled;

  /// One-time explainers the user has already dismissed (Phase 4 asks for a
  /// one-time "why the rolling average matters" note on the weigh-in chart).
  final bool seenWeightAvgExplainer;

  /// Whether we've already asked Android for exact-alarm scheduling access
  /// (the "Alarms & reminders" toggle) so the rest-timer notification rings
  /// on time. Asked once ever — repeatedly bouncing the user to Settings if
  /// they decline once would be annoying, and inexact scheduling still works
  /// as a fallback either way.
  final bool exactAlarmRequested;

  const AppSettings({
    this.restTimerSeconds = 90,
    this.remindersEnabled = false,
    this.restCompleteSoundEnabled = true,
    this.hydrationRemindersEnabled = false,
    this.seenWeightAvgExplainer = false,
    this.exactAlarmRequested = false,
  });

  AppSettings copyWith({
    int? restTimerSeconds,
    bool? remindersEnabled,
    bool? restCompleteSoundEnabled,
    bool? hydrationRemindersEnabled,
    bool? seenWeightAvgExplainer,
    bool? exactAlarmRequested,
  }) {
    return AppSettings(
      restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      restCompleteSoundEnabled:
          restCompleteSoundEnabled ?? this.restCompleteSoundEnabled,
      hydrationRemindersEnabled:
          hydrationRemindersEnabled ?? this.hydrationRemindersEnabled,
      seenWeightAvgExplainer:
          seenWeightAvgExplainer ?? this.seenWeightAvgExplainer,
      exactAlarmRequested: exactAlarmRequested ?? this.exactAlarmRequested,
    );
  }

  Map<String, dynamic> toJson() => {
        'restTimerSeconds': restTimerSeconds,
        'remindersEnabled': remindersEnabled,
        'restCompleteSoundEnabled': restCompleteSoundEnabled,
        'hydrationRemindersEnabled': hydrationRemindersEnabled,
        'seenWeightAvgExplainer': seenWeightAvgExplainer,
        'exactAlarmRequested': exactAlarmRequested,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        restTimerSeconds: (json['restTimerSeconds'] as num?)?.toInt() ?? 90,
        remindersEnabled: json['remindersEnabled'] as bool? ?? false,
        restCompleteSoundEnabled:
            json['restCompleteSoundEnabled'] as bool? ?? true,
        hydrationRemindersEnabled:
            json['hydrationRemindersEnabled'] as bool? ?? false,
        seenWeightAvgExplainer:
            json['seenWeightAvgExplainer'] as bool? ?? false,
        exactAlarmRequested: json['exactAlarmRequested'] as bool? ?? false,
      );
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kSettings, next.toJson()));
    final saved = store.getMap(LocalStore.kSettings);
    return saved != null ? AppSettings.fromJson(saved) : const AppSettings();
  }

  void setRestTimerSeconds(int seconds) {
    state = state.copyWith(restTimerSeconds: seconds);
  }

  void setReminders(bool enabled) {
    state = state.copyWith(remindersEnabled: enabled);
  }

  void setHydrationReminders(bool enabled) {
    state = state.copyWith(hydrationRemindersEnabled: enabled);
  }

  void setRestCompleteSound(bool enabled) {
    state = state.copyWith(restCompleteSoundEnabled: enabled);
  }

  void markWeightAvgExplainerSeen() {
    state = state.copyWith(seenWeightAvgExplainer: true);
  }

  void markExactAlarmRequested() {
    state = state.copyWith(exactAlarmRequested: true);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
