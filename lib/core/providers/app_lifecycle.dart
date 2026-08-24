import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is actually on screen right now.
///
/// This exists because "is a Dart timer still running?" and "is the user
/// looking at the app?" are different questions, and the rest timer used to
/// conflate them. Android keeps a backgrounded Flutter isolate alive for a
/// while, so a `Timer.periodic` can happily fire with the screen off — code
/// that treats its own execution as proof of being foregrounded will cancel
/// the very OS notification the user is relying on.
///
/// Read [appIsForegroundProvider] before doing anything that only makes sense
/// with a visible frame: playing an in-app sound, starting an animation, or
/// deciding that a system notification is redundant.
class AppLifecycleNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    // `lifecycleState` is null before the first frame; treat that as
    // foreground, since the app is starting up in front of the user.
    return binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `resumed` is the only state where a frame is actually being presented.
    // `inactive` covers the app switcher and transient overlays, `paused` and
    // `hidden` mean backgrounded, `detached` means no view at all.
    // The parameter shadows the Notifier's own `state`, so assign through
    // `super` to reach the setter rather than the argument.
    super.state = state == AppLifecycleState.resumed;
  }
}

final appIsForegroundProvider =
    NotifierProvider<AppLifecycleNotifier, bool>(AppLifecycleNotifier.new);
