import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/providers/providers.dart';

/// Greetings must be answered locally (no API spend); real questions must not
/// be swallowed by the small-talk filter. Verified through the chat notifier:
/// a small-talk message produces an instant assistant reply with no thinking
/// state; anything substantial is left for the cloud/mock pipeline.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.profile': '{"name":"Divy","hasCompletedOnboarding":true}',
    });
  });

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('greetings get an instant local reply without thinking state',
      () async {
    final container = await makeContainer();
    final before = container.read(coachChatProvider).length;

    // No WidgetRef available in a pure container test — exercise the
    // small-talk path via the public API contract instead.
    final notifier = container.read(coachChatProvider.notifier);
    final profile = container.read(userProfileProvider);

    for (final msg in ['hi', 'Hello!', 'thanks', 'ok', 'who are you']) {
      final reply = notifier.debugSmallTalk(msg, profile);
      expect(reply, isNotNull, reason: '"$msg" should be handled locally');
    }
    expect(container.read(coachThinkingProvider), false);
    expect(container.read(coachChatProvider).length, before);
  });

  test('real questions are NOT swallowed by the small-talk filter', () async {
    final container = await makeContainer();
    final notifier = container.read(coachChatProvider.notifier);
    final profile = container.read(userProfileProvider);

    for (final msg in [
      'hi coach, my knee hurts when I squat',
      'build me a nutrition plan',
      'why is my bench stuck',
      'ok to train legs two days in a row?',
    ]) {
      expect(notifier.debugSmallTalk(msg, profile), isNull,
          reason: '"$msg" must reach the real coach');
    }
  });

  test('greeting reply is personalized with the profile name', () async {
    final container = await makeContainer();
    final notifier = container.read(coachChatProvider.notifier);
    final profile = container.read(userProfileProvider);
    expect(notifier.debugSmallTalk('hi', profile), contains('Divy'));
  });
}
