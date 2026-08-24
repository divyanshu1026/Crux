import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON wrapper over [SharedPreferences] — the app's local-first store.
/// Every stateful provider hydrates from here on build and writes back on
/// change, so data survives app restarts with no cloud dependency.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  /// Storage keys. Keep stable — changing one silently drops persisted data.
  static const kProfile = 'rq.profile';
  static const kProgram = 'rq.program';
  static const kHistory = 'rq.history';
  static const kBodyweight = 'rq.bodyweight';
  static const kMeasurements = 'rq.measurements';
  static const kPhotos = 'rq.photos';
  static const kQuests = 'rq.quests';
  static const kSettings = 'rq.settings';
  static const kAuth = 'rq.auth';
  static const kChat = 'rq.chat';
  static const kThemeMode = 'rq.themeMode';
  static const kActiveWorkout = 'rq.activeWorkout';
  static const kRestTimer = 'rq.restTimer';
  static const kHydration = 'rq.hydration';
  static const kProtein = 'rq.protein';
  static const kQuestsWeekKey = 'rq.questsWeekKey';
  static const kStreakCheckedOn = 'rq.streakCheckedOn';
  static const kMissedDayDismissedOn = 'rq.missedDayDismissedOn';
  static const kWeekCompleteShownFor = 'rq.weekCompleteShownFor';

  /// Last signed-in account id (Supabase uid or local email). Used to wipe
  /// local data when a different account signs in on this device.
  static const kLastAccountId = 'rq.lastAccountId';
  static const kBackupSchedule = 'rq.backupSchedule';
  static const kSavedSchedules = 'rq.savedSchedules';

  /// User-owned keys wiped on logout / account switch. Device prefs
  /// (theme, settings) are kept.
  static const userDataKeys = <String>[
    kProfile,
    kProgram,
    kHistory,
    kBodyweight,
    kMeasurements,
    kPhotos,
    kQuests,
    kChat,
    kAuth,
    kActiveWorkout,
    kRestTimer,
    kHydration,
    kProtein,
    kQuestsWeekKey,
    kStreakCheckedOn,
    kMissedDayDismissedOn,
    kWeekCompleteShownFor,
  ];

  Map<String, dynamic>? getMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<dynamic>? getList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Erases all per-user workout/profile data on this device. Does not touch
  /// theme or app settings.
  Future<void> clearUserData() async {
    for (final key in userDataKeys) {
      await _prefs.remove(key);
    }
  }
}

/// Overridden in `main()` with the initialized instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main()'),
);

final localStoreProvider =
    Provider<LocalStore>((ref) => LocalStore(ref.read(sharedPreferencesProvider)));
