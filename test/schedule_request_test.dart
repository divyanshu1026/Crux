import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/domain/schedule_request.dart';

void main() {
  group('looksLikeScheduleRequest — offers to change the plan', () {
    const yes = [
      'move legs to saturday',
      'swap monday and friday',
      'make wednesday a rest day',
      'I can only train 3 days a week',
      'can you add a second leg day',
      'more glute work please',
      'less cardio in my week',
      'my shoulder hurts, what should I do about pressing',
      'I only have dumbbells now',
      'no gym for two weeks',
      'rebuild my split around 4 days',
      'drop the deadlifts',
      'how do I move leg day to sunday?',
    ];

    for (final text in yes) {
      test('"$text"', () => expect(looksLikeScheduleRequest(text), isTrue));
    }
  });

  group('looksLikeScheduleRequest — stays quiet', () {
    const no = [
      '',
      'hi',
      'thanks coach',
      'explain my program',
      'why this weight?',
      'what does progressive overload mean',
      'how much protein should I eat',
      'build me a nutrition plan',
      'am I recovering well',
    ];

    for (final text in no) {
      test('"$text"', () => expect(looksLikeScheduleRequest(text), isFalse));
    }
  });
}
