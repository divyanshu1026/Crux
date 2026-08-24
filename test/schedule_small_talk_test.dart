import 'package:flutter_test/flutter_test.dart';
import 'package:crux/features/schedule/presentation/schedule_chat_sheet.dart';

/// The schedule chat answers chatter locally. Every message that reaches the
/// plan builder costs a real request against the user's daily cap, and "hi"
/// buys them nothing.
void main() {
  group('answered locally — no AI spend', () {
    const local = [
      'hi',
      'Hey!',
      'hello',
      'thanks',
      'thank you coach',
      'ok',
      'cool',
      'bye',
      'good night',
      'help',
      'what can you do',
    ];
    for (final text in local) {
      test('"$text"', () {
        expect(scheduleSmallTalkReply(text), isNotNull);
      });
    }
  });

  group('sent to Coach', () {
    const real = [
      'move legs to saturday',
      'more glute work',
      'my shoulder hurts, swap the overhead pressing',
      'i want to focus on my legs',
      'I only have dumbbells now',
      '',
    ];
    for (final text in real) {
      test('"$text"', () {
        expect(scheduleSmallTalkReply(text), isNull);
      });
    }
  });
}
