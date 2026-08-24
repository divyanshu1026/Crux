import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../supabase/supabase_config.dart';

/// Thrown when the cloud coach can't answer. [code] lets the caller decide
/// whether to fall back to the offline reply ('not_configured' / 'auth') or to
/// surface the message to the user ('rate_limited' / 'upstream').
class CoachException implements Exception {
  CoachException(this.message, this.code);
  final String message;
  final String code;
}

/// Calls the `coach` Supabase Edge Function (Anthropic primary, Gemini
/// fallback). The function streams SSE; we accumulate the deltas into the full
/// reply since the current chat UI appends a whole message. Returns the text.
class CoachApi {
  /// How much of the conversation goes with each message. Enough that Coach
  /// remembers the last few weeks of a thread, capped so a long-running chat
  /// doesn't grow the request without limit.
  static const historyMessageLimit = 30;
  static const historyWindowDays = 45;

  /// [snapshot] is the user's training data as the device holds it (see
  /// [buildCoachSnapshot]) and [today] their local date. Both are sent because
  /// the server's own `coach_context()` can only see synced rows — which today
  /// means the profile and body logs, not the program or a single workout.
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    Map<String, dynamic>? today,
    Map<String, dynamic>? snapshot,
  }) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw CoachException('Coach cloud is not configured.', 'not_configured');
    }
    if (client.auth.currentSession == null) {
      throw CoachException('Sign in to chat with Coach.', 'auth');
    }

    try {
      final cutoff =
          DateTime.now().subtract(const Duration(days: historyWindowDays));
      final recent = history
          .where((m) => m.id != 'welcome' && m.timestamp.isAfter(cutoff))
          .toList();
      final windowed = recent.length > historyMessageLimit
          ? recent.sublist(recent.length - historyMessageLimit)
          : recent;

      final res = await client.functions.invoke('coach', body: {
        'message': message,
        if (today != null) 'today': today,
        if (snapshot != null) 'snapshot': snapshot,
        'history': windowed
            .map((m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                })
            .toList(),
      });
      return _parseSse(await _readBody(res.data));
    } on FunctionException catch (e) {
      final details = e.details;
      final code = (details is Map && details['code'] is String)
          ? details['code'] as String
          : 'upstream';
      final msg = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Coach is unavailable right now. Try again in a moment.';
      throw CoachException(msg, code);
    }
  }

  /// Test hook for the decode path — the bug this guards against was invisible
  /// from the outside, because the failure looked like a normal offline reply.
  @visibleForTesting
  Future<String> debugDecode(dynamic data) async =>
      _parseSse(await _readBody(data));

  /// Turns whatever `functions.invoke` handed back into the raw SSE text.
  ///
  /// The function replies `text/event-stream`, and for that content type the
  /// Supabase client hands back the **live byte stream**, not a String. The old
  /// code did `data is String ? data : jsonEncode(data)`, and `jsonEncode` of a
  /// stream throws — outside the `FunctionException` catch, so every single
  /// reply fell through to the offline mock coach. The cloud coach was never
  /// reaching the user, whatever the server did.
  Future<String> _readBody(dynamic data) async {
    if (data is String) return data;
    if (data is Stream<List<int>>) return utf8.decodeStream(data);
    if (data is List<int>) return utf8.decode(data);
    // A JSON body here means the function answered with an object rather than
    // a stream — keep it readable so _parseSse can report it honestly.
    return jsonEncode(data);
  }

  String _parseSse(String raw) {
    final buffer = StringBuffer();
    var failedMidStream = false;
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (!t.startsWith('data:')) continue;
      final payload = t.substring(5).trim();
      if (payload.isEmpty) continue;
      try {
        final evt = jsonDecode(payload) as Map<String, dynamic>;
        if (evt['type'] == 'delta' && evt['text'] is String) {
          buffer.write(evt['text']);
        } else if (evt['type'] == 'error') {
          failedMidStream = true;
        }
      } catch (_) {
        // ignore keep-alives / non-JSON lines
      }
    }
    final out = buffer.toString().trim();
    if (out.isEmpty) {
      // The provider dropped the stream. Falling back to the offline reply is
      // better than an error bubble the user can do nothing with.
      throw CoachException(
        'Coach returned an empty reply.',
        failedMidStream ? 'upstream_stream' : 'empty',
      );
    }
    return out;
  }
}

final coachApiProvider = Provider<CoachApi>((ref) => CoachApi());
