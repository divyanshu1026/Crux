import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/data/supabase/plan_repository.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/program_diff.dart';
import 'schedule_assistant.dart';
import 'schedule_preview_sheet.dart';

// ---------------------------------------------------------------------------
// Conversation state
// ---------------------------------------------------------------------------

/// A change Coach wants to make. It has not happened yet — the user applies it
/// from the card in the thread, after reviewing it if they want to.
class PlanProposal {
  const PlanProposal({
    required this.before,
    required this.after,
    required this.note,
    required this.request,
    this.concern,
  });

  final Program before;
  final Program after;
  final String note;
  final String request;

  /// Coach's professional objection, when it thinks this is a bad idea. It
  /// never blocks the change — see [showSchedulePreviewSheet].
  final String? concern;
}

/// How the user resolved a card attached to a message.
enum TurnOutcome { applied, discarded, undone }

/// One turn in the schedule conversation.
class ScheduleChatMessage {
  const ScheduleChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.proposal,
    this.undoTo,
    this.outcome,
    this.offerFullCoach = false,
  });

  final String id;
  final String text;
  final bool isUser;

  /// Non-null while Coach is waiting for a yes/no on a rewrite.
  final PlanProposal? proposal;

  /// The program as it was immediately before this turn changed it. Present on
  /// anything that already took effect, so every applied change has a way back
  /// — the fast offline edits apply without a preview, and a coach who can't
  /// undo is a coach you hesitate to talk to.
  final Program? undoTo;

  /// Set once the card has been acted on.
  final TurnOutcome? outcome;

  /// Coach couldn't be reached — offer the full chat instead of a dead end.
  final bool offerFullCoach;

  ScheduleChatMessage copyWith({String? text, TurnOutcome? outcome}) =>
      ScheduleChatMessage(
        id: id,
        text: text ?? this.text,
        isUser: isUser,
        proposal: proposal,
        undoTo: undoTo,
        outcome: outcome ?? this.outcome,
        offerFullCoach: offerFullCoach,
      );
}

/// Replies to chatter without spending an AI call.
///
/// "hi", "thanks", "ok" are not schedule edits, and sending them to the plan
/// builder costs a real request against the user's daily cap to be told
/// nothing. Anything longer or more specific than this list goes to Coach.
/// Returns null when the message deserves the real thing.
String? scheduleSmallTalkReply(String input) {
  final t = input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
  if (t.isEmpty) return null;
  if (t.split(RegExp(r'\s+')).length > 4) return null;

  const greetings = {
    'hi', 'hii', 'hiii', 'hello', 'hey', 'heya', 'yo', 'sup', 'hola',
    'namaste', 'good morning', 'good afternoon', 'good evening', 'gm',
  };
  const thanks = {
    'thanks', 'thank you', 'thanks a lot', 'thank u', 'thx', 'ty',
    'thanks coach', 'thank you coach', 'perfect thanks',
  };
  const acks = {
    'ok', 'okay', 'okk', 'k', 'cool', 'nice', 'great', 'awesome', 'perfect',
    'got it', 'sounds good', 'alright', 'sure', 'done', 'yes', 'yeah', 'yep',
    'no', 'nope',
  };
  const byes = {'bye', 'goodbye', 'see you', 'gn', 'good night', 'cya'};
  const help = {
    'help', 'help me', 'what can you do', 'who are you', 'what do you do',
    'options', 'what can i ask',
  };

  if (greetings.contains(t)) {
    return 'Hey! What do you want to change about your week? Try "move legs to '
        'Saturday", "make Wednesday a rest day", or "more glute work".';
  }
  if (thanks.contains(t)) {
    return "Anytime. Anything else about your week, I'm right here.";
  }
  if (acks.contains(t)) {
    return 'Got it. Tell me the change whenever you\'re ready.';
  }
  if (byes.contains(t)) {
    return 'See you at the next session. Your schedule is saved.';
  }
  if (help.contains(t)) {
    return 'I edit your training week. I can move a workout to another day, '
        'swap two days, make a day a rest day, change how many days you train, '
        'or rebuild the plan around a goal ("more glute work") or a problem '
        '("my shoulder hurts", "I only have dumbbells").';
  }
  return null;
}

/// The schedule conversation. In memory for the session: it's a working
/// conversation about one job, not a history worth keeping — the changes
/// themselves are persisted in the program.
class ScheduleChatNotifier extends Notifier<List<ScheduleChatMessage>> {
  static const _greetingId = 'sched_greeting';

  static const _greeting = ScheduleChatMessage(
    id: _greetingId,
    text: "Tell me what you want different about your week — move a day, swap "
        "two, take a rest day, train fewer days, or something bigger like more "
        "glute work or training around a sore shoulder. Nothing changes until "
        "you say so.",
    isUser: false,
  );

  @override
  List<ScheduleChatMessage> build() => const [_greeting];

  /// Bumped on every send and every stop. A reply is only used while the
  /// generation it belongs to is still current.
  int _generation = 0;

  void _add(ScheduleChatMessage msg) => state = [...state, msg];

  void _replace(ScheduleChatMessage msg) => state = [
        for (final m in state) m.id == msg.id ? msg : m,
      ];

  ScheduleChatMessage _coach(
    String text, {
    PlanProposal? proposal,
    Program? undoTo,
    bool offerFullCoach = false,
  }) =>
      ScheduleChatMessage(
        id: 'sched_${DateTime.now().microsecondsSinceEpoch}_coach',
        text: text,
        isUser: false,
        proposal: proposal,
        undoTo: undoTo,
        offerFullCoach: offerFullCoach,
      );

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (ref.read(scheduleChatThinkingProvider)) return;

    _add(ScheduleChatMessage(
      id: 'sched_${DateTime.now().microsecondsSinceEpoch}_user',
      text: text,
      isUser: true,
    ));

    // Chatter is answered here, for free. Sending "hi" to the plan builder
    // spends a real request to be told nothing.
    final smallTalk = scheduleSmallTalkReply(text);
    if (smallTalk != null) {
      _add(_coach(smallTalk));
      return;
    }

    final program = ref.read(programProvider);
    if (program == null) {
      _add(_coach(
        "You don't have a program yet — finish onboarding and I'll build one, "
        'then we can shape the week however you like.',
      ));
      return;
    }

    // Fast path: recognised edits apply instantly, offline, at no cost. They
    // carry an Undo rather than a preview — asking someone to confirm "make
    // Wednesday a rest day" twice is friction, not safety.
    final intent = parseScheduleCommand(text, program);
    if (intent != null) {
      final note = applyScheduleIntent(ref, intent);
      _add(_coach(note, undoTo: program));
      CxHaptics.fire(CxHaptic.success);
      return;
    }

    // Everything else goes to Coach, which rewrites the plan properly —
    // "more glutes", "my shoulder hurts", "swap in machines only".
    final generation = ++_generation;
    bool cancelled() => _generation != generation;

    ref.read(scheduleChatThinkingProvider.notifier).set(true);
    try {
      final outcome =
          await ref.read(programProvider.notifier).applyAiScheduleEdit(
                text,
                ref.read(userProfileProvider),
                isCancelled: cancelled,
              );
      if (cancelled()) return;
      switch (outcome) {
        case PlanUpdated(:final note, :final concern, program: final proposed):
          _add(_coach(
            note,
            proposal: PlanProposal(
              before: program,
              after: proposed,
              note: note,
              concern: concern,
              request: text,
            ),
          ));
        case PlanNeedsInfo(:final question):
          _add(_coach(question));
      }
    } on PlanException catch (e) {
      if (cancelled() || e.code == 'cancelled') return;
      _add(_coach(
        e.isSilentFallback
            ? "I can't reach Coach right now. Quick edits — moves, swaps, rest "
                'days, changing how many days you train — still work offline.'
            : e.message,
        offerFullCoach: e.isSilentFallback,
      ));
    } finally {
      // Only the live request owns the flag: a late reply from a cancelled one
      // must not clear the indicator for whatever replaced it.
      if (!cancelled()) {
        ref.read(scheduleChatThinkingProvider.notifier).set(false);
      }
    }
  }

  /// Abandons the in-flight request. The server call can't be recalled — it
  /// will finish and still count against the daily cap — but its result is
  /// discarded, so an accidental send never rewrites the week.
  void stop() {
    if (!ref.read(scheduleChatThinkingProvider)) return;
    _generation++;
    ref.read(scheduleChatThinkingProvider.notifier).set(false);
    _add(_coach('Stopped. Your plan is unchanged.'));
  }

  /// Writes a proposal into the real program.
  void applyProposal(String messageId) {
    final msg = _find(messageId);
    final proposal = msg?.proposal;
    if (msg == null || proposal == null || msg.outcome != null) return;
    ref.read(programProvider.notifier).loadProgram(proposal.after);
    _replace(msg.copyWith(outcome: TurnOutcome.applied));
    _add(_coach(
      'Applied. Open any day on the schedule to fine-tune it.',
      undoTo: proposal.before,
    ));
    CxHaptics.fire(CxHaptic.success);
  }

  void discardProposal(String messageId) {
    final msg = _find(messageId);
    if (msg == null || msg.proposal == null || msg.outcome != null) return;
    _replace(msg.copyWith(outcome: TurnOutcome.discarded));
    _add(_coach('Kept your current plan. Tell me what to try instead.'));
  }

  /// Puts back the program as it was before [messageId]'s change.
  void undo(String messageId) {
    final msg = _find(messageId);
    final before = msg?.undoTo;
    if (msg == null || before == null || msg.outcome != null) return;
    ref.read(programProvider.notifier).loadProgram(before);
    _replace(msg.copyWith(outcome: TurnOutcome.undone));
    _add(_coach('Reverted — your week is back to how it was.'));
    CxHaptics.fire(CxHaptic.selection);
  }

  /// Starts over. Anything already applied stays applied; this only clears the
  /// transcript.
  void reset() {
    _generation++;
    ref.read(scheduleChatThinkingProvider.notifier).set(false);
    state = const [_greeting];
  }

  ScheduleChatMessage? _find(String id) {
    for (final m in state) {
      if (m.id == id) return m;
    }
    return null;
  }
}

final scheduleChatProvider =
    NotifierProvider<ScheduleChatNotifier, List<ScheduleChatMessage>>(
        ScheduleChatNotifier.new);

/// True while a plan rewrite is in flight.
class ScheduleChatThinkingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final scheduleChatThinkingProvider =
    NotifierProvider<ScheduleChatThinkingNotifier, bool>(
        ScheduleChatThinkingNotifier.new);

// ---------------------------------------------------------------------------
// The sheet
// ---------------------------------------------------------------------------

/// Questions worth suggesting. The first five are handled instantly offline;
/// the rest show that Coach takes real requests, not a command vocabulary.
const kScheduleChatSuggestions = [
  'Move legs to Saturday',
  'Make Wednesday a rest day',
  'Swap Monday and Friday',
  'I can only train 3 days',
  'Balance my week',
  'More glute work',
  'My shoulder hurts — swap the overhead pressing',
  'I only have dumbbells now',
  'Add a second leg day',
  'Make my sessions shorter',
];

/// Opens the schedule conversation: a chat with Coach that can rewrite the
/// week, with every change reviewable before it lands.
///
/// Opens at three-quarter height, can be dragged up to nearly full or down to
/// dismiss.
void showScheduleAssistantSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialRequest,
  String title = 'Change my schedule',
  bool allowFullCoachHandoff = true,
}) {
  CxHaptics.fire(CxHaptic.selection);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ScheduleChatSheet(
      initialRequest: initialRequest,
      title: title,
      allowFullCoachHandoff: allowFullCoachHandoff,
    ),
  );
}

class _ScheduleChatSheet extends ConsumerStatefulWidget {
  const _ScheduleChatSheet({
    this.initialRequest,
    this.title = 'Change my schedule',
    this.allowFullCoachHandoff = true,
  });

  /// Sent straight away when the user arrived by tapping a suggestion, so the
  /// sheet opens with the answer already coming rather than making them retype.
  final String? initialRequest;

  final String title;

  /// Whether the "ask the full coach" escape hatch may navigate away. False
  /// during onboarding, where leaving for the coach tab would strand the user
  /// mid-flow with a half-built plan.
  final bool allowFullCoachHandoff;

  @override
  ConsumerState<_ScheduleChatSheet> createState() => _ScheduleChatSheetState();
}

class _ScheduleChatSheetState extends ConsumerState<_ScheduleChatSheet> {
  final _input = TextEditingController();
  final _drag = DraggableScrollableController();

  /// The list's controller, handed to us by [DraggableScrollableSheet] so the
  /// same gesture both scrolls the thread and resizes the sheet. Kept here only
  /// to scroll to the newest message.
  ScrollController? _list;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRequest;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(scheduleChatProvider.notifier).send(initial);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = _list;
      if (list == null || !list.hasClients) return;
      list.animateTo(
        list.position.maxScrollExtent,
        duration: CxDuration.slow,
        curve: CxCurves.standard,
      );
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    if (ref.read(scheduleChatThinkingProvider)) return;
    ref.read(scheduleChatProvider.notifier).send(text);
    _input.clear();
    setState(() {});
    _scrollToBottom();
  }

  /// Typing needs the room the thread was using, so give the sheet its full
  /// height while the keyboard is up.
  void _onInputFocus(bool hasFocus) {
    if (!hasFocus || !_drag.isAttached) return;
    _drag.animateTo(0.95,
        duration: CxDuration.base, curve: CxCurves.standard);
  }

  void _sendToFullCoach(String text) {
    Navigator.pop(context);
    ref.read(coachChatProvider.notifier).sendMessage(
          'About my weekly schedule: $text',
          ref: ref,
        );
    context.go(Routes.coach);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(scheduleChatProvider);
    final thinking = ref.watch(scheduleChatThinkingProvider);

    // New turns should be visible without scrolling for them.
    ref.listen(scheduleChatProvider, (_, _) => _scrollToBottom());
    ref.listen(scheduleChatThinkingProvider, (_, _) => _scrollToBottom());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        controller: _drag,
        expand: false,
        snap: true,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        snapSizes: const [0.45, 0.75, 0.95],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) {
          _list = scrollController;
          return _GlassShell(
            child: Column(
              children: [
                _header(messages.length > 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        CxSpace.screen, 0, CxSpace.screen, CxSpace.md),
                    itemCount: messages.length + (thinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _ThinkingRow();
                      }
                      final msg = messages[index];
                      return _MessageRow(
                        message: msg,
                        // The opening turn carries the full suggestion list;
                        // after that they live above the input.
                        showSuggestions:
                            index == 0 && messages.length == 1 && !thinking,
                        onSuggestion: _send,
                        onApply: () => ref
                            .read(scheduleChatProvider.notifier)
                            .applyProposal(msg.id),
                        onDiscard: () => ref
                            .read(scheduleChatProvider.notifier)
                            .discardProposal(msg.id),
                        onUndo: () =>
                            ref.read(scheduleChatProvider.notifier).undo(msg.id),
                        onReview: () => _review(msg),
                        onAskFullCoach: widget.allowFullCoachHandoff
                            ? () => _sendToFullCoach(msg.text)
                            : null,
                      );
                    },
                  ),
                ),
                _composer(thinking),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _review(ScheduleChatMessage msg) async {
    final proposal = msg.proposal;
    if (proposal == null) return;
    final accepted = await showSchedulePreviewSheet(
      context,
      before: proposal.before,
      after: proposal.after,
      note: proposal.note,
      concern: proposal.concern,
      request: proposal.request,
    );
    if (!mounted || !accepted) return;
    ref.read(scheduleChatProvider.notifier).applyProposal(msg.id);
  }

  Widget _header(bool canReset) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CxSpace.screen, CxSpace.md, CxSpace.sm, CxSpace.md),
      child: Row(
        children: [
          const YorhartWidget(expression: 'coaching', size: 36),
          const SizedBox(width: CxSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                Text('You review every change before it happens.',
                    style: CxType.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          if (canReset)
            IconButton(
              icon: Icon(Icons.restart_alt_rounded, color: c.textTertiary),
              tooltip: 'Start over',
              onPressed: () {
                ref.read(scheduleChatProvider.notifier).reset();
                CxHaptics.fire(CxHaptic.selection);
              },
            ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.textTertiary),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _composer(bool thinking) {
    final c = context.cx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          CxSpace.screen, CxSpace.sm, CxSpace.screen, CxSpace.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kScheduleChatSuggestions.length,
              itemBuilder: (context, index) {
                final text = kScheduleChatSuggestions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: CxSpace.sm),
                  // Centered in the strip's fixed height; width stays
                  // intrinsic because the list scrolls horizontally.
                  child: Center(
                    child: _SuggestionChip(
                      label: text,
                      onTap: thinking ? null : () => _send(text),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: CxSpace.sm),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: _onInputFocus,
                  child: CxTextField(
                    controller: _input,
                    hint: 'e.g. move push day to Sunday',
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _send,
                  ),
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              Semantics(
                button: true,
                label: thinking ? 'Stop Coach' : 'Send request',
                child: Material(
                  color: thinking ? c.surfaceHigh : c.ember,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: thinking
                        ? () => ref.read(scheduleChatProvider.notifier).stop()
                        : (_input.text.trim().isEmpty
                            ? null
                            : () => _send(_input.text)),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(
                        thinking ? Icons.stop_rounded : Icons.send_rounded,
                        color: thinking ? c.textPrimary : c.onEmber,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The frosted panel the sheet lives in — the same glass as
/// [CxGlassBottomSheet], but sized by its parent so the thread can scroll
/// inside it.
class _GlassShell extends StatelessWidget {
  const _GlassShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? CxColors.darkSurface.withValues(alpha: 0.88)
        : CxColors.lightSurface.withValues(alpha: 0.92);
    final borderColor = isDark
        ? CxColors.darkBorder.withValues(alpha: 0.4)
        : CxColors.lightBorder.withValues(alpha: 0.5);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(CxRadii.xl),
        topRight: Radius.circular(CxRadii.xl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 1.5),
              left: BorderSide(color: borderColor, width: 0.5),
              right: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: CxSpace.md),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread pieces
// ---------------------------------------------------------------------------

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.showSuggestions,
    required this.onSuggestion,
    required this.onApply,
    required this.onDiscard,
    required this.onUndo,
    required this.onReview,
    required this.onAskFullCoach,
  });

  final ScheduleChatMessage message;
  final bool showSuggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onApply;
  final VoidCallback onDiscard;
  final VoidCallback onUndo;
  final VoidCallback onReview;

  /// Null where handing off to the coach tab isn't allowed (onboarding).
  final VoidCallback? onAskFullCoach;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isUser = message.isUser;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                margin: const EdgeInsets.only(
                    bottom: CxSpace.md, right: CxSpace.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border, width: 1.2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: c.surfaceHigh,
                  child: const YorhartWidget(
                    expression: 'coaching',
                    size: 24,
                    animate: false,
                  ),
                ),
              ),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: CxSpace.md),
                padding: const EdgeInsets.all(CxSpace.lg),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                decoration: BoxDecoration(
                  color: isUser ? c.ember : c.surfaceHigh,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 16),
                  ),
                  border: isUser ? null : Border.all(color: c.border),
                ),
                child: Text(
                  message.text,
                  style: CxType.bodySmall
                      .copyWith(color: isUser ? c.onEmber : c.textPrimary),
                ),
              ),
            ),
          ],
        ),

        // Suggested requests, shown while the conversation is empty.
        if (showSuggestions) ...[
          Padding(
            padding: const EdgeInsets.only(
                left: 40, bottom: CxSpace.md, right: CxSpace.sm),
            child: Wrap(
              spacing: CxSpace.sm,
              runSpacing: CxSpace.sm,
              children: [
                // A sample, not the catalogue — the full list is always one
                // swipe away in the strip above the input.
                for (final s in kScheduleChatSuggestions.take(6))
                  _SuggestionChip(label: s, onTap: () => onSuggestion(s)),
              ],
            ),
          ),
        ],

        // A rewrite waiting on a decision.
        if (message.proposal != null)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: CxSpace.lg),
            child: _ProposalCard(
              proposal: message.proposal!,
              outcome: message.outcome,
              onApply: onApply,
              onReview: onReview,
              onDiscard: onDiscard,
            ),
          ),

        // Something that already happened, and the way back.
        if (message.proposal == null && message.undoTo != null)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: CxSpace.lg),
            child: _UndoRow(outcome: message.outcome, onUndo: onUndo),
          ),

        if (message.offerFullCoach && onAskFullCoach != null)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: CxSpace.lg),
            child: CxButton(
              label: 'Ask the full coach',
              variant: CxButtonVariant.secondary,
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: onAskFullCoach,
            ),
          ),
      ],
    );
  }
}

/// What would change, why, and the two buttons that decide it.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.outcome,
    required this.onApply,
    required this.onReview,
    required this.onDiscard,
  });

  final PlanProposal proposal;
  final TurnOutcome? outcome;
  final VoidCallback onApply;
  final VoidCallback onReview;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final diff = ProgramDiff.between(proposal.before, proposal.after);
    final concern = proposal.concern;
    final hasConcern = concern != null && concern.trim().isNotEmpty;

    if (outcome == TurnOutcome.applied || outcome == TurnOutcome.discarded) {
      final applied = outcome == TurnOutcome.applied;
      return Row(
        children: [
          Icon(applied ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16, color: applied ? c.success : c.textTertiary),
          const SizedBox(width: CxSpace.sm),
          Text(
            applied ? 'Applied to your plan' : 'Discarded',
            style: CxType.caption
                .copyWith(color: applied ? c.success : c.textTertiary),
          ),
        ],
      );
    }

    if (diff.isEmpty) {
      // The model answered without actually changing anything. Applying it
      // would be a no-op dressed up as a change.
      return Container(
        padding: const EdgeInsets.all(CxSpace.md),
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: CxRadii.brMd,
          border: Border.all(color: c.border),
        ),
        child: Text(
          "That didn't change anything in your plan. Try being more specific "
          'about what you want different.',
          style: CxType.caption.copyWith(color: c.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(CxSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: CxRadii.brLg,
        border: Border.all(color: c.ember.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 16, color: c.ember),
              const SizedBox(width: CxSpace.sm),
              Text('Proposed change',
                  style: CxType.label.copyWith(color: c.ember)),
            ],
          ),
          const SizedBox(height: CxSpace.md),
          for (final change in diff.changes.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: CxSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 5, color: c.textTertiary),
                  const SizedBox(width: CxSpace.sm),
                  Expanded(
                    child: Text(change.text,
                        style:
                            CxType.caption.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
          if (diff.changes.length > 3)
            Text('+${diff.changes.length - 3} more',
                style: CxType.caption.copyWith(color: c.textTertiary)),
          if (hasConcern) ...[
            const SizedBox(height: CxSpace.sm),
            Container(
              padding: const EdgeInsets.all(CxSpace.md),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: CxRadii.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.warning),
                  const SizedBox(width: CxSpace.sm),
                  Expanded(
                    child: Text(concern,
                        style:
                            CxType.caption.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: CxSpace.md),
          Row(
            children: [
              Expanded(
                child: CxButton(
                  label: 'Apply change',
                  expand: true,
                  haptic: CxHaptic.success,
                  onPressed: onApply,
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              Expanded(
                child: CxButton(
                  label: 'Review',
                  variant: CxButtonVariant.secondary,
                  expand: true,
                  onPressed: onReview,
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onDiscard,
              child: Text('Keep my current plan',
                  style: CxType.caption.copyWith(color: c.textTertiary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UndoRow extends StatelessWidget {
  const _UndoRow({required this.outcome, required this.onUndo});

  final TurnOutcome? outcome;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    if (outcome == TurnOutcome.undone) {
      return Row(
        children: [
          Icon(Icons.undo_rounded, size: 14, color: c.textTertiary),
          const SizedBox(width: CxSpace.sm),
          Text('Undone',
              style: CxType.caption.copyWith(color: c.textTertiary)),
        ],
      );
    }
    return CxButton(
      label: 'Undo',
      variant: CxButtonVariant.secondary,
      icon: Icons.undo_rounded,
      onPressed: onUndo,
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: CxSpace.md, vertical: CxSpace.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: CxRadii.brPill,
          border: Border.all(color: c.border),
        ),
        // No Center here: inside a Wrap the child gets a loose full-width
        // constraint, and Center would expand into it — turning every chip
        // into a full-width bar.
        child: Text(
          label,
          style: CxType.caption.copyWith(
            color: enabled ? c.textSecondary : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Pulsing dots and a status line that advances through the work while Coach
/// rewrites the plan. A rewrite takes several seconds; a bubble that says what
/// is happening is the difference between waiting and giving up.
class _ThinkingRow extends StatefulWidget {
  const _ThinkingRow();

  @override
  State<_ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<_ThinkingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  Timer? _stageTimer;
  int _step = 0;

  /// The work, in the order it actually happens.
  static const _stages = [
    'Reading your current week',
    'Checking which days you train',
    'Counting your weekly sets per muscle',
    'Balancing the muscle groups',
    'Choosing the movements',
    'Fitting them to your equipment',
    'Writing the new plan',
    'Checking the week adds up',
  ];

  /// A rewrite can run past the stage list on a slow day. Rather than freezing
  /// on "almost there" — which starts to read like a hang — keep saying
  /// something true.
  static const _patience = [
    'Still working — a full rewrite takes a moment',
    'Double-checking the volume per muscle',
    'Nearly there',
  ];

  String get _label => _step < _stages.length
      ? _stages[_step]
      : _patience[(_step - _stages.length) % _patience.length];

  @override
  void initState() {
    super.initState();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted) return;
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: CxSpace.md, right: CxSpace.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 1.2),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: c.surfaceHigh,
            child: const YorhartWidget(
                expression: 'coaching', size: 24, animate: true),
          ),
        ),
        Flexible(
          child: Container(
          margin: const EdgeInsets.only(bottom: CxSpace.md),
          padding: const EdgeInsets.symmetric(
              horizontal: CxSpace.lg, vertical: CxSpace.md),
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_pulse.value + i * 0.25) % 1.0;
                    final opacity = 0.25 + 0.75 * (1 - (t - 0.5).abs() * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity.clamp(0.25, 1.0),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.ultraviolet,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Flexible(
                child: AnimatedSwitcher(
                  duration: CxDuration.base,
                  child: Text(
                    _label,
                    key: ValueKey(_step),
                    style: CxType.caption.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ],
    );
  }
}
