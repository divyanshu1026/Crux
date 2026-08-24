/// What actually changed between two programs.
///
/// Computed from the two programs themselves rather than taken from the
/// model's description of its own work. A model will happily say "added an
/// extra biceps exercise" whether or not it did, and this screen exists
/// specifically so the user can trust what they're about to accept — so the
/// list of changes has to come from the data, not the narration.
///
/// The model's prose still has a job: explaining *why*. That lives alongside
/// this, clearly labelled as the coach talking.
library;

import '../../../core/models/models.dart';

enum ChangeKind { schedule, session, exercise, volume }

class ProgramChange {
  const ProgramChange(this.kind, this.text);
  final ChangeKind kind;
  final String text;
}

class ProgramDiff {
  const ProgramDiff(this.changes);
  final List<ProgramChange> changes;

  bool get isEmpty => changes.isEmpty;
  bool get isNotEmpty => changes.isNotEmpty;

  /// How many weekdays are trained, before and after — the single number
  /// people care about most, and the one the old bug silently wrecked.
  static int trainingDayCount(Program p) => p.dayAssignments.length;

  static ProgramDiff between(Program before, Program after) {
    final changes = <ProgramChange>[];

    // --- Weekly layout -----------------------------------------------------
    final beforeDays = trainingDayCount(before);
    final afterDays = trainingDayCount(after);
    if (beforeDays != afterDays) {
      changes.add(ProgramChange(
        ChangeKind.schedule,
        'Training days: $beforeDays → $afterDays per week',
      ));
    } else {
      final movedFrom = <String>[];
      for (final wd in Program.weekdays) {
        final b = before.dayAssignments[wd];
        final a = after.dayAssignments[wd];
        if (b != a) movedFrom.add(wd);
      }
      if (movedFrom.isNotEmpty) {
        changes.add(ProgramChange(
          ChangeKind.schedule,
          'Reshuffled which workout runs on ${_list(movedFrom)}',
        ));
      }
    }

    // --- Sessions added / removed -----------------------------------------
    final beforeByName = {for (final d in before.days) d.name: d};
    final afterByName = {for (final d in after.days) d.name: d};

    final added = afterByName.keys.where((n) => !beforeByName.containsKey(n));
    final removed = beforeByName.keys.where((n) => !afterByName.containsKey(n));
    for (final n in added) {
      changes.add(ProgramChange(ChangeKind.session, 'New session: $n'));
    }
    for (final n in removed) {
      changes.add(ProgramChange(ChangeKind.session, 'Removed session: $n'));
    }

    // --- Exercise-level changes within sessions that survived --------------
    for (final name in afterByName.keys) {
      final b = beforeByName[name];
      final a = afterByName[name]!;
      if (b == null) continue;

      final bEx = {for (final e in b.exercises) e.name: e};
      final aEx = {for (final e in a.exercises) e.name: e};

      final gained = aEx.keys.where((e) => !bEx.containsKey(e)).toList();
      final lost = bEx.keys.where((e) => !aEx.containsKey(e)).toList();

      if (gained.isNotEmpty) {
        changes.add(ProgramChange(
          ChangeKind.exercise,
          '$name: added ${_list(gained)}',
        ));
      }
      if (lost.isNotEmpty) {
        changes.add(ProgramChange(
          ChangeKind.exercise,
          '$name: removed ${_list(lost)}',
        ));
      }

      // Set changes on movements present in both.
      for (final exName in aEx.keys) {
        final before2 = bEx[exName];
        final after2 = aEx[exName]!;
        if (before2 == null) continue;
        if (before2.targetSets != after2.targetSets) {
          changes.add(ProgramChange(
            ChangeKind.volume,
            '$name — $exName: ${before2.targetSets} → ${after2.targetSets} sets',
          ));
        }
      }
    }

    return ProgramDiff(changes);
  }

  static String _list(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }
}
