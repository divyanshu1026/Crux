# Crux v2 — Full Product Plan & Claude Code Master Prompt
*(Global product. Working name — alternatives: LiftUp, IronPath, FirstRep, Repwise)*

---

## 1. Positioning

**The AI gym coach that teaches beginners what to do, tracks every rep, and turns lifelong consistency into a game.**

Global from day one. Localization is handled through *units, currency, and language* — not through market-specific features. Gym training is the same everywhere; only the display layer changes.

- **Units**: default from device locale/region (kg for metric countries, lbs for US/Liberia/Myanmar), overridable in Settings. All data stored internally in kg.
- **Currency & pricing**: regional price tiers via the app stores / Razorpay International (Razorpay supports international cards and 100+ currencies; UPI additionally for India).
- **Language**: English at launch; l10n architecture from day one so any language is a string-file away.

---

## 2. Market landscape (mid-2026) & the gaps

| App | Owns | Weakness exploited |
|---|---|---|
| Hevy (~$24/yr) | Best free tier, social, fast logging | Doesn't coach; assumes you know your program |
| Strong (~$30/yr) | Fastest minimalist logger | Zero guidance, zero AI, no demos |
| Fitbod (~$96/yr) | Algorithmic workout generation | Expensive; opaque; fights user preference; no explanations |
| Jefit | 1,400+ exercise library | Cluttered, dated UX, overwhelming |
| Boostcamp | Expert pre-made programs | Follow-only; no personalization or gamification |
| Slate / Vora / Stronger | Recovery, strength scores | iOS-heavy, premium-priced, intermediate+ focus |

**The five gaps:** (1) nobody *explains* — trackers log, generators generate; (2) beginners are explicitly warned away from the best trackers; (3) AI coaching is priced at ~$96/yr — a fraction of that price opens a much larger market; (4) gamification everywhere is shallow (streaks and badges, no progression loop); (5) no app is designed to *grow with the user for years* — they serve one experience level and lose users who evolve.

Gap 5 is why the **Progression System (§6)** exists — it's the retention answer nobody else has.

---

## 3. Personas

**P1 — Confused Beginner** (0–12 months). Doesn't know splits, overload, or whether their numbers are good. Fears looking stupid and wasting months. Wants to be told what to do today and shown they're improving. Primary persona, all genders.

**P2 — Returning / Inconsistent**. Knows basics, fell off. Motivation-driven. The gamification layer hits hardest here.

**P3 — Self-directed Intermediate/Advanced**. Has a program, wants fast logging + smart analytics. Served by the same core loop plus the advanced tier unlocked via the Progression System.

**Cross-gender product requirements** (details, not separate personas): glute/lower-body templates as first-class citizens; strength standards calibrated by sex and bodyweight; diverse avatars; hypertrophy/strength framing with zero calorie-restriction messaging; optional cycle-aware training notes (opt-in, later phase).

---

## 4. Design system — "does not look AI-generated" is a requirement

**Anti-goals (explicitly forbidden in the prompt):** the three template looks — (a) near-black + single acid-green accent (the current fitness-app cliché, including the reference screenshots' worst habit), (b) cream + serif + terracotta, (c) generic Material defaults with Inter everywhere.

**Direction — "Night Gym":** dark-first (gyms are dim, OLED saves battery) but *warm* dark, layered with tactile pastel surface cards and a two-accent system.

- **Palette (tokens):**
  - `canvas` #121114 (warm near-black, not pure black)
  - `surface` #1C1B1F, `surface-raised` #26242B
  - `card-lilac` #D9CFF5, `card-cream` #F3EDDF, `card-mint` #CFE8D8 (tactile light cards floating on dark — content chips, plan cards)
  - `accent-hot` #FF5C39 (embers — PRs, CTAs, celebration)
  - `accent-cool` #9A8CFF (ultraviolet — progress, analytics)
  - Semantic: success/warn/error derived, never raw green/red for lift performance (colorblind-safe patterns + icons).
- **Typography is the hero.** In a lifting app the numbers ARE the product. Display face for numerals and headers: a characterful grotesque with personality (e.g., Clash Display or Cabinet Grotesk from Fontshare — NOT Inter, NOT Roboto, NOT Poppins). Body/UI face: a quiet humanist grotesque (e.g., General Sans). Data/mono face for weights & timers: a tabular-figures mono (e.g., JetBrains Mono or Space Mono) so numbers never jitter as they change. Weight numerals render huge — 64–96pt on the logging screen.
- **Signature element (the one memorable thing):** the **PR moment** — when a personal record lands, the logged number physically *slams* onto the screen with a variable-font weight animation (thin→black), a bass haptic thud, ember particles, and the exercise name stamped beneath. One orchestrated moment, everything else stays disciplined.
- **Motion language:** springy but fast (all transitions ≤250ms), respectful of reduced-motion settings. Rest timer breathes subtly. Number changes roll like a mechanical counter. No scattered gratuitous animation — motion only where it communicates state.
- **Shape language:** chunky 20–24px radii, generous padding, 56px minimum tap targets (post-set shaky hands), one-handed reachability for every primary action.

---

## 5. Psychology system (applied, with an ethics line)

Every mechanic below maps to an established behavioral principle. **Ethics rule baked into the prompt: motivate, never shame; no dark patterns; no fake urgency; no fabricated social proof.** Shame-based fitness apps churn — and it's wrong.

| Principle | Where it's applied |
|---|---|
| **Fogg Behavior Model** (reduce friction) | ≤3-tap set logging; pre-filled weights; auto rest timer. The entire core loop. |
| **Endowed progress effect** | Onboarding progress bar starts at ~15% ("we've already set up the basics"). Milestone quests begin with 1/5 pre-credited from onboarding actions. |
| **Labor illusion** | After onboarding, a 4–6s staged "Building your program" sequence (Analyzing your goals → Selecting exercises for your equipment → Calibrating starting weights) — people trust results more when they see the work. Must be real computation staged, not a fake spinner. |
| **Peak-end rule** | Workout summary is a celebration screen (volume, PRs, XP count-up), so every session *ends* on a high. |
| **Loss aversion, humanely** | Weekly streak + one monthly Rest Pass that auto-protects a missed week. Protecting a streak is stronger motivation than earning one — but illness never nukes months of identity. |
| **Variable reward** | Occasional surprise bonus XP ("Coach's bonus: +40 XP for perfect form consistency this week") — unpredictable, small, delightful. |
| **Goal gradient** | Quest progress bars visually accelerate near completion; "1 workout away" nudges. |
| **Zeigarnik effect** | An unfinished workout persists as a gentle open loop on the home screen ("Resume — 3 exercises left"). |
| **Identity-based habits** | Copy milestones speak identity, not activity: after workout #10 → "Ten sessions. You're not trying the gym anymore — you train." Rank titles reinforce it. |
| **Fresh start effect** | Weekly quests reset Monday; monthly Boss Battle starts on the 1st; "new program block" moments framed as fresh chapters. |
| **Commitment & consistency** | User picks their training days in onboarding and the app holds them to *their own* plan ("You planned Push today"), never to an imposed one. |
| **Anchoring (paywall only)** | Annual plan anchored against monthly with honest math. No fake countdown timers. |
| **Competence (Self-Determination Theory)** | Strength-standard bands shown as *encouraging context* ("ahead of most people at your training age"), never leaderboard shame. |

---

## 6. The Progression System (user-controlled, lifetime arc)

The answer to "what happens when a beginner becomes intermediate" — and the app's core long-term retention mechanic. Framed in-game as **Ranks**.

**Signals tracked silently:** total workouts logged, training months, consistency %, e1RM of key lifts vs. sex/bodyweight-calibrated strength standards, frequency of stalls/deloads, exercise vocabulary breadth.

**Promotion flow (never automatic — always user-confirmed):**
1. Thresholds crossed → a **Promotion Available** card appears on the dashboard (not a blocking popup).
2. It shows the evidence: "62 workouts · 8 months consistent · Squat crossed Novice standard · Bench approaching it."
3. User taps → sees exactly what changes at the next rank: more volume, new exercise variations, rep-range periodization, RPE tracking unlocked, advanced analytics unlocked.
4. **Accept** → celebratory rank ceremony, program regenerates at the new level (user reviews & can edit before it activates). **Not yet** → dismissible, resurfaces after meaningful new progress. Users can also self-set experience level in Settings anytime (both directions — coming back from a long break should allow stepping down without shame: "Rebuilding rank" framing).

**Program lifecycle (mesocycles):** every 8–12 weeks the app proposes a program refresh ("You've run this block for 10 weeks — time to rotate exercises and reset rep ranges?") with a diff view of proposed changes. User approves, edits, or keeps current. This prevents staleness — the #1 silent killer of long-term users — while keeping the user in control.

**Rank ladder (unlocks per rank):**
- **Novice** — guided everything, explanations everywhere, 3–4 exercises/day
- **Apprentice** — exercise swapping freedom, volume tracking
- **Iron I–III** — RPE logging, per-muscle weekly volume targets, deload weeks
- **Steel** — periodization blocks, custom program builder, advanced analytics (e1RM trends, fatigue proxy)
- **Titan** — full manual control + the AI as a peer-level analyst

---

## 7. Dashboard (dedicated tab)

One screen where the user sees *everything at a glance* — the "am I actually improving?" answer:

- Current rank + XP bar + streak
- Bodyweight 7-day rolling average sparkline (raw points ghosted)
- This week: workouts done vs planned, total volume vs last week
- Consistency heatmap (last 12 weeks of gym days)
- Big-lift e1RM trend mini-charts with strength-standard band markers
- Muscle-group weekly volume balance (radar or stacked bar) — flags neglected groups
- Recent PRs strip
- Active quests + Boss Battle progress
- "Ask Coach about my progress" entry point (AI gets this exact dashboard data as context)

---

## 8. Feature map — full product

**Tier 1 — Core loop (MVP, Phases 1–8):** onboarding + AI intake, rule-based program generator with "why" explanations, ≤3-tap logging with rest timers, deterministic progressive-overload engine with reasons, PR detection + signature celebration, body & habit tracking, XP/levels/quests/streaks/Rest Pass, Zen mode, dashboard v1, Supabase auth + offline-first sync, AI Coach chat with guardrails, analytics events, paywall (Razorpay International + regional pricing).

**Tier 2 — Growth (Phases 9–11):** Progression System full flow + rank unlocks; program marketplace (10–15 curated programs: PPL, Upper/Lower, Full-Body 3×, Glute-focus 4×, Home Dumbbell, 5/3/1-style, bodyweight); exercise demo media; Boss Battles; friend leaderboards (opt-in) + workout sharing cards (shareable image renders — organic growth loop); Hindi + Spanish + German l10n; home-screen widgets; health-platform sync (HealthKit / Health Connect) for weight & workouts.

**Tier 3 — Expansion (Phases 12–14):** social feed (follow, react — deliberately last: Hevy's moat, fight it only with an existing user base); protein-target-only nutrition tracking (NOT a food database — a daily protein goal + quick-log, the one nutrition metric hypertrophy actually hinges on); cycle-aware training notes (opt-in); Apple Watch / Wear OS set logging; AI weekly review ("Your week in iron" — auto-generated narrative summary, shareable); coach/PT dashboard (web, B2B — sell to personal trainers managing clients).

**Explicitly never (v-none):** full calorie/food database (a separate company), AI video form-checking (liability + hard), PED/extreme-cut content (ethics), engagement mechanics that punish rest.

---

## 9. Monetization (global)

- **Free**: full logging, overload engine, core gamification, dashboard v1, 5 AI messages/week, 3 routines.
- **Pro** — regional pricing, reference points: $4.99/mo · $34.99/yr (US), ₹149/mo · ₹999/yr (India), equivalent tiers elsewhere. Unlocks: unlimited AI coach, unlimited routines, full history & advanced analytics, program marketplace, exclusive avatar gear, AI weekly review.
- Payments: Razorpay International (cards, 100+ currencies, UPI in India) and/or store billing where required by platform policy — the prompt implements a `BillingService` abstraction so the provider is swappable.
- Cost rule: deterministic features free; LLM-cost features paid. Sonnet at ~50 msgs/user/month is comfortably covered by the lowest regional tier.

---

## 10. Tech stack

| Layer | Choice | Why |
|---|---|---|
| App | Flutter (Android + iOS) | Your existing expertise (Prenza); single codebase |
| State | Riverpod | Testable, modern |
| Local DB | Drift (SQLite), **local-first** | Offline gyms; instant logging |
| Backend | Supabase (auth, Postgres, Edge Functions, RLS) | Known stack; free tier suffices at launch |
| AI | Claude API via Supabase Edge Function proxy | Key server-side ONLY; per-user rate limits; prompt caching |
| Payments | Razorpay International behind a `BillingService` abstraction | Global cards + UPI; swappable for store billing |
| Analytics | PostHog | Funnels, retention cohorts, logging-speed metric |
| Charts | fl_chart | Trends, radar, heatmaps |
| Fonts | Fontshare/Google Fonts bundled locally | Offline-safe, licensed |

Architecture principle unchanged: **everything except AI chat works in airplane mode.**

---

## 11. Data model (v2 additions in bold)

```
User        (id, name, sex, dob, height_cm, experience_level, goal,
             days_per_week, equipment, units, locale, avatar_id,
             level, xp, rank, streak_weeks, rest_passes_remaining,
             zen_mode, is_pro, created_at)

Exercise    (id, name, muscle_group, secondary_muscles, equipment,
             is_compound, demo_url, instructions, l10n_key)

Program     (id, user_id, name, split_type, days json, is_active,
             source[ai|template|custom], block_started_at, rank_level)

Workout     (id, user_id, program_day_ref, started_at, completed_at, notes, synced)
SetLog      (id, workout_id, exercise_id, set_number, weight_kg, reps,
             rpe?, is_pr, is_warmup)
BodyLog     (id, user_id, date, weight_kg, measurements json?, photo_path?)
PR          (id, user_id, exercise_id, type[weight|e1rm|reps|volume], value, achieved_at)
Quest       (id, user_id, template_id, progress, target, status, xp_reward, expires_at)
XPEvent     (id, user_id, type, amount, ref_id, created_at)

**RankSignal  (id, user_id, signal_type, value, computed_at)**
**Promotion   (id, user_id, from_rank, to_rank, evidence json,
              status[available|accepted|deferred], created_at, decided_at)**
**ProteinLog  (id, user_id, date, grams)**            -- Tier 3
**Friendship  (id, user_id, friend_id, status)**       -- Tier 2
ChatMessage (id, user_id, role, content, created_at)   -- server-side only
```

e1RM: Epley `weight × (1 + reps/30)`.

---

## 12. Metrics & risks

**Metrics:** activation = onboarding-complete AND first workout logged (>40%); week-4 retention ≥2 workouts (>20%); median seconds-to-log-a-set (<8s); % accepting first Promotion within 7 days of it appearing; free→Pro conversion (>3%); **and: are YOU still using it daily at week 6.**

**Risks:** scope (the phased prompt + your discipline is the mitigation — MVP ships before Tier 2 starts); AI safety (guardrailed system prompt, logged conversations); Hevy's free tier (your pitch is "the app is your coach," never "better tracker"); design drifting template-ward (design-token approval gate in Phase 0); API cost (rate limits + caching + capped context).

---
---

# MASTER PROMPT FOR CLAUDE CODE — v2 (FULL PRODUCT)

*Paste everything below into Claude Code. It is phased: Phases 0–8 are the MVP, 9–11 Growth, 12–14 Expansion. Tell it to execute ONE phase at a time; review and approve between phases. Do not paste-and-walk-away.*

---

You are the founding engineer AND the design lead of **Crux** — a production-quality Flutter gym app with AI coaching, deep gamification, and a lifetime progression system. You have the standards of the best product designers in the world: every screen you ship should be indistinguishable from the output of a top-tier design studio, and must NOT look like a template or AI-generated UI. Work in phases; after each phase run `flutter analyze` (zero warnings), run all tests (green), then STOP and summarize what you built and what I should manually verify. Do not start the next phase without my approval.

## Global engineering requirements
- Flutter latest stable, Dart null-safe, Riverpod, GoRouter, freezed.
- **Local-first**: Drift (SQLite) is source of truth; every feature except AI chat works fully offline; sync layer reconciles with Supabase when online.
- Clean architecture `lib/features/<feature>/{data,domain,presentation}`; zero business logic in widgets.
- All weights stored in kg. Display units auto-detected from device locale/region (lbs for US-region locales, kg otherwise), overridable in Settings; conversion at the display layer only.
- l10n from day one (flutter gen-l10n); English strings now, keys structured for future languages. No hardcoded user-facing strings.
- Tests: unit tests for ALL domain logic (overload engine, XP engine, streak logic, rank signals get exhaustive coverage), widget tests per screen, golden tests for the 5 flagship screens (Today, Active Workout, PR celebration, Dashboard, Onboarding step).
- Accessibility: semantic labels, dynamic type, min 56px tap targets, colorblind-safe (never raw red/green as the sole signal), reduced-motion respected everywhere.

## Global design requirements — read carefully, this is a hard gate
- **Forbidden looks**: (a) pure-black background with a single acid-green accent; (b) cream background + serif + terracotta; (c) default Material styling with Inter/Roboto/Poppins. If you catch yourself producing any of these, stop and redesign.
- **Direction — "Night Gym"**: warm near-black canvas (#121114), layered surfaces (#1C1B1F / #26242B), tactile light pastel cards floating on dark (#D9CFF5 lilac, #F3EDDF cream, #CFE8D8 mint) for plan/content chips, and a TWO-accent system: #FF5C39 ember (CTAs, PRs, celebration) + #9A8CFF ultraviolet (progress, analytics). Light theme derives from the same tokens.
- **Typography is the hero.** Display face: Clash Display or Cabinet Grotesk (Fontshare, bundle locally). Body/UI: General Sans. Numerals/timers: a tabular-figures mono (Space Mono or JetBrains Mono) so changing numbers never jitter. Weight numerals on the logging screen render 64–96pt. Define a full type scale as theme tokens.
- **Signature moment**: the PR celebration. When a PR lands: the number slams in with a weight-animation (light→black), bass haptic, ember particle burst, exercise name stamped beneath, ~1.8s, skippable by tap. This is the ONE place to be theatrical; everything else stays disciplined.
- **Motion**: purposeful only. Transitions ≤250ms with spring curves; numbers roll like mechanical counters; rest timer bar breathes subtly. No decoration-only animation.
- Chunky 20–24px radii, generous whitespace, one-handed reachability for all primary actions.
- **Copywriting rules**: active voice, sentence case, plain verbs; buttons say exactly what happens ("Log set", "Start workout"); milestones speak identity ("You train now"), never shame; errors say what went wrong and how to fix it. No filler, no hype-speak.
- **Ethics rules (non-negotiable)**: no dark patterns, no fake urgency/countdowns, no fabricated social proof, never punish rest days, no calorie-restriction or extreme-diet messaging anywhere in UI copy.

## Phase 0 — Design tokens & app skeleton (approval gate)
1. Produce the complete design system as code: `theme/tokens.dart` (colors, type scale, spacing, radii, motion durations/curves, haptic map), light+dark ThemeData, and a `DesignGallery` debug screen showing every token, button style, card style, input, chip, and the number-roll widget.
2. Bundle and wire the three typefaces.
3. Build the app shell: GoRouter with bottom nav (Today · History · Dashboard · Coach · Profile), placeholder screens.
4. STOP. Show me screenshots of the DesignGallery and shell. I approve the visual language before any feature UI is built.

## Phase 1 — Data layer
1. Full Drift schema: User, Exercise, Program, ProgramDay, Workout, SetLog, BodyLog, PR, Quest, XPEvent, RankSignal, Promotion (fields per the plan doc; infer sensible types).
2. Seed 180+ exercises as a JSON asset: name, muscle_group, secondary_muscles, equipment (barbell/dumbbell/machine/cable/bodyweight/band), is_compound, one-line form cue, l10n key. Strong coverage of glute/lower-body movements (hip thrust, RDL variants, abductions, split squats) — not just bro-split staples.
3. Repositories with CRUD + reactive streams; unit tests.

## Phase 2 — Onboarding (this must feel like the most legitimate fitness app the user has ever installed)
1. Flow (PageView, animated progress bar that STARTS at 15% — endowed progress): welcome (one bold animated screen, identity-focused headline like "Walk in knowing exactly what to do", no stock photos) → name → sex (male/female/prefer not to say) → age → height → current weight (big mono numerals, unit auto-set from locale) → goal (build muscle / get stronger / lose fat & tone / general fitness — cards with subtle illustrations) → experience (never trained / <6 months / 6–24 months / 2+ years) → days per week (2–6, tap the actual weekdays) → equipment (full gym / dumbbells only / minimal home) → injuries or exercises to avoid (free text + quick chips: shoulder, knee, lower back, none) → notification permission with honest value framing.
2. Each step: single question, large touch targets, spring transitions, haptic tick on selection, back always available. A step never takes more than one decision.
3. **Program generation moment (labor illusion — must be real staged computation, not a fake spinner):** 4–6 seconds of staged progress — "Analyzing your goals" → "Selecting exercises for your equipment" → "Calibrating starting weights" → reveal.
4. **Rule-based program generator** (pure Dart, exhaustively tested, no AI): 2–3 days → Full Body; 4 → Upper/Lower; 5 → PPL+UL or PPLPP; 6 → PPL×2. Beginner: compound-focused, 3×8–12, 3–4 exercises/day; goal modifies rep ranges (strength 4–6 compounds; muscle 8–12; tone 10–15 + honest in-app note that nutrition drives fat loss). Equipment filters substitutions. Injury chips/text map to conservative exclusions with substitutes. Output includes a generated "why this program fits you" paragraph.
5. Program review screen: per-day cards (pastel card style), swap any exercise (picker filtered by muscle+equipment), confirm → active.
6. Avatar + display-name selection: 8+ diverse avatars (male- and female-presenting, varied), rank badge shown as "Novice — everyone starts here."
7. First-run Today screen shows Quest board with the first milestone quest already at 1/5 (endowed progress, credited from onboarding).

## Phase 3 — Core loop: workout logging (the sacred screen)
1. **Today screen**: today's plan card (or rest-day state with recovery framing, never guilt), streak, XP bar, next quest, resume-workout open loop if one is unfinished (Zeigarnik), Start Workout CTA. "Train anyway" picker on rest days.
2. **Active Workout screen** — optimize relentlessly, ≤3 taps per set in the common case:
   - Exercises with target sets×reps×suggested weight; previous session's numbers greyed inline.
   - Weight/reps steppers pre-filled from last session or the overload suggestion; giant mono numerals; one big Log button per set.
   - Auto rest timer (default 90s, per-exercise override) as persistent bottom bar with skip/+30s; local notification if backgrounded.
   - Swap/add exercise, add set, warmup flag, reorder — reachable but out of the fast path.
   - PR detection per set (weight PR + Epley e1RM PR) → the signature PR celebration.
   - Set-by-set instant persistence; kill-and-reopen resumes exactly.
3. Finish → summary/celebration screen (peak-end): duration, volume, PRs, animated XP count-up, one identity-flavored line at milestones.
4. **Progressive overload engine** (pure Dart, heavily tested): all working sets at top of rep range → +2.5kg upper / +5kg lower-compound next session, reps reset to bottom of range; missed target 2 sessions → hold weight; 3 → offer −10% deload. Every suggestion carries a human-readable `reason` surfaced in UI.
5. History tab: 12-week heatmap + past workouts list → full detail.

## Phase 4 — Body tracking + Dashboard
1. Daily weigh-in quick sheet, configurable reminder, 7-day rolling-average chart with ghosted raw points + a one-time explainer of why the average matters.
2. Optional measurements + local-only progress photos with side-by-side compare.
3. **Dashboard tab**: rank+XP+streak header; bodyweight sparkline; week summary (done vs planned, volume vs last week); consistency heatmap; big-lift e1RM mini-trends with strength-standard band markers (bundle published sex+bodyweight-calibrated standards as JSON, framed encouragingly); muscle-group weekly volume balance chart flagging neglected groups; recent PRs strip; active quests; "Ask Coach about my progress" entry.

## Phase 5 — Gamification engine
1. XP engine (event-sourced): workout +50, all planned sets +25, PR +100, weigh-in +5, quest rewards; occasional variable-reward bonus (small, random-ish, positive framing; deterministic seed so it's testable). Level curve XP = 100 × level^1.5. Level-up ceremony.
2. Rank titles: Novice → Apprentice → Iron I/II/III → Steel → Titan (ranks are progression-system-driven from Phase 9; until then display maps from level).
3. Streaks: a week counts when planned days are hit; one auto-applied Rest Pass per month; zero shame copy for misses ("Life happens — your Rest Pass covered this week").
4. Quests: weekly templates (log N workouts, +weight on any lift, hit a muscle 2×, 5 weigh-ins) resetting Mondays (fresh start); milestone quests (1st/10th/50th/100th workout, first PR, 4-week streak). Quest board with goal-gradient progress bars and claim animations.
5. Avatar gear unlocks per level (simple asset swaps).
6. **Zen mode** toggle: hides ALL gamification UI, clean-tracker presentation; events still record silently.
7. Exhaustive unit tests: XP math, level curve, streak edge cases (timezones, week boundaries, Rest Pass consumption), variable-reward determinism.

## Phase 6 — Supabase: auth + sync
1. Email OTP + Google + Apple sign-in. App fully usable anonymously; auth prompted only for sync/AI ("Your data lives only on this phone — sign in to back it up").
2. Postgres schema mirroring local tables, RLS (own-rows only), SQL migration files included.
3. Queue-based sync: push local changes, pull-merge on login, last-write-wins per row, retry with backoff, `synced` flags, status indicator in Settings. Never block UI on network.

## Phase 7 — AI Coach
1. Supabase Edge Function `coach` proxying the Anthropic API (key in server env ONLY). Server assembles context: profile, active program, last 10 workouts (compact JSON), bodyweight trend, recent PRs, current dashboard stats. Model claude-sonnet, ~800 max output tokens, prompt caching on the system block.
2. Coach system prompt enforces: encouraging, concise, beginner-first explanations; grounded ONLY in provided data — says so when it doesn't know; NO medical diagnosis — pain/injury → reduce load / stop movement / see a professional + safe substitutions only; no extreme-diet or disordered-eating-adjacent content; no PED guidance; form questions → cue-based tips + suggest video; ≤150 words unless asked.
3. Rate limiting: free 5 msgs/week, Pro unlimited (`is_pro` flag; Razorpay webhook TODO stub).
4. Chat UI: streaming, starter chips ("Explain my program", "Why this weight?", "Only 30 min today — what do I cut?"), one-time "general guidance, not medical advice" disclaimer.
5. Inline "Ask Coach" entries: from an exercise, from a stalled chart, from the workout summary, from the dashboard.

## Phase 8 — MVP polish + billing + release
1. Empty/error/loading states everywhere (empty states are invitations to act, not sad faces). App icon, splash, 3-step coach-marks on first Today screen.
2. Settings: units, theme, rest timer default, reminders, Zen mode, language stub, CSV export of all data, delete account/data.
3. `BillingService` abstraction + Razorpay International integration (subscriptions, regional price tiers by store country, UPI where available); paywall screen with honest annual-vs-monthly anchoring, NO countdown timers.
4. PostHog: onboarding_step/complete, workout_started, set_logged (with ms-since-previous), workout_completed, pr_hit, quest_claimed, promotion_shown/accepted, coach_message_sent, weigh_in_logged, paywall_viewed, subscribe.
5. Android release config (ProGuard, signing docs), iOS config, README (architecture, run, edge-function deploy).
=== MVP COMPLETE — ship to real users before continuing ===

## Phase 9 — Progression System (Ranks)
1. RankSignal computation job (local): total workouts, training months, consistency %, key-lift e1RMs vs bundled strength standards, stall frequency.
2. Promotion detection thresholds per rank; when crossed → Promotion row created → **Promotion Available** card on Dashboard (non-blocking) showing the evidence.
3. Promotion flow: evidence screen → "what changes at [rank]" preview (volume, new variations, unlocks: RPE logging at Iron, periodization + custom builder at Steel, full manual + analyst-mode coach at Titan) → Accept (rank ceremony + program regenerated at new level, user reviews/edits before activation) or Not yet (defer, resurface on new progress).
4. Self-set experience level in Settings, both directions; demotion framed as "Rebuilding" with zero shame.
5. Mesocycle refresh: every 8–12 weeks propose a program rotation with a diff view; approve/edit/keep.
6. Rank-gated feature flags cleanly implemented; exhaustive tests on signal math and threshold logic.

## Phase 10 — Content & motivation expansion
1. Program marketplace: 12+ curated programs (PPL, Upper/Lower, Full-Body 3×, Glute-focus 4×, Home Dumbbell, bodyweight, 5/3/1-style, hypertrophy blocks) as structured JSON, browsable with preview + one-tap adopt (Pro-gated except 3 free).
2. Exercise demo media: short looping clips or high-quality illustrations per exercise (asset pipeline documented; placeholder-safe).
3. Boss Battles: monthly challenge framed as a boss ("Add 10kg total across your big 3 this month"), starts on the 1st, with a dedicated progress screen and defeat ceremony.
4. Shareable workout cards: branded image render of a completed session/PR for social sharing (organic growth loop).
5. Home-screen widgets (Android + iOS): today's workout + streak.
6. Health platform sync: HealthKit / Health Connect for bodyweight + workout sessions.

## Phase 11 — Social layer (opt-in)
1. Friends via invite link/code; Friendship table + RLS.
2. Opt-in leaderboards among friends: weekly consistency and volume (never bodyweight).
3. Reactions on friends' PRs. No public feed yet; no comments (moderation scope).

## Phase 12 — Nutrition-lite + recovery notes
1. Protein-target-only tracking: daily gram goal computed from bodyweight+goal, quick-log buttons (+10g/+25g/custom), dashboard ring. Explicitly NOT a food database.
2. Opt-in cycle-aware training notes: user-enabled, private, gentle energy-planning hints; conservative evidence-based copy; fully ignorable.
3. AI weekly review (Pro): "Your week in iron" — narrative summary generated server-side from the week's data, shareable card.

## Phase 13 — Wearables
Apple Watch + Wear OS companion: today's exercise list, set logging (weight/reps crown/stepper input), rest timer with haptics, syncs to phone.

## Phase 14 — Coach platform (B2B, web)
Flutter web or lightweight Next.js dashboard for personal trainers: invite clients, view their logs/dashboards, assign programs, message-lite. Separate Pro-Coach billing tier. (Scope this phase with me before building.)

## Working rules for you (Claude Code)
- ONE phase at a time; analyzer clean + tests green + summary + my approval before proceeding. Phase 0's design gate and Phase 8's ship gate are hard stops.
- Prefer boring, well-supported packages; justify every new dependency in one line.
- Ambiguous product decision → make the beginner-friendly, ethics-compliant choice and flag it in your summary.
- The logging flow is sacred: any change that slows set-logging is wrong by definition.
- Before building each screen, write a 3-line design intent (what's the hero, what's quiet, what moves) — this prevents template drift.
