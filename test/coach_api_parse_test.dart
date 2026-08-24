import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/data/coach/coach_api.dart';

/// The coach Edge Function replies `text/event-stream`, and for that content
/// type the Supabase client hands back a byte **stream**, not a String. The
/// client used to `jsonEncode` whatever it got, which throws on a stream — so
/// every cloud reply was silently swallowed and answered by the offline mock
/// instead. These tests pin the decoding.
void main() {
  final api = CoachApi();

  const sse = 'data: {"type":"delta","text":"Today "}\n\n'
      'data: {"type":"delta","text":"is Saturday."}\n\n'
      'data: {"type":"done"}\n\n';

  test('reads a byte stream (what invoke actually returns)', () async {
    final stream = Stream<List<int>>.fromIterable([
      utf8.encode(sse.substring(0, 20)),
      utf8.encode(sse.substring(20)),
    ]);
    expect(await api.debugDecode(stream), 'Today is Saturday.');
  });

  test('reads a plain string body', () async {
    expect(await api.debugDecode(sse), 'Today is Saturday.');
  });

  test('reads raw bytes', () async {
    expect(await api.debugDecode(utf8.encode(sse)), 'Today is Saturday.');
  });

  test('ignores keep-alives and non-JSON lines', () async {
    const noisy = ': keep-alive\n\n'
        'data: not json\n\n'
        'data: {"type":"delta","text":"ok"}\n\n';
    expect(await api.debugDecode(noisy), 'ok');
  });

  test('an empty stream is an error, not an empty message', () async {
    await expectLater(
      api.debugDecode('data: {"type":"done"}\n\n'),
      throwsA(isA<CoachException>()),
    );
  });

  test('a mid-stream provider failure is reported as upstream', () async {
    try {
      await api.debugDecode('data: {"type":"error"}\n\n');
      fail('expected a CoachException');
    } on CoachException catch (e) {
      expect(e.code, 'upstream_stream');
    }
  });
}
