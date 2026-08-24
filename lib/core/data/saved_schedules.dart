import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'local_store.dart';

/// A schedule the user named and kept.
///
/// Exists so trying something is not destructive. Before this, asking Coach to
/// rebuild your week meant the plan you liked was simply gone — the only way
/// back was to remember what it looked like and rebuild it by hand.
class SavedSchedule {
  const SavedSchedule({
    required this.id,
    required this.name,
    required this.program,
    required this.savedAt,
  });

  final String id;
  final String name;
  final Program program;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'program': program.toJson(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedSchedule.fromJson(Map<String, dynamic> json) => SavedSchedule(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        program:
            Program.fromJson(Map<String, dynamic>.from(json['program'] as Map)),
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  /// "3 days · Upper/Lower Strength" — the line shown under the user's name.
  String get subtitle {
    final days = program.dayAssignments.length;
    return '$days ${days == 1 ? 'day' : 'days'} · ${program.name}';
  }
}

class SavedSchedulesNotifier extends Notifier<List<SavedSchedule>> {
  @override
  List<SavedSchedule> build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) {
      store.setJson(LocalStore.kSavedSchedules, {
        'items': next.map((s) => s.toJson()).toList(),
      });
    });
    final saved = store.getMap(LocalStore.kSavedSchedules);
    final items = (saved?['items'] as List?) ?? const [];
    return items
        .map((e) => SavedSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Saves [program] under [name]. Saving the same name twice overwrites,
  /// which is what people expect from "save" and avoids a list full of
  /// near-identical entries.
  void save(String name, Program program) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final entry = SavedSchedule(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      program: program,
      savedAt: DateTime.now(),
    );
    final rest = state.where(
        (s) => s.name.toLowerCase() != trimmed.toLowerCase());
    state = [entry, ...rest];
  }

  void remove(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final savedSchedulesProvider =
    NotifierProvider<SavedSchedulesNotifier, List<SavedSchedule>>(
        SavedSchedulesNotifier.new);
