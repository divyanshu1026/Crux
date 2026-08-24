import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/data/backup_schedule.dart';

void main() {
  group('when a backup is due', () {
    test('a first-ever backup runs immediately', () {
      const s = BackupSchedule();
      expect(s.isDue(DateTime(2026, 8, 3, 14, 0)), isTrue,
          reason: 'waiting a week to protect data they already have is '
              'backwards');
    });

    test('nothing is due while it is switched off', () {
      const s = BackupSchedule(enabled: false);
      expect(s.isDue(DateTime(2026, 8, 3)), isFalse);
    });

    test('weekly waits a week, then fires after the chosen hour', () {
      final s = BackupSchedule(
        lastBackupAt: DateTime(2026, 8, 1, 2, 0),
      );
      expect(s.isDue(DateTime(2026, 8, 5)), isFalse, reason: 'only 4 days');
      expect(s.isDue(DateTime(2026, 8, 8, 1, 0)), isFalse,
          reason: '7 days have passed but it is 01:00, before the 02:00 slot');
      expect(s.isDue(DateTime(2026, 8, 8, 2, 30)), isTrue);
    });

    test('daily is due the next day', () {
      final s = BackupSchedule(
        frequency: BackupFrequency.daily,
        lastBackupAt: DateTime(2026, 8, 1, 2, 0),
      );
      expect(s.isDue(DateTime(2026, 8, 1, 23, 0)), isFalse);
      expect(s.isDue(DateTime(2026, 8, 2, 2, 1)), isTrue);
    });

    test('quarterly really does wait about three months', () {
      final s = BackupSchedule(
        frequency: BackupFrequency.quarterly,
        lastBackupAt: DateTime(2026, 1, 1, 2, 0),
      );
      expect(s.isDue(DateTime(2026, 3, 1)), isFalse);
      expect(s.isDue(DateTime(2026, 4, 2, 3, 0)), isTrue);
    });

    test('a custom hour is respected', () {
      final s = BackupSchedule(
        hour: 23,
        minute: 30,
        frequency: BackupFrequency.daily,
        lastBackupAt: DateTime(2026, 8, 1, 23, 30),
      );
      expect(s.isDue(DateTime(2026, 8, 2, 22, 0)), isFalse);
      expect(s.isDue(DateTime(2026, 8, 2, 23, 31)), isTrue);
    });

    test('changing the time cannot make a fresh backup instantly overdue', () {
      // Backed up at 02:00, then the user moves the slot to 01:00.
      final s = BackupSchedule(
        hour: 1,
        frequency: BackupFrequency.daily,
        lastBackupAt: DateTime(2026, 8, 1, 2, 0),
      );
      expect(s.isDue(DateTime(2026, 8, 1, 2, 5)), isFalse);
    });
  });

  group('round trip', () {
    test('survives json', () {
      final s = BackupSchedule(
        enabled: false,
        frequency: BackupFrequency.quarterly,
        hour: 5,
        minute: 45,
        lastBackupAt: DateTime(2026, 7, 2, 5, 45),
      );
      final back = BackupSchedule.fromJson(s.toJson());
      expect(back.enabled, isFalse);
      expect(back.frequency, BackupFrequency.quarterly);
      expect(back.hour, 5);
      expect(back.minute, 45);
      expect(back.lastBackupAt, s.lastBackupAt);
    });

    test('an unknown frequency falls back to weekly rather than throwing', () {
      final back = BackupSchedule.fromJson({'frequency': 'fortnightly'});
      expect(back.frequency, BackupFrequency.weekly);
    });

    test('defaults are weekly at 02:00, enabled', () {
      const s = BackupSchedule();
      expect(s.enabled, isTrue);
      expect(s.frequency, BackupFrequency.weekly);
      expect(s.timeLabel, '02:00');
    });
  });

  test('describeNext reads like a sentence', () {
    const fresh = BackupSchedule();
    expect(fresh.describeNext(DateTime(2026, 8, 3)),
        'Runs next time you open the app');

    const off = BackupSchedule(enabled: false);
    expect(off.describeNext(DateTime(2026, 8, 3)), 'Automatic backup is off');

    final due = BackupSchedule(lastBackupAt: DateTime(2026, 7, 1, 2, 0));
    expect(due.describeNext(DateTime(2026, 8, 3)), 'Due now');

    final soon = BackupSchedule(
      frequency: BackupFrequency.daily,
      lastBackupAt: DateTime(2026, 8, 3, 2, 0),
    );
    expect(soon.describeNext(DateTime(2026, 8, 3, 20, 0)), 'Next in 6h');
  });
}
