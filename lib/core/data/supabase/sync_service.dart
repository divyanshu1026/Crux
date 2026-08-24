import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import 'supabase_config.dart';

/// Thrown when a sync can't run (offline/unconfigured/not-signed-in).
class SyncException implements Exception {
  SyncException(this.message);
  final String message;
}

/// Queue-free "backup / restore" sync against the Supabase schema. Gated on a
/// configured project + a signed-in user, so it never runs in local/offline
/// mode. Currently covers the two tables whose keys map cleanly today:
///   * `profiles` (row id == auth uid)
///   * `body_logs` (natural key: user_id + logged_on)
///
/// Workouts/programs need the client models to adopt UUID primary keys before
/// they can round-trip to the uuid-keyed tables — that's the next step and is
/// intentionally left out rather than shipped half-correct.
class SyncService {
  // Client display strings ↔ normalized DB enum values.
  static const _sexToDb = {
    'Male': 'male',
    'Female': 'female',
    'Prefer not to say': 'prefer_not_to_say',
  };
  static const _expToDb = {
    'Never trained': 'never_trained',
    '<6 months': 'under_6_months',
    '6–24 months': '6_to_24_months',
    '2+ years': '2_plus_years',
  };
  static const _goalToDb = {
    'Build Muscle': 'build_muscle',
    'Get Stronger': 'get_stronger',
    'Lose Fat & Tone': 'lose_fat_tone',
    'General Fitness': 'general_fitness',
  };
  static const _equipToDb = {
    'Full gym': 'full_gym',
    'Dumbbells only': 'dumbbells_only',
    'Minimal home': 'minimal_home',
  };

  static String _reverse(
      Map<String, String> m, String? dbValue, String fallback) {
    for (final e in m.entries) {
      if (e.value == dbValue) return e.key;
    }
    return fallback;
  }

  void _guard() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw SyncException('Cloud sync is not configured.');
    }
    if (client.auth.currentUser == null) {
      throw SyncException('Sign in to sync your data.');
    }
  }

  /// Push local profile + weigh-ins up to Supabase (backup).
  /// Pass `ref.read` from a [Ref] or [WidgetRef].
  Future<void> backup(dynamic read) async {
    _guard();
    final client = SupabaseConfig.clientOrNull!;
    final uid = client.auth.currentUser!.id;

    final UserProfile p = read(userProfileProvider);
    await client.from('profiles').upsert({
      'id': uid,
      'name': p.name,
      'sex': _sexToDb[p.sex] ?? 'prefer_not_to_say',
      // The client stores age; approximate dob (Jan 1) so the server-side
      // coach can compute age for nutrition math.
      'dob': '${DateTime.now().year - p.age}-01-01',
      'height_cm': p.height,
      'experience_level': _expToDb[p.experience] ?? 'never_trained',
      'goal': _goalToDb[p.goal] ?? 'build_muscle',
      'days_per_week': p.daysPerWeek,
      'equipment': _equipToDb[p.equipment] ?? 'full_gym',
      'units': p.units == 'lbs' ? 'imperial' : 'metric',
      'avatar_id': p.avatar,
      'injuries': p.injuries,
      'level': p.level,
      'xp': p.xp,
      'streak_weeks': p.streak,
      'zen_mode': p.zenMode,
      'notification_opt_in': p.notificationPermission,
      'onboarding_complete': p.hasCompletedOnboarding,
    });

    final List<WeighIn> weighIns = read(bodyweightProvider);
    if (weighIns.isNotEmpty) {
      final rows = weighIns
          .map((w) => {
                'user_id': uid,
                'logged_on': _dateOnly(w.date),
                'weight_kg': w.weight,
              })
          .toList();
      await client
          .from('body_logs')
          .upsert(rows, onConflict: 'user_id,logged_on');
    }

    await _backupWorkouts(client, uid, read(workoutHistoryProvider));
  }

  /// Pushes the training log — the data the app is actually for.
  ///
  /// Everything conflicts on `(user_id, client_id)`, so running this on every
  /// scheduled backup updates the same rows instead of accumulating a fresh
  /// copy of the user's history each week.
  Future<void> _backupWorkouts(
    SupabaseClient client,
    String uid,
    List<WorkoutSession> history,
  ) async {
    if (history.isEmpty) return;

    // Only completed sessions: an in-progress workout is still changing, and
    // half a session in the cloud is worse than none.
    final sessions = history.where((s) => s.completed).toList();
    if (sessions.isEmpty) return;

    final workoutRows = sessions
        .map((s) => {
              'user_id': uid,
              'client_id': s.id,
              'workout_day_name': s.workoutDayName,
              'started_at': (s.startedAt ?? s.date).toUtc().toIso8601String(),
              'completed_at': s.date.toUtc().toIso8601String(),
              'duration_seconds': s.durationSeconds,
              'total_volume_kg': s.totalVolume,
              'xp_earned': s.xpEarned,
            })
        .toList();

    final saved = await client
        .from('workouts')
        .upsert(workoutRows, onConflict: 'user_id,client_id')
        .select('id, client_id');

    // Map our ids back to the server's uuids so the sets can point at them.
    final idByClientId = {
      for (final row in saved)
        row['client_id'] as String: row['id'] as String,
    };

    final setRows = <Map<String, dynamic>>[];
    for (final s in sessions) {
      final workoutId = idByClientId[s.id];
      if (workoutId == null) continue;
      for (var e = 0; e < s.exercises.length; e++) {
        final ex = s.exercises[e];
        for (var i = 0; i < ex.sets.length; i++) {
          final set = ex.sets[i];
          setRows.add({
            'workout_id': workoutId,
            'user_id': uid,
            'client_id': '${s.id}:$e:$i',
            'exercise_name': ex.exerciseName,
            'muscle_group': ex.muscleGroup,
            'set_number': i + 1,
            'weight_kg': set.weight,
            'reps': set.reps,
            'note': set.note,
            'is_pr': set.isPR,
            'is_e1rm_pr': set.isEpleyPR,
            'is_warmup': set.isWarmup,
            'completed': set.completed,
          });
        }
      }
    }

    // Chunked: a year of training is thousands of sets, and one giant request
    // is the kind of thing that times out on gym wifi.
    const chunk = 500;
    for (var i = 0; i < setRows.length; i += chunk) {
      final end = (i + chunk).clamp(0, setRows.length);
      await client
          .from('set_logs')
          .upsert(setRows.sublist(i, end), onConflict: 'user_id,client_id');
    }
  }

  /// Pull profile + weigh-ins from Supabase into the local providers (restore).
  /// Pass `ref.read` from a [Ref] or [WidgetRef].
  /// Returns true when a cloud profile row existed.
  Future<bool> restore(dynamic read) async {
    _guard();
    final client = SupabaseConfig.clientOrNull!;
    final uid = client.auth.currentUser!.id;

    final profileRow = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (profileRow != null) {
      final UserProfile local = read(userProfileProvider);
      final cloudOnboarded = profileRow['onboarding_complete'] as bool? ?? false;
      // Never regress a completed onboarding from a stale/default cloud row
      // (profiles are created with onboarding_complete=false; backup can lag).
      final onboarded = local.hasCompletedOnboarding || cloudOnboarded;
      (read(userProfileProvider.notifier) as UserProfileNotifier)
          .updateProfile(local.copyWith(
            name: profileRow['name'] as String? ?? local.name,
            sex: _reverse(_sexToDb, profileRow['sex'] as String?, local.sex),
            age: profileRow['dob'] != null
                ? DateTime.now().year -
                    DateTime.parse(profileRow['dob'] as String).year
                : local.age,
            height:
                (profileRow['height_cm'] as num?)?.toDouble() ?? local.height,
            experience: _reverse(_expToDb,
                profileRow['experience_level'] as String?, local.experience),
            goal: _reverse(
                _goalToDb, profileRow['goal'] as String?, local.goal),
            equipment: _reverse(
                _equipToDb, profileRow['equipment'] as String?, local.equipment),
            daysPerWeek:
                (profileRow['days_per_week'] as List?)?.cast<String>() ??
                    local.daysPerWeek,
            units:
                (profileRow['units'] as String?) == 'imperial' ? 'lbs' : 'kg',
            avatar: profileRow['avatar_id'] as String? ?? local.avatar,
            injuries: (profileRow['injuries'] as List?)?.cast<String>() ??
                local.injuries,
            level: (profileRow['level'] as num?)?.toInt() ?? local.level,
            xp: (profileRow['xp'] as num?)?.toInt() ?? local.xp,
            streak:
                (profileRow['streak_weeks'] as num?)?.toInt() ?? local.streak,
            zenMode: profileRow['zen_mode'] as bool? ?? local.zenMode,
            isPro: profileRow['is_pro'] as bool? ?? local.isPro,
            proExpiresAt:
                DateTime.tryParse(profileRow['pro_expires_at'] as String? ?? '')
                    ?? local.proExpiresAt,
            notificationPermission:
                profileRow['notification_opt_in'] as bool? ??
                    local.notificationPermission,
            hasCompletedOnboarding: onboarded,
          ));

      // Heal cloud if the device already finished onboarding but Supabase
      // still has the default false from handle_new_user().
      if (onboarded && !cloudOnboarded) {
        try {
          await backup(read);
        } catch (_) {}
      }
    }

    final bodyRows = await client
        .from('body_logs')
        .select('logged_on, weight_kg')
        .eq('user_id', uid)
        .order('logged_on');
    if (bodyRows.isNotEmpty) {
      final weighIns = bodyRows
          .map((r) => WeighIn(
                date: DateTime.parse(r['logged_on'] as String),
                weight: (r['weight_kg'] as num).toDouble(),
              ))
          .toList();
      (read(bodyweightProvider.notifier) as BodyweightNotifier)
          .replaceAll(weighIns);
    }

    return profileRow != null;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());
