import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Loud, repeating rest-complete cue (alarm-stream audio + strong vibration).
///
/// [SystemSound.alert] is often silent on Android when touch sounds are off,
/// so we play a bundled beep on the alarm audio stream and drive a gym-timer
/// vibration pattern until [stop] is called.
class RestAlertService {
  RestAlertService._();
  static final RestAlertService instance = RestAlertService._();

  AudioPlayer? _player;
  Timer? _hapticTimer;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _startAudio();
    await _pulseHaptics();
    // Keep pulsing until stopped — pattern matches the beep cadence (~0.8s).
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      unawaited(_pulseHaptics());
    });
  }

  Future<void> stop() async {
    _running = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Vibration.cancel();
      }
    } catch (_) {}
  }

  Future<void> _startAudio() async {
    try {
      final player = AudioPlayer();
      _player = player;

      // Use alarm usage so the beep follows alarm volume (not silent media).
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1.0);
      await player.play(AssetSource('sounds/rest_complete.wav'));
    } catch (e) {
      debugPrint('RestAlertService audio failed: $e');
    }
  }

  /// Strong double-pulse: heavy → gap → heavy → longer buzz.
  Future<void> _pulseHaptics() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          final hasAmp = await Vibration.hasAmplitudeControl();
          if (hasAmp) {
            // pattern: wait, buzz, pause, buzz, pause, long buzz (ms)
            await Vibration.vibrate(
              pattern: [0, 120, 80, 120, 80, 280],
              intensities: [0, 255, 0, 255, 0, 220],
            );
          } else {
            await Vibration.vibrate(pattern: [0, 140, 90, 140, 90, 300]);
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback when the vibration plugin isn't available.
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.vibrate();
  }
}
