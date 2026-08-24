import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'supabase_config.dart';

/// Thrown when Coach can't produce a plan. [message] is always safe to show.
class PlanException implements Exception {
  PlanException(this.message, this.code);
  final String message;
  final String code;

  /// True when the app should quietly fall back to its built-in templates
  /// rather than telling the user anything — the AI is simply not available
  /// (no account, no network, not deployed, no credits, backend misconfigured).
  ///
  /// `no_ledger` is in here because it means the server refused to run the AI
  /// without a working rate-limit ledger. That is our problem to fix, and the
  /// user gets a curated plan meanwhile — telling them about it would be
  /// noise they can do nothing with.
  bool get isSilentFallback =>
      code == 'offline' ||
      code == 'auth' ||
      code == 'not_deployed' ||
      code == 'no_ledger';
}

/// What Coach came back with.
///
/// Deliberately two outcomes rather than one: a coach who cannot tell what you
/// meant should ask, not guess. Before this existed the only legal reply was a
/// complete program, so a half-finished request like "I want to focus" came
/// back as the unchanged plan plus a note inventing a reason nothing changed.
sealed class PlanOutcome {
  const PlanOutcome();
}

/// Coach rewrote the plan. [note] is the one-line summary of what changed.
///
/// This is a *proposal*, not something already applied — the caller shows it
/// for confirmation first. See `SchedulePreviewSheet`.
class PlanUpdated extends PlanOutcome {
  const PlanUpdated({
    required this.program,
    required this.note,
    this.concern,
  });
  final Program program;
  final String note;

  /// Coach's professional objection, when it thinks the request is a bad idea
  /// for this person. Non-null does not mean the change was refused — it was
  /// still made. A coach who only ever agrees is not worth having, and one who
  /// refuses to do what you asked is worse.
  final String? concern;
}

/// Coach needs one more thing before it can act. [question] is safe to show
/// verbatim, and the user's plan has NOT been touched.
class PlanNeedsInfo extends PlanOutcome {
  const PlanNeedsInfo(this.question);
  final String question;
}

/// Calls the `plan` Edge Function, which builds and edits programs with an LLM
/// and validates the result server-side before it gets here.
///
/// Every method throws [PlanException] rather than returning null, so callers
/// have to decide explicitly between falling back and surfacing the problem.
class PlanRepository {
  /// How long to wait for a plan before giving up. Generous — a full program
  /// rewrite legitimately takes tens of seconds — but finite.
  static const planTimeout = Duration(seconds: 75);

  /// Builds a program from scratch for [profile].
  Future<PlanOutcome> generate(UserProfile profile) =>
      _invoke({'action': 'generate', 'profile': _profileJson(profile)});

  /// Applies a natural-language [instruction] to [program].
  Future<PlanOutcome> edit({
    required UserProfile profile,
    required Program program,
    required String instruction,
  }) =>
      _invoke({
        'action': 'edit',
        'profile': _profileJson(profile),
        'program': program.toJson(),
        'instruction': instruction,
      });

  /// Only the fields that shape programming — deliberately not the whole
  /// profile. XP, streak and level tell a coach nothing, and every extra field
  /// is more of the user's data leaving the device.
  Map<String, dynamic> _profileJson(UserProfile p) => {
        'sex': p.sex,
        'age': p.age,
        'heightCm': p.height,
        'weightKg': p.weight,
        'goal': p.goal,
        'experience': p.experience,
        'trainingDays': p.daysPerWeek,
        'equipment': p.equipment,
        'injuries': p.injuries,
        'units': p.units,
      };

  Future<PlanOutcome> _invoke(Map<String, dynamic> body) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw PlanException('Coach needs a connection to build plans.', 'offline');
    }
    if (client.auth.currentSession == null) {
      throw PlanException('Sign in to let Coach build your plan.', 'auth');
    }

    try {
      // Rewriting a five-day program is a big generation, and a slow provider
      // day can stretch it past a minute. Without a ceiling the caller's
      // spinner runs forever with no way out, which is worse than saying the
      // plan builder is being slow.
      final res = await client.functions
          .invoke('plan', body: body)
          .timeout(planTimeout);
      final data = res.data;
      if (data is! Map) {
        throw PlanException('Coach sent back something unexpected.', 'bad_plan');
      }
      final clarify = (data['clarify'] as String?)?.trim();
      if (clarify != null && clarify.isNotEmpty) {
        return PlanNeedsInfo(clarify);
      }
      final programJson = data['program'];
      if (programJson is! Map) {
        throw PlanException('Coach sent back something unexpected.', 'bad_plan');
      }
      final concern = (data['concern'] as String?)?.trim();
      return PlanUpdated(
        program: Program.fromJson(Map<String, dynamic>.from(programJson)),
        note: (data['note'] as String?)?.trim().isNotEmpty == true
            ? data['note'] as String
            : 'Updated your plan.',
        concern: (concern == null || concern.isEmpty) ? null : concern,
      );
    } on FunctionException catch (e) {
      debugPrint('plan failed: status=${e.status} details=${e.details}');
      if (e.status == 404) {
        // Function not deployed — an operator problem, never the user's.
        throw PlanException(
          'Coach plan building is not available yet.',
          'not_deployed',
        );
      }
      final details = e.details;
      final msg = (details is Map && details['error'] is String)
          ? details['error'] as String
          : "Coach couldn't build that right now. Please try again.";
      final code = (details is Map && details['code'] is String)
          ? details['code'] as String
          : 'failed';
      throw PlanException(msg, code);
    } on PlanException {
      rethrow;
    } on TimeoutException {
      throw PlanException(
        "Coach is taking longer than usual to rebuild your plan. Try again in "
        'a moment — your current plan is untouched.',
        'timeout',
      );
    } catch (e) {
      debugPrint('plan failed: $e');
      throw PlanException(
        "Couldn't reach Coach. Check your connection and try again.",
        'offline',
      );
    }
  }
}

final planRepositoryProvider = Provider<PlanRepository>((ref) => PlanRepository());
