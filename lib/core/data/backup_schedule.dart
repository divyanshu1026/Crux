/// How often the app backs itself up, and when the next one is due.
///
/// Pure date maths, kept out of the providers so it can be tested without a
/// container, a clock, or a network.
library;

enum BackupFrequency {
  daily,
  weekly,
  monthly,
  quarterly;

  /// What the user sees in Settings.
  String get label => switch (this) {
        BackupFrequency.daily => 'Daily',
        BackupFrequency.weekly => 'Weekly',
        BackupFrequency.monthly => 'Monthly',
        BackupFrequency.quarterly => 'Every 3 months',
      };

  String get blurb => switch (this) {
        BackupFrequency.daily => 'Safest — never lose more than a day',
        BackupFrequency.weekly => 'A good balance for most people',
        BackupFrequency.monthly => 'Light touch',
        BackupFrequency.quarterly => 'Minimal — you could lose 3 months',
      };

  Duration get interval => switch (this) {
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
        BackupFrequency.monthly => const Duration(days: 30),
        BackupFrequency.quarterly => const Duration(days: 90),
      };

  static BackupFrequency fromName(String? name) => BackupFrequency.values
      .firstWhere((f) => f.name == name, orElse: () => BackupFrequency.weekly);
}

/// The user's backup preferences.
class BackupSchedule {
  const BackupSchedule({
    this.enabled = true,
    this.frequency = BackupFrequency.weekly,
    this.hour = 2,
    this.minute = 0,
    this.lastBackupAt,
  });

  final bool enabled;
  final BackupFrequency frequency;

  /// Local time of day the backup becomes due. Defaults to 02:00 — nobody is
  /// mid-set at 2am, so a backup then can never interrupt a workout.
  final int hour;
  final int minute;

  final DateTime? lastBackupAt;

  /// The moment this backup became (or becomes) due.
  ///
  /// Anchored to [lastBackupAt] plus the interval, then snapped to the chosen
  /// time of day. Never earlier than the last backup, so changing the time
  /// can't retroactively make one overdue the instant it's saved.
  DateTime nextDueAfter(DateTime last) {
    final target = last.add(frequency.interval);
    final at = DateTime(target.year, target.month, target.day, hour, minute);
    return at.isBefore(last) ? at.add(const Duration(days: 1)) : at;
  }

  /// Whether a backup should run at [now].
  ///
  /// A first-ever backup is due immediately: waiting a week to protect data
  /// the user already has would be the wrong way round.
  bool isDue(DateTime now) {
    if (!enabled) return false;
    final last = lastBackupAt;
    if (last == null) return true;
    return !now.isBefore(nextDueAfter(last));
  }

  /// Human-readable "when's the next one", for Settings.
  String describeNext(DateTime now) {
    if (!enabled) return 'Automatic backup is off';
    final last = lastBackupAt;
    if (last == null) return 'Runs next time you open the app';
    final due = nextDueAfter(last);
    if (!now.isBefore(due)) return 'Due now';
    final delta = due.difference(now);
    if (delta.inHours < 24) return 'Next in ${delta.inHours}h';
    return 'Next in ${delta.inDays}d';
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  BackupSchedule copyWith({
    bool? enabled,
    BackupFrequency? frequency,
    int? hour,
    int? minute,
    DateTime? lastBackupAt,
  }) =>
      BackupSchedule(
        enabled: enabled ?? this.enabled,
        frequency: frequency ?? this.frequency,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'frequency': frequency.name,
        'hour': hour,
        'minute': minute,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
      };

  factory BackupSchedule.fromJson(Map<String, dynamic> json) => BackupSchedule(
        enabled: json['enabled'] as bool? ?? true,
        frequency: BackupFrequency.fromName(json['frequency'] as String?),
        hour: (json['hour'] as num?)?.toInt().clamp(0, 23) ?? 2,
        minute: (json['minute'] as num?)?.toInt().clamp(0, 59) ?? 0,
        lastBackupAt: DateTime.tryParse(json['lastBackupAt'] as String? ?? ''),
      );
}
