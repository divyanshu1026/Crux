import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders (plan Phase 8.2 "reminders" made real).
///
/// Two honest, non-spammy schedules — matching the notification-permission
/// promise made during onboarding:
///  * Training-day reminders: one notification on each planned weekday.
///  * Hydration reminders: three gentle nudges spread through the day.
///
/// Every call is wrapped so a notification failure can never crash the app,
/// and everything is a no-op on web (plugin unsupported there).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _trainingIdBase = 100; // +1..7 per weekday
  static const _hydrationIds = [201, 202, 203];
  static const _hydrationTimes = [(11, 0), (15, 0), (19, 0)];
  static const _restCompleteId = 401;

  static const _androidChannel = AndroidNotificationDetails(
    'crux_reminders',
    'Reminders',
    channelDescription: 'Training-day and hydration reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const _details = NotificationDetails(
    android: _androidChannel,
    iOS: DarwinNotificationDetails(),
  );

  // Rest-complete gets its own louder channel — it's a short, time-critical
  // "your set is ready" ping (not a routine reminder), so it should make
  // sound/vibrate even when the phone is locked mid-workout.
  static const _restChannel = AndroidNotificationDetails(
    'crux_rest_timer',
    'Rest timer',
    channelDescription: 'Rings when your rest between sets is over',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    playSound: true,
    enableVibration: true,
  );
  static const _restDetails = NotificationDetails(
    android: _restChannel,
    iOS: DarwinNotificationDetails(
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  /// Initialize plugin + timezone database. Safe to call more than once.
  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final localTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTz));
      } catch (_) {
        // Keep the default (UTC) location — reminders still fire, just may be
        // offset; better than failing init entirely.
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Asks the OS for permission (Android 13+ / iOS). Returns granted-ness;
  /// null-safe on platforms where the request isn't applicable.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  /// Schedules one weekly reminder per planned weekday at 17:30 local time.
  /// [plannedWeekdays] uses 'Mon'..'Sun'.
  Future<void> scheduleTrainingReminders(List<String> plannedWeekdays) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await cancelTrainingReminders();
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var wd = 1; wd <= 7; wd++) {
        if (!plannedWeekdays.contains(names[wd - 1])) continue;
        await _plugin.zonedSchedule(
          _trainingIdBase + wd,
          'Training day',
          'You planned ${names[wd - 1]} — your session is ready in Crux.',
          _nextInstanceOfWeekdayTime(wd, 17, 30),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (_) {}
  }

  Future<void> cancelTrainingReminders() async {
    if (kIsWeb || !_ready) return;
    try {
      for (var wd = 1; wd <= 7; wd++) {
        await _plugin.cancel(_trainingIdBase + wd);
      }
    } catch (_) {}
  }

  /// Three daily hydration nudges (11:00, 15:00, 19:00 local).
  Future<void> scheduleHydrationReminders() async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await cancelHydrationReminders();
      const bodies = [
        'Morning check-in: a glass of water keeps the engine running.',
        'Midday top-up — your muscles are ~75% water.',
        'Evening reminder: close out your water goal for today.',
      ];
      for (var i = 0; i < _hydrationIds.length; i++) {
        final (h, m) = _hydrationTimes[i];
        await _plugin.zonedSchedule(
          _hydrationIds[i],
          'Hydration',
          bodies[i],
          _nextInstanceOfTime(h, m),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {}
  }

  Future<void> cancelHydrationReminders() async {
    if (kIsWeb || !_ready) return;
    try {
      for (final id in _hydrationIds) {
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }

  /// Schedules the one-shot "rest is over" alert for [firesAt] — the OS fires
  /// this regardless of whether the app is foregrounded, backgrounded, or the
  /// phone is locked, which is the only reliable way to alert the user during
  /// a rest period (in-app sound/haptics can't run without an active frame).
  ///
  /// Tries exact scheduling first (so it rings within a second or two of the
  /// real end time, which matters for a short 60–180s rest); if the OS denies
  /// exact-alarm scheduling (Android 12+ without the user granting "Alarms &
  /// reminders"), falls back to inexact so the notification still fires, just
  /// with looser timing, rather than not firing at all.
  Future<void> scheduleRestComplete(DateTime firesAt,
      {required String exerciseName}) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    final zoned = tz.TZDateTime.from(firesAt, tz.local);
    try {
      await _plugin.zonedSchedule(
        _restCompleteId,
        'Rest over',
        'Back to $exerciseName — your next set is ready.',
        zoned,
        _restDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          _restCompleteId,
          'Rest over',
          'Back to $exerciseName — your next set is ready.',
          zoned,
          _restDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelRestComplete() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(_restCompleteId);
    } catch (_) {}
  }

  /// Requests Android 12+ exact-alarm access ("Alarms & reminders"). Safe to
  /// call anywhere — a no-op on platforms/versions where it doesn't apply,
  /// and scheduling still falls back to inexact if this is never granted.
  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    var next = _nextInstanceOfTime(hour, minute);
    while (next.weekday != weekday) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);
