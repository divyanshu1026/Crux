import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_schedule.dart';
import '../data/local_store.dart';
import '../data/supabase/supabase_config.dart';
import '../data/supabase/sync_service.dart';
import 'app_lifecycle.dart';

/// The user's automatic-backup preferences, persisted locally.
class BackupScheduleNotifier extends Notifier<BackupSchedule> {
  @override
  BackupSchedule build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setJson(LocalStore.kBackupSchedule, next.toJson()));
    final saved = store.getMap(LocalStore.kBackupSchedule);
    return saved != null
        ? BackupSchedule.fromJson(saved)
        : const BackupSchedule();
  }

  void setEnabled(bool enabled) =>
      state = state.copyWith(enabled: enabled);

  void setFrequency(BackupFrequency frequency) =>
      state = state.copyWith(frequency: frequency);

  void setTime(int hour, int minute) =>
      state = state.copyWith(hour: hour, minute: minute);

  void markBackedUp(DateTime at) => state = state.copyWith(lastBackupAt: at);
}

final backupScheduleProvider =
    NotifierProvider<BackupScheduleNotifier, BackupSchedule>(
        BackupScheduleNotifier.new);

/// What the last automatic backup did. Surfaced in Settings so the feature is
/// inspectable rather than something the user has to take on faith.
enum BackupStatus { idle, running, ok, failed }

class BackupStatusNotifier extends Notifier<BackupStatus> {
  @override
  BackupStatus build() => BackupStatus.idle;
  void set(BackupStatus s) => state = s;
}

final backupStatusProvider =
    NotifierProvider<BackupStatusNotifier, BackupStatus>(
        BackupStatusNotifier.new);

/// Runs the scheduled backup when one is due.
///
/// ## Why this is triggered by app lifecycle rather than a real 2am timer
///
/// Android does not let an ordinary app guarantee it will execute at 02:00.
/// Doze, App Standby and per-manufacturer battery managers all suspend
/// background work, and the OS is entitled to kill the process entirely. An
/// implementation that promised a wake-up at exactly 2am would quietly not
/// happen for most users, which is worse than not promising it.
///
/// So the scheduled time is treated as the moment a backup becomes *due*, and
/// the app settles the debt the next time it is open. In practice that means
/// backups land within a day of their slot for anyone who uses the app, and
/// the 02:00 default still does its real job: it guarantees the boundary never
/// falls mid-workout, so a backup can't interrupt a session.
class BackupRunner {
  BackupRunner(this.ref);
  final Ref ref;

  bool _inFlight = false;

  /// Backs up if [BackupSchedule.isDue]. Safe to call often — it is cheap when
  /// nothing is due, and will not overlap itself.
  Future<void> maybeRun({DateTime? now}) async {
    if (_inFlight) return;
    final at = now ?? DateTime.now();
    final schedule = ref.read(backupScheduleProvider);
    if (!schedule.isDue(at)) return;
    if (!SupabaseConfig.isConfigured) return;
    // Nothing to back up to without an account. Not an error — plenty of
    // people use the app entirely offline.
    if (SupabaseConfig.clientOrNull?.auth.currentUser == null) return;

    _inFlight = true;
    ref.read(backupStatusProvider.notifier).set(BackupStatus.running);
    try {
      await ref.read(syncServiceProvider).backup(ref.read);
      ref.read(backupScheduleProvider.notifier).markBackedUp(at);
      ref.read(backupStatusProvider.notifier).set(BackupStatus.ok);
    } catch (e) {
      // A failed backup must never surface as an error the user has to dismiss
      // — they didn't ask for it to run now. It retries on the next open.
      debugPrint('scheduled backup failed: $e');
      ref.read(backupStatusProvider.notifier).set(BackupStatus.failed);
    } finally {
      _inFlight = false;
    }
  }
}

final backupRunnerProvider = Provider<BackupRunner>(BackupRunner.new);

/// Wires the runner to app foregrounding. Watch once, at the root.
final backupSchedulerProvider = Provider<void>((ref) {
  // Check on launch...
  Future<void>.microtask(() => ref.read(backupRunnerProvider).maybeRun());
  // ...and every time the app comes back to the foreground.
  ref.listen<bool>(appIsForegroundProvider, (was, isForeground) {
    if (isForeground && was != true) {
      unawaited(ref.read(backupRunnerProvider).maybeRun());
    }
  });
});
