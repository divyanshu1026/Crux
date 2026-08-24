import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/placeholder_screen.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/data/supabase/plan_repository.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../features/schedule/presentation/schedule_preview_sheet.dart';
import '../../../l10n/app_localizations.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _starterChips = [
    "Explain my program",
    "Build me a nutrition plan",
    "Why this weight?",
    "Only 30 min today — what do I cut?",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollToBottom(animate: false);
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && mounted) {
      _scrollToBottom(animate: false);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: CxDuration.slow,
          curve: CxCurves.standard,
        );
      } else {
        _scrollController.jumpTo(target);
        // Secondary frame callback in case lazy list items expand maxScrollExtent
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  /// True while a plan rewrite triggered from the chat is in flight, so the
  /// offer button can't be fired twice.
  bool _applyingOffer = false;

  /// Bumped by [_stopApplyingOffer]. The request itself can't be recalled, but
  /// its result is discarded — nobody's week gets rewritten by a change they
  /// backed out of.
  int _applyGeneration = 0;

  /// Abandons an in-flight rewrite. A full program rebuild takes tens of
  /// seconds, and a spinner with no way out is a trap.
  void _stopApplyingOffer() {
    _applyGeneration++;
    CxHaptics.fire(CxHaptic.selection);
    setState(() => _applyingOffer = false);
    ref.read(scheduleOfferProvider.notifier).clear();
    ref
        .read(coachChatProvider.notifier)
        .noteFromCoach('Stopped. Your plan is unchanged.');
  }

  /// Takes a request the user made in chat and runs it through the real plan
  /// editor: propose → show the diff → apply only if they accept. Same path as
  /// the schedule screen, so a change asked for here is as reviewable as one
  /// asked for there.
  Future<void> _applyScheduleOffer(ScheduleOffer offer) async {
    if (_applyingOffer) return;
    final before = ref.read(programProvider);
    if (before == null) return;
    setState(() => _applyingOffer = true);
    final generation = ++_applyGeneration;
    bool cancelled() => _applyGeneration != generation;
    final chat = ref.read(coachChatProvider.notifier);
    try {
      final outcome = await ref.read(programProvider.notifier).applyAiScheduleEdit(
            offer.request,
            ref.read(userProfileProvider),
            isCancelled: cancelled,
          );
      if (!mounted || cancelled()) return;
      switch (outcome) {
        case PlanUpdated(:final note, :final concern, program: final proposed):
          final accepted = await showSchedulePreviewSheet(
            context,
            before: before,
            after: proposed,
            note: note,
            concern: concern,
            request: offer.request,
          );
          if (!mounted || cancelled()) return;
          if (accepted) {
            ref.read(programProvider.notifier).loadProgram(proposed);
            CxHaptics.fire(CxHaptic.success);
            chat.noteFromCoach('Done — I updated your plan. $note');
          } else {
            chat.noteFromCoach('Kept your current plan — nothing changed.');
          }
        case PlanNeedsInfo(:final question):
          chat.noteFromCoach(question);
      }
    } on PlanException catch (e) {
      if (!mounted || cancelled() || e.code == 'cancelled') return;
      chat.noteFromCoach(
        e.isSilentFallback
            ? "I can't rewrite your plan right now — I couldn't reach the plan "
                'builder. You can still move days around from the schedule '
                'screen, and those edits work offline.'
            : e.message,
      );
    } finally {
      // A cancelled attempt already cleared its own state; a late reply must
      // not reopen the spinner or wipe a newer offer.
      if (mounted && !cancelled()) {
        ref.read(scheduleOfferProvider.notifier).clear();
        setState(() => _applyingOffer = false);
      }
    }
    _scrollToBottom();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    // One question at a time — prevents double-sends while Coach is thinking
    // (the server enforces a cooldown too; this just keeps the UI honest).
    if (ref.read(coachThinkingProvider)) return;
    ref.read(coachChatProvider.notifier).sendMessage(text, ref: ref);
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(programProvider);
    if (program == null) {
      final l10n = AppL10n.of(context);
      return PlaceholderScreen(
        title: l10n.coachTitle,
        message: l10n.coachPlaceholder,
        icon: Icons.forum_rounded,
        accent: CxColors.ember,
        yorhartExpression: 'coaching',
      );
    }

    final c = context.cx;
    final messages = ref.watch(coachChatProvider);
    final quests = ref.watch(questProvider);
    final levelUp = ref.watch(levelUpProvider);

    // Auto-scroll to bottom whenever new messages are added or received
    ref.listen<List<ChatMessage>>(coachChatProvider, (previous, next) {
      if (next.isNotEmpty) {
        _scrollToBottom(animate: true);
      }
    });

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: Text("Coach & Progression", style: CxType.headline.copyWith(color: c.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: c.textTertiary),
            tooltip: "About Coach",
            onPressed: () => _showAboutCoachSheet(c),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: c.ember,
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textTertiary,
          labelStyle: CxType.titleSmall,
          unselectedLabelStyle: CxType.label,
          tabs: const [
            Tab(text: "AI Coach"),
            Tab(text: "Quest Board"),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: AI Coach Chat
              _buildChatTab(messages, c),

              // Tab 2: Quest Board
              _buildQuestTab(quests, c),
            ],
          ),

          // Level Up Ceremony Overlay
          if (levelUp != null)
            _buildLevelUpOverlay(levelUp, c),
        ],
      ),
    );
  }

  /// "About Coach" — professional, trust-building disclosure. Lives behind
  /// the ⓘ so it never nags, but is one tap away for anyone who wants it.
  void _showAboutCoachSheet(CxColorsExt c) {
    CxHaptics.fire(CxHaptic.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CxGlassBottomSheet(
        title: "About Coach Yorhart",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: const YorhartWidget(
                  expression: 'coaching', size: 72, animate: true),
            ),
            const SizedBox(height: CxSpace.lg),
            _aboutRow(
              c,
              Icons.psychology_rounded,
              "AI-powered coaching",
              "Yorhart is an AI coach built on established exercise-science principles — progressive overload, evidence-based volume ranges, and recovery fundamentals.",
            ),
            const SizedBox(height: CxSpace.md),
            _aboutRow(
              c,
              Icons.insights_rounded,
              "Grounded in your data",
              "Answers are personalized using your logged workouts, bodyweight trend, program and goals — not generic templates. The more you log, the sharper the advice.",
            ),
            const SizedBox(height: CxSpace.md),
            _aboutRow(
              c,
              Icons.verified_user_rounded,
              "Built-in guardrails",
              "Coach never recommends extreme diets or unsafe loading, and always defers to professionals on pain or injury.",
            ),
            const SizedBox(height: CxSpace.lg),
            Container(
              padding: const EdgeInsets.all(CxSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: CxRadii.brMd,
              ),
              child: Text(
                "Responses are AI-generated general guidance — not medical, dietetic or physiotherapy advice. For pain, injury, or health conditions, consult a qualified professional.",
                style: CxType.caption.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: CxSpace.sm),
          ],
        ),
      ),
    );
  }

  Widget _aboutRow(CxColorsExt c, IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.ember),
        const SizedBox(width: CxSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(body,
                  style: CxType.caption.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(List<ChatMessage> messages, CxColorsExt c) {
    final thinking = ref.watch(coachThinkingProvider);
    if (thinking) _scrollToBottom();

    // An apply-to-my-plan action only belongs under the reply it was made for,
    // and only once Coach has finished talking.
    final offer = ref.watch(scheduleOfferProvider);
    final showOffer = offer != null &&
        !thinking &&
        messages.isNotEmpty &&
        messages.last.id == offer.afterMessageId;

    return Column(
      children: [
        // Chat messages scrolling area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(CxSpace.screen, CxSpace.md, CxSpace.screen, 100),
            itemCount:
                messages.length + (thinking ? 1 : 0) + (showOffer ? 1 : 0),
            itemBuilder: (context, idx) {
              if (showOffer && idx == messages.length) {
                return _ScheduleOfferCard(
                  colors: c,
                  busy: _applyingOffer,
                  onApply: () => _applyScheduleOffer(offer),
                  onDismiss: _applyingOffer
                      ? _stopApplyingOffer
                      : () => ref.read(scheduleOfferProvider.notifier).clear(),
                );
              }
              if (idx == messages.length) {
                return _ThinkingBubble(colors: c);
              }
              final msg = messages[idx];
              return _buildMessageBubble(msg, c);
            },
          ),
        ),

        // Chat input pane
        _buildChatInputArea(c),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, CxColorsExt c) {
    final isUser = msg.isUser;
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
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
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  GestureDetector(
                    onTap: () => _showAboutCoachSheet(c),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Yorhart",
                          style: CxType.caption.copyWith(color: c.ember, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          " · AI",
                          style: CxType.caption.copyWith(color: c.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CxSpace.xs),
                ],
                Text(
                  msg.text,
                  style: CxType.bodySmall.copyWith(color: isUser ? c.onEmber : c.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatInputArea(CxColorsExt c) {
    final thinking = ref.watch(coachThinkingProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(CxSpace.screen, CxSpace.sm, CxSpace.screen, 110),
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Starter chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _starterChips.length,
              itemBuilder: (context, idx) {
                final text = _starterChips[idx];
                return GestureDetector(
                  onTap: () {
                    _sendMessage(text);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: CxSpace.sm),
                    padding: const EdgeInsets.symmetric(horizontal: CxSpace.md, vertical: CxSpace.xs),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: CxRadii.brPill,
                      border: Border.all(color: c.border),
                    ),
                    child: Center(
                      child: Text(
                        text,
                        style: CxType.caption.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: CxSpace.sm),

          // Message input bar
          Row(
            children: [
              Expanded(
                child: CxTextField(
                  controller: _messageController,
                  hint: "Ask Coach Yorhart...",
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              // Mid-reply this becomes a stop button. Yorhart's thinking
              // animation above already shows something is happening, so this
              // slot is better spent on the escape hatch than on a second
              // spinner the user can't act on.
              Semantics(
                button: true,
                label: thinking ? 'Stop Coach' : 'Send message',
                child: Material(
                  color: thinking ? c.surfaceHigh : c.ember,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: thinking
                        ? () => ref
                            .read(coachChatProvider.notifier)
                            .stopResponding(ref)
                        : (_messageController.text.trim().isEmpty
                            ? null
                            : () => _sendMessage(_messageController.text)),
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

  Widget _buildQuestTab(List<Quest> quests, CxColorsExt c) {
    final weeklyQuests = quests.where((q) => !q.isMilestone).toList();
    final milestoneQuests = quests.where((q) => q.isMilestone).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(CxSpace.screen, CxSpace.md, CxSpace.screen, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          _buildProgressionIntroCard(c),
          const SizedBox(height: CxSpace.xl),

          // Weekly Quests
          Text("Weekly Quests", style: CxType.title.copyWith(color: c.textPrimary)),
          Text("Resets automatically every Monday.", style: CxType.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.md),
          for (final quest in weeklyQuests) ...[
            _buildQuestRowCard(quest, c),
            const SizedBox(height: CxSpace.md),
          ],
          const SizedBox(height: CxSpace.x2l),

          // Milestone Quests
          Text("Milestone achievements", style: CxType.title.copyWith(color: c.textPrimary)),
          Text("Lifetime challenges to cement your consistency.", style: CxType.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.md),
          for (final quest in milestoneQuests) ...[
            _buildQuestRowCard(quest, c),
            const SizedBox(height: CxSpace.md),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressionIntroCard(CxColorsExt c) {
    return CxPastelCard(
      tint: CxPastelTint.lilac,
      child: Row(
        children: [
          Icon(Icons.shield_rounded, size: 40, color: cxPastelInk()),
          const SizedBox(width: CxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Crux Progression", style: CxType.titleSmall.copyWith(color: cxPastelInk())),
                Text(
                  "Earn XP from finished workouts, tracking weight, and claiming quest rewards. Power up your profile and transition from Novice to Iron Warrior!",
                  style: CxType.caption.copyWith(color: cxPastelInk(opacity: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestRowCard(Quest quest, CxColorsExt c) {
    final double percent = (quest.currentValue / quest.targetValue).clamp(0.0, 1.0);

    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  quest.title,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: c.warning, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "+${quest.xpReward} XP",
                    style: CxType.caption.copyWith(color: c.warning, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            quest.description,
            style: CxType.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.lg),
          Row(
            children: [
              Expanded(
                child: CxProgressBar(
                  value: percent,
                  height: 10,
                  accent: quest.isMilestone ? CxProgressAccent.ember : CxProgressAccent.ultraviolet,
                ),
              ),
              const SizedBox(width: CxSpace.md),
              Text(
                "${quest.currentValue}/${quest.targetValue}",
                style: CxType.numS.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (quest.isCompleted && !quest.isClaimed) ...[
            const SizedBox(height: CxSpace.md),
            CxButton(
              label: "Claim +${quest.xpReward} XP",
              expand: true,
              haptic: CxHaptic.success,
              onPressed: () {
                ref.read(questProvider.notifier).claimQuest(quest.id, ref: ref);
              },
            ),
          ] else if (quest.isClaimed) ...[
            const SizedBox(height: CxSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: c.success, size: 16),
                const SizedBox(width: 4),
                Text("Quest Completed & Claimed", style: CxType.caption.copyWith(color: c.success, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelUpOverlay(int level, CxColorsExt c) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.92),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_bolt_rounded, color: c.ember, size: 100),
              const SizedBox(height: CxSpace.xl),
              Text(
                "CONGRATULATIONS!",
                style: CxType.overline.copyWith(color: c.ember, fontSize: 16),
              ),
              const SizedBox(height: CxSpace.md),
              Text(
                "LEVEL UP!",
                style: CxType.displayXL.copyWith(color: Colors.white, fontSize: 50),
              ),
              const SizedBox(height: CxSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: CxSpace.x2l, vertical: CxSpace.sm),
                decoration: BoxDecoration(
                  color: c.ultraviolet.withOpacity(0.2),
                  borderRadius: CxRadii.brLg,
                  border: Border.all(color: c.ultraviolet, width: 2),
                ),
                child: Text(
                  "Level $level",
                  style: CxType.displayL.copyWith(color: c.ultraviolet),
                ),
              ),
              const SizedBox(height: CxSpace.lg),
              Text(
                "You are building unstoppable momentum.",
                style: CxType.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: CxSpace.x4l),
              CxButton(
                label: "Continue Journey",
                onPressed: () {
                  ref.read(levelUpProvider.notifier).clearLevelUp();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apply-to-my-plan offer
// ---------------------------------------------------------------------------

/// Shown under a reply about changing the training week. Advice the user has
/// to re-enter somewhere else is advice they mostly won't act on — this turns
/// it into one tap, without turning it into an automatic rewrite.
class _ScheduleOfferCard extends StatelessWidget {
  const _ScheduleOfferCard({
    required this.colors,
    required this.busy,
    required this.onApply,
    required this.onDismiss,
  });

  final CxColorsExt colors;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      margin: const EdgeInsets.only(left: 40, bottom: CxSpace.lg),
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
              Text(
                busy ? 'Rewriting your plan' : 'Want me to change your plan?',
                style: CxType.titleSmall.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.xs),
          Text(
            busy
                // A full program rebuild takes tens of seconds. Silence for
                // that long reads as broken, so say what is happening and how
                // long it takes.
                ? 'Rebuilding your whole week takes a few seconds. Nothing is '
                    'saved until you review the changes.'
                : "I'll rewrite your week from what you just asked and show you "
                    'exactly what changes. Nothing moves until you accept it.',
            style: CxType.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.md),
          Row(
            children: [
              Expanded(
                child: CxButton(
                  label: 'Update my plan',
                  expand: true,
                  loading: busy,
                  haptic: CxHaptic.selection,
                  onPressed: busy ? null : onApply,
                ),
              ),
              const SizedBox(width: CxSpace.sm),
              Expanded(
                child: CxButton(
                  // Mid-rewrite this is the escape hatch, not a dismissal.
                  label: busy ? 'Stop' : 'Not now',
                  variant: CxButtonVariant.secondary,
                  icon: busy ? Icons.stop_rounded : null,
                  expand: true,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thinking bubble — labor illusion (plan section 5): staged, real-feeling work
// ---------------------------------------------------------------------------

/// Shown while the coach call is in flight: Yorhart avatar, three pulsing
/// dots, and a status line that advances through coaching stages. People
/// trust results more when they can see the work happening.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble({required this.colors});

  final CxColorsExt colors;

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _stageTimer;
  int _stage = 0;

  static const _stages = [
    'Reading your training data',
    'Checking your recent sessions',
    'Crunching your numbers',
    'Writing your answer',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() => _stage = (_stage + 1).clamp(0, _stages.length - 1));
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
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
              expression: 'coaching',
              size: 24,
              animate: true,
            ),
          ),
        ),
        Container(
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
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      // Staggered sine-ish pulse per dot.
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
                  );
                },
              ),
              const SizedBox(width: CxSpace.md),
              AnimatedSwitcher(
                duration: CxDuration.base,
                child: Text(
                  _stages[_stage],
                  key: ValueKey(_stage),
                  style: CxType.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
