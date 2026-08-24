# Crux — Backend (Supabase)

This is the server side for the Crux Flutter app. It implements the backend
work described in the product plan (`gym-app-plan-and-prompt-v2.md`):

- **Phase 6 — Auth + Sync**: Postgres schema mirroring the local Drift tables,
  Row Level Security (own-rows-only), email OTP / Google / Apple / anonymous
  auth, and the columns the queue-based sync layer needs (`updated_at`,
  `deleted_at` tombstones, last-write-wins).
- **Phase 7 — AI Coach**: the `coach` Edge Function that proxies Anthropic
  (primary) with Gemini fallback (keys server-side only), assembles grounding
  context, enforces the free 5-messages/week limit, applies safety guardrails,
  and streams replies.
- **Phase 8/9 hooks**: `razorpay-webhook` for `is_pro` entitlement, and
  `recompute_rank_signals()` for the Progression System.

> Architecture principle from the plan: **everything except AI chat works in
> airplane mode.** The client (Drift/SQLite) is the source of truth; this
> backend is a sync target + the AI proxy, never a blocking dependency.

---

## Layout

```
supabase/
├── config.toml                 # local stack + auth config
├── seed.sql                    # reference exercise library
├── .env.example                # Edge Function secrets template
├── migrations/
│   ├── 20260708120000_extensions_and_helpers.sql
│   ├── 20260708120100_schema.sql          # all tables, indexes, triggers
│   ├── 20260708120200_rls_policies.sql    # own-rows-only RLS
│   └── 20260708120300_functions.sql       # coach_context, rate limit, rank signals
└── functions/
    ├── _shared/cors.ts
    ├── coach/index.ts          # Anthropic primary + Gemini fallback (streaming)
    └── razorpay-webhook/index.ts
```

## Tables (mirror plan §11)

`profiles` · `exercises` · `programs` · `workouts` · `set_logs` · `body_logs` ·
`prs` · `quests` · `xp_events` · `rank_signals` · `promotions` ·
`protein_logs` (Tier 3) · `friendships` (Tier 2) · `chat_messages`
(server-only) · `billing_events` (server-only).

Every user-owned table has `user_id → auth.users`, RLS restricting all access
to `auth.uid() = user_id`, an `updated_at` trigger, and a soft-delete
`deleted_at` tombstone so deletions sync.

---

## Local setup

```bash
# 1. Install the Supabase CLI (https://supabase.com/docs/guides/cli)
# 2. From the repo root:
supabase start                 # boots Postgres + Studio + Edge runtime
supabase db reset              # runs migrations + seed.sql

# 3. Provide Edge Function secrets for local serving:
cp supabase/.env.example supabase/.env   # then fill in ANTHROPIC_API_KEY etc.
supabase functions serve --env-file supabase/.env
```

Studio: http://localhost:54323 · API: http://localhost:54321 · captured
emails (OTP links): http://localhost:54324.

## Deploy to a hosted project

```bash
supabase link --project-ref <your-project-ref>
supabase db push                                  # apply migrations
psql "$DATABASE_URL" -f supabase/seed.sql         # seed exercises (or run in SQL editor)

# Secrets (server-side only — AI keys never ship in the app):
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set GEMINI_API_KEY=AIza...          # fallback when Anthropic fails
supabase secrets set RAZORPAY_WEBHOOK_SECRET=whsec_...

# Edge Functions:
supabase functions deploy coach
supabase functions deploy razorpay-webhook --no-verify-jwt   # provider-signed
```

Enable Google/Apple in `config.toml` (or the dashboard) and set their secrets
when you wire those sign-in buttons.

---

## Flutter client wiring (integration guide)

The frontend currently runs on in-memory Riverpod providers with mock data.
To connect it to this backend, three thin layers are needed (none change the
UI). Suggested files under `lib/core/data/`:

**1. Bootstrap** — in `main.dart`:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

Add `supabase_flutter` to `pubspec.yaml`. Pass the URL/key at build time with
`--dart-define` so they aren't hardcoded.

**2. Sync service** — on login/foreground: push local rows where
`synced == false` (upsert by `id`), then pull rows where
`updated_at > lastPulledAt` and merge last-write-wins (respect `deleted_at`).
Because PKs are device-generated UUIDs, the same row upserts cleanly from any
device.

**3. Coach API** — replace the mock logic in `CoachChatNotifier.sendMessage`
with a call to the Edge Function and consume the SSE stream:

```dart
final res = await supabase.functions.invoke(
  'coach',
  body: {'message': text, 'history': recentTurns},
);
// For streaming, hit the function URL directly with an http client and
// parse `data: {...}` lines (type: 'delta' | 'done' | 'error').
```

The function returns `429 {code:'rate_limited'}` when a free user is out of
weekly messages — surface the upgrade prompt, don't retry.

---

## Guardrails & ethics (enforced server-side)

- AI keys (`ANTHROPIC_API_KEY`, `GEMINI_API_KEY`) exist only in Edge Function
  env; the app never sees them. Anthropic is tried first; Gemini is the fallback.
- The coach system prompt hard-codes: no medical diagnosis, no extreme-diet or
  PED content, never shame rest, ground answers only in the user's own data.
- Grounding context (`coach_context()`) is built server-side from the caller's
  rows only — the client cannot inject another user's data.
- Free tier is rate-limited from `chat_messages` counts, so it can't be
  bypassed by the client.
- All transcripts are logged (`chat_messages`) for safety auditing (plan §12).
