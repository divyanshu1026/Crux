import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/local_store.dart';

/// App theme mode. Defaults to system ("Night Gym" dark is primary). Persisted
/// locally so the user's choice survives restarts.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) => store.setString(LocalStore.kThemeMode, next.name));
    final saved = store.getString(LocalStore.kThemeMode);
    return ThemeMode.values
        .firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) => state = mode;

  /// Picks a theme explicitly. Callers pass what the user asked for, not a
  /// flip of an internal state.
  ///
  /// The switch used to call a [toggle] that guessed from
  /// `platformBrightness` whenever the mode was still `system`. When that
  /// guess disagreed with what was actually on screen — which it does any
  /// time the OS says one thing and the rendered theme says another — the
  /// first tap appeared to do nothing (it moved `system` → the mode already
  /// being displayed) and only the second tap changed anything. Setting the
  /// requested mode directly cannot desynchronise.
  void setDark(bool dark) => state = dark ? ThemeMode.dark : ThemeMode.light;
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
