// ============================================================================
// Crux — Edge Function: `plan`
// ----------------------------------------------------------------------------
// Builds and edits training programs with an LLM, returning **strict JSON** the
// client applies directly. Two actions:
//
//   action: "generate"  → a whole program tailored to the onboarding answers
//   action: "edit"      → the user's program with a natural-language change
//                         applied ("more glutes", "I can only train 3 days")
//
// Why this is separate from `coach`: coach streams prose and is budgeted for
// conversation. This returns a validated object, needs schema enforcement, and
// costs far more per call — so it gets its own limits and its own ledger
// (public.plan_requests).
//
// Design rules:
//   * The model never talks to the client directly. Everything it returns is
//     parsed and validated here; anything malformed is rejected with a code the
//     app uses to fall back to its built-in templates. A user must never end up
//     with a broken program because a model had an off day.
//   * Errors are friendly one-liners. Provider detail goes to console only.
//   * The caller's identity comes from the verified JWT, never the body.
//
// Request:  { action, profile, program?, instruction? }
// Response: { program, note, provider } | { error, code }
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const OPENROUTER_API_KEY = (Deno.env.get("OPENROUTER_API_KEY") ?? "").trim();
const ANTHROPIC_API_KEY = (Deno.env.get("ANTHROPIC_API_KEY") ?? "").trim();
const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// See coach/index.ts — same contract, so one secret switches both functions.
const AI_PRIMARY = (Deno.env.get("AI_PRIMARY") ?? "openrouter").trim().toLowerCase();
const OPENROUTER_MODEL =
  (Deno.env.get("OPENROUTER_MODEL") ?? "deepseek/deepseek-v4-flash").trim();
const ANTHROPIC_MODEL = "claude-sonnet-5";
const GEMINI_MODELS = [
  "gemini-3.5-flash",
  "gemini-3.1-flash",
  "gemini-flash-latest",
];

// A full program is a big object: 6 days x 8 exercises x 9 fields.
//
// Raised from 8000 after a real failure: editing a 5-day PPLPP plan (30
// exercises) ran past the cap, the JSON arrived cut off mid-object, and
// `extractJson` could only report "unusable output" — the user saw "Coach
// couldn't build that right now" after a two-minute wait. Output tokens are
// only billed when used, so a cap that fits the biggest legal program costs
// nothing on the small ones.
const MAX_TOKENS = 16000;

// Plan calls are expensive. Generation happens once at onboarding; edits are
// occasional. 12/day is generous for real use and still caps a runaway bill.
const DAILY_CAP = 12;
const COOLDOWN_SECONDS = 8;

const FRIENDLY = {
  unavailable:
    "Coach can't build plans right now. Your schedule still works — try again later.",
  cooldown: "One moment — Coach is still working on your last change.",
  dailyCap:
    "You've reached today's limit for plan changes. You can still edit any day by hand.",
  badPlan:
    "Coach couldn't put a clean plan together for that. Try describing the change differently.",
  auth: "Sign in to let Coach build your plan.",
};

// ---------------------------------------------------------------------------
// Prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT =
  `You are Yorhart, the strength coach behind the Crux training app. You design
weekly training programs.

You reply with ONE JSON object and nothing else. No prose, no markdown, no code
fences.

When you are asked to CHANGE an existing program and the request is too vague,
incomplete or ambiguous to act on, reply with this object instead:

{ "clarify": string }   // one short question, max 140 chars, asking for the
                        // ONE thing you most need to know

Use "clarify" when the request:
- is cut off or unfinished ("I want to focus", "can you make it")
- names no concrete change ("make it better", "improve this")
- could mean several different edits and you would be guessing which
- asks for something you cannot see (a gym, a date, an injury they didn't list)

Do NOT use "clarify" to be polite or cautious. If the request has a reasonable
reading, act on it. "More glutes", "my shoulder hurts", "only dumbbells now",
"I can train 4 days" are all clear enough — do them. Never use "clarify" when
building a brand-new program, only when editing one.

Ask like a coach who wants to get it right, in their words: for "I want to
focus" ask "Focus on what — a muscle group, a lift, or fewer days?", not
"Please provide more information."

Otherwise the object must match this shape exactly:

{
  "name": string,               // short plan name, e.g. "Upper/Lower Strength"
  "description": string,        // one line, max 90 chars
  "whyFitsParagraph": string,   // 2-3 sentences addressed to the user as "you",
                                // naming the specific answers that shaped this
  "note": string,               // one short sentence describing what you did
  // Optional. Your professional opinion when what they asked for is a bad
  // idea for them. See the coaching rules below — you still DO what they
  // asked; this is you saying so, not you refusing.
  "concern": string | null,
  "days": [
    {
      "id": string,             // lowercase slug, unique, e.g. "upper-a"
      "name": string,           // e.g. "Upper A — Push Focus"
      "exercises": [
        {
          "id": string,         // lowercase slug, unique within the day
          "name": string,       // the common gym name for the movement
          // muscleGroup MUST be one of exactly these six. The app groups
          // volume by this string, so anything else fragments their stats.
          "muscleGroup": string,// Chest | Back | Shoulders | Legs | Arms | Core
          "equipment": string,  // Barbell | Dumbbell | Machine | Cable | Bodyweight
          "targetSets": number, // 2-5
          "targetReps": string, // a range like "8-12" or "4-6"
          "suggestedWeight": number,  // kg; 0 for bodyweight
          "restTimeSeconds": number   // 60-180; compounds rest longer
        }
      ]
    }
  ],
  "dayAssignments": { "Mon": "upper-a", ... }  // weekday -> day id; omit rest days
}

Programming rules — these are not negotiable:
- Produce exactly as many entries in "days" as the user has training days.
- Every id in dayAssignments MUST be an id present in days. Weekdays are the
  three-letter forms: Mon, Tue, Wed, Thu, Fri, Sat, Sun. Only use the weekdays
  the user actually trains.
- 4-8 exercises per day, compounds first, isolations last.
- Respect the equipment they have. "Minimal home" means no barbell and no
  machines. "Dumbbells only" means dumbbells, bodyweight and bands only.
- Work around every injury they list: never program a movement that directly
  loads an injured joint or region. Substitute, do not just remove.
- Match rep ranges to the goal: strength 3-6, hypertrophy 6-12, endurance/tone
  12-20. Beginners get simpler movements and fewer exercises.
- Never program two heavy sessions for the same muscle on consecutive days.
- suggestedWeight is a conservative starting load for THIS person given their
  bodyweight and experience. When unsure, go lighter — they can add weight.

Coaching judgement — use "concern":

A good coach does what the client asks and tells them the truth about it. A
bad coach either refuses, or silently does something stupid because they were
asked to. You are the first kind.

So when a request is genuinely not in their interest, you STILL apply it, and
you put your honest opinion in "concern". Set "concern" to null when the
request is fine — most are, and a coach who worries about everything gets
tuned out.

Raise a concern when the request would:
- work a muscle again with too little recovery (the same group hard on
  consecutive days)
- cut so much volume the goal they gave you stops being reachable
- pile isolation work on while dropping the compound lifts driving progress
- load a joint they told you is injured
- push training days beyond what their stated experience supports
- drop to so few sessions that the plan can't cover the whole body

Write it as one or two sentences, to them, in plain gym language. Name the
specific risk and the alternative you'd prefer. Never lecture, never moralise,
never repeat the request back at them.

Good: "Three biceps exercises on one day is more direct arm work than most
people recover from, and your rows already hit biceps hard. I'd cut it to two
and add a set to your rows instead — but it's your call, this is done."

Bad: "As your coach I must warn you that overtraining is dangerous."

Write like a coach who read their answers, not a template engine.`;

// ---------------------------------------------------------------------------
// Providers — both return raw text, which we then parse as JSON.
// ---------------------------------------------------------------------------

type ProviderResult =
  | { ok: true; text: string; provider: string }
  | { ok: false; status: number; detail: string };

function hasOpenRouterKey(): boolean {
  return OPENROUTER_API_KEY.startsWith("sk-or-");
}

function hasAnthropicKey(): boolean {
  return ANTHROPIC_API_KEY.startsWith("sk-ant-");
}

/// OpenRouter, OpenAI chat-completions shape.
///
/// `response_format: json_object` is requested because this endpoint's whole
/// contract is a JSON object — but it is not relied on: [extractJson] and
/// [validateProgram] still run, so a model that ignores the hint (or wraps the
/// object in prose) is handled rather than failing the request.
async function callOpenRouter(userPrompt: string): Promise<ProviderResult> {
  const resp = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "content-type": "application/json",
      "HTTP-Referer": "https://crux.app",
      "X-Title": "Crux",
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      max_tokens: MAX_TOKENS,
      temperature: 0.4,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
    }),
  });

  if (!resp.ok) {
    return { ok: false, status: resp.status, detail: await resp.text().catch(() => "") };
  }
  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content ?? "";
  if (typeof text !== "string" || !text.trim()) {
    return { ok: false, status: 502, detail: "empty completion" };
  }
  return { ok: true, text, provider: `openrouter:${OPENROUTER_MODEL}` };
}

function hasGeminiKey(): boolean {
  return GEMINI_API_KEY.length > 20;
}

async function callAnthropic(userPrompt: string): Promise<ProviderResult> {
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [
        { role: "user", content: userPrompt },
        // Prefilling the assistant turn with "{" is the reliable way to stop a
        // model prefacing JSON with "Here's your plan:".
        { role: "assistant", content: "{" },
      ],
    }),
  });

  if (!resp.ok) {
    return { ok: false, status: resp.status, detail: await resp.text().catch(() => "") };
  }
  const data = await resp.json();
  const text = (data?.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("");
  // Put back the "{" we prefilled.
  return { ok: true, text: "{" + text, provider: "anthropic" };
}

async function callGemini(userPrompt: string, model: string): Promise<ProviderResult> {
  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": GEMINI_API_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
        generationConfig: {
          maxOutputTokens: MAX_TOKENS,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  if (!resp.ok) {
    return { ok: false, status: resp.status, detail: await resp.text().catch(() => "") };
  }
  const data = await resp.json();
  const text = (data?.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("");
  return { ok: true, text, provider: `gemini:${model}` };
}

// ---------------------------------------------------------------------------
// Validation — the model is untrusted input like any other
// ---------------------------------------------------------------------------

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// The app groups training volume by muscleGroup, so a model that invents
// "Quads" or "Glutes" would silently split a user's leg stats in two. Snap
// anything unexpected onto the app's own six.
const MUSCLE_GROUPS = ["Chest", "Back", "Shoulders", "Legs", "Arms", "Core"];
const MUSCLE_ALIASES: Record<string, string> = {
  quads: "Legs",
  quadriceps: "Legs",
  hamstrings: "Legs",
  glutes: "Legs",
  calves: "Legs",
  adductors: "Legs",
  biceps: "Arms",
  triceps: "Arms",
  forearms: "Arms",
  abs: "Core",
  abdominals: "Core",
  obliques: "Core",
  traps: "Back",
  lats: "Back",
  "rear delts": "Shoulders",
  "full body": "Legs",
};

function normalizeMuscle(v: unknown): string {
  const raw = typeof v === "string" ? v.trim() : "";
  if (!raw) return "Legs";
  const exact = MUSCLE_GROUPS.find((m) => m.toLowerCase() === raw.toLowerCase());
  if (exact) return exact;
  return MUSCLE_ALIASES[raw.toLowerCase()] ?? "Legs";
}

const EQUIPMENT = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight"];

function normalizeEquipment(v: unknown): string {
  const raw = typeof v === "string" ? v.trim() : "";
  const exact = EQUIPMENT.find((e) => e.toLowerCase() === raw.toLowerCase());
  if (exact) return exact;
  const lower = raw.toLowerCase();
  if (lower.includes("band") || lower.includes("body")) return "Bodyweight";
  if (lower.includes("kettle") || lower.includes("dumb")) return "Dumbbell";
  if (lower.includes("bar")) return "Barbell";
  return "Dumbbell";
}

/** Pulls the JSON object out of a reply that may still have stray text around it. */
function extractJson(raw: string): unknown | null {
  const trimmed = raw.trim().replace(/^```(?:json)?/i, "").replace(/```$/, "");
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(trimmed.slice(start, end + 1));
  } catch {
    return null;
  }
}

function str(v: unknown, fallback = ""): string {
  return typeof v === "string" && v.trim() ? v.trim() : fallback;
}

function clampInt(v: unknown, lo: number, hi: number, fallback: number): number {
  const n = typeof v === "number" ? Math.round(v) : parseInt(String(v ?? ""), 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(hi, Math.max(lo, n));
}

function slug(v: unknown, fallback: string): string {
  const s = str(v).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  return s || fallback;
}

type CleanExercise = {
  id: string;
  name: string;
  muscleGroup: string;
  equipment: string;
  targetSets: number;
  targetReps: string;
  suggestedWeight: number;
  isWarmup: boolean;
  restTimeSeconds: number;
};

type CleanProgram = {
  id: string;
  name: string;
  description: string;
  whyFitsParagraph: string;
  days: { id: string; name: string; exercises: CleanExercise[] }[];
  dayAssignments: Record<string, string>;
};

/**
 * Coerces the model's object into a program the app can definitely render, or
 * returns null if it is too broken to repair. Repairing beats rejecting: a
 * plan with one odd rep range is still useful; a plan whose dayAssignments
 * point at non-existent days would crash the week view, so that we fix.
 */
function validateProgram(raw: unknown): CleanProgram | null {
  if (!raw || typeof raw !== "object") return null;
  const o = raw as Record<string, unknown>;

  const rawDays = Array.isArray(o.days) ? o.days : [];
  if (rawDays.length === 0 || rawDays.length > 7) return null;

  const usedDayIds = new Set<string>();
  const days = rawDays.map((d, i) => {
    const dd = (d ?? {}) as Record<string, unknown>;
    let id = slug(dd.id, `day-${i + 1}`);
    while (usedDayIds.has(id)) id = `${id}-${i + 1}`;
    usedDayIds.add(id);

    const rawEx = Array.isArray(dd.exercises) ? dd.exercises : [];
    const usedExIds = new Set<string>();
    const exercises: CleanExercise[] = rawEx
      .slice(0, 12)
      .map((e, j) => {
        const ee = (e ?? {}) as Record<string, unknown>;
        const name = str(ee.name);
        if (!name) return null;
        let exId = slug(ee.id, `${id}-ex-${j + 1}`);
        while (usedExIds.has(exId)) exId = `${exId}-${j + 1}`;
        usedExIds.add(exId);

        const reps = str(ee.targetReps, "8-12");
        return {
          id: exId,
          name,
          muscleGroup: normalizeMuscle(ee.muscleGroup),
          equipment: normalizeEquipment(ee.equipment),
          targetSets: clampInt(ee.targetSets, 1, 6, 3),
          // Guard against "8 to 12" or "12" — the app parses "a-b".
          targetReps: /^\d+\s*-\s*\d+$/.test(reps) ? reps.replace(/\s/g, "") : "8-12",
          suggestedWeight: Math.max(0, Number(ee.suggestedWeight) || 0),
          isWarmup: false,
          restTimeSeconds: clampInt(ee.restTimeSeconds, 30, 300, 90),
        };
      })
      .filter((e): e is CleanExercise => e !== null);

    return { id, name: str(dd.name, `Day ${i + 1}`), exercises };
  });

  // A day with no exercises is not a day.
  const usable = days.filter((d) => d.exercises.length >= 2);
  if (usable.length === 0) return null;

  // Assignments must point at days that exist, on real weekdays.
  const validIds = new Set(usable.map((d) => d.id));
  const rawAssign = (o.dayAssignments ?? {}) as Record<string, unknown>;
  const dayAssignments: Record<string, string> = {};
  for (const wd of WEEKDAYS) {
    const target = str(rawAssign[wd]);
    if (target && validIds.has(target)) dayAssignments[wd] = target;
  }
  // Every session the model wrote must actually land on a weekday.
  //
  // This used to only rebuild when the mapping was completely empty, which let
  // a much worse case through: a model that writes five sessions but whose
  // dayAssignments only match one id (a typo, a renamed slug) produced a
  // "5 workouts across 1 training day" week. The app then derives the user's
  // training days from these assignments, so one bad reply permanently
  // shrank their profile to a single training day and every template loaded
  // afterwards inherited it. Partial is worse than empty, so both rebuild.
  const assignedIds = new Set(Object.values(dayAssignments));
  const everyDayPlaced = usable.every((d) => assignedIds.has(d.id));
  if (!everyDayPlaced) {
    console.error(
      `plan: model placed ${assignedIds.size}/${usable.length} sessions on ` +
        `weekdays — rebuilding the layout`,
    );
    for (const wd of WEEKDAYS) delete dayAssignments[wd];
    const spread = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    usable.forEach((d, i) => {
      if (i < spread.length) dayAssignments[spread[i]] = d.id;
    });
  }

  return {
    id: `ai-${Date.now()}`,
    name: str(o.name, "Your plan"),
    description: str(o.description, "Built around your answers."),
    whyFitsParagraph: str(
      o.whyFitsParagraph,
      "Built from your goal, experience, available equipment and training days.",
    ),
    days: usable,
    dayAssignments,
  };
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed", code: "method" }, 405);
  }

  // --- 1. Authenticate ------------------------------------------------------
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: FRIENDLY.auth, code: "auth" }, 401);
  }
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) {
    return jsonResponse({ error: FRIENDLY.auth, code: "auth" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // --- 2. Input -------------------------------------------------------------
  let body: {
    action?: string;
    profile?: unknown;
    program?: unknown;
    instruction?: string;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body.", code: "bad_request" }, 400);
  }

  const action = body.action === "edit" ? "edit" : "generate";
  const instruction = (body.instruction ?? "").trim().slice(0, 500);
  if (action === "edit" && !instruction) {
    return jsonResponse({ error: "Tell Coach what to change.", code: "bad_request" }, 400);
  }

  // --- 3. Rate limiting -----------------------------------------------------
  // These MUST fail closed. The ledger is the only thing standing between a
  // scripted loop and an unbounded AI bill, so if it can't be read — migration
  // not applied, table dropped, database unreachable — we cannot prove this
  // user is under quota, and we refuse rather than assume they are.
  const { data: last, error: lastErr } = await admin
    .from("plan_requests")
    .select("created_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (lastErr) {
    console.error(
      `plan: cannot read plan_requests (${lastErr.code}: ${lastErr.message}). ` +
        `Run \`supabase db push\` to apply the plan_requests migration. ` +
        `Refusing the request rather than serving it unmetered.`,
    );
    return jsonResponse({ error: FRIENDLY.unavailable, code: "no_ledger" }, 503);
  }
  if (last?.created_at) {
    const elapsed = Date.now() - new Date(last.created_at as string).getTime();
    if (elapsed < COOLDOWN_SECONDS * 1000) {
      return jsonResponse({ error: FRIENDLY.cooldown, code: "cooldown" }, 429);
    }
  }

  const { data: used, error: usedErr } = await admin.rpc("plan_daily_usage", {
    p_user: user.id,
  });
  if (usedErr) {
    console.error(
      `plan: plan_daily_usage() unavailable (${usedErr.code}: ${usedErr.message}). ` +
        `Run \`supabase db push\`. Refusing rather than serving unmetered.`,
    );
    return jsonResponse({ error: FRIENDLY.unavailable, code: "no_ledger" }, 503);
  }
  if ((used ?? 0) >= DAILY_CAP) {
    return jsonResponse({ error: FRIENDLY.dailyCap, code: "daily_cap" }, 429);
  }

  if (!hasOpenRouterKey() && !hasAnthropicKey() && !hasGeminiKey()) {
    console.error(
      "plan: no AI key configured (OPENROUTER_API_KEY / ANTHROPIC_API_KEY / GEMINI_API_KEY)",
    );
    return jsonResponse({ error: FRIENDLY.unavailable, code: "missing_key" }, 503);
  }

  // --- 4. Build the prompt --------------------------------------------------
  const profileJson = JSON.stringify(body.profile ?? {});
  const userPrompt = action === "generate"
    ? `Build a weekly training program for this person.\n\nTheir answers ` +
      `(JSON):\n${profileJson}\n\nReturn the JSON object described in your ` +
      `instructions. Use exactly their chosen training days.`
    : `Here is the person's profile (JSON):\n${profileJson}\n\n` +
      `Here is their current program (JSON):\n${JSON.stringify(body.program ?? {})}\n\n` +
      `They asked: "${instruction}"\n\n` +
      `If that request is too vague or unfinished to act on, return the ` +
      `{"clarify": "..."} object instead — do NOT return the program unchanged ` +
      `with a note explaining why nothing changed. That is never a useful ` +
      `answer.\n\n` +
      `Otherwise apply the change and return the COMPLETE updated program as ` +
      `the JSON object described in your instructions. Keep everything they ` +
      `did not ask you to change. If the request would make the plan unsafe or ` +
      `unbalanced, do the closest sensible thing and say so in "note".`;

  // --- 5. Provider chain, [AI_PRIMARY] first --------------------------------
  let result: ProviderResult | null = null;

  const safe = (p: Promise<ProviderResult>) =>
    p.catch((e): ProviderResult => ({ ok: false, status: 0, detail: String(e) }));

  const attempts: Record<string, () => Promise<ProviderResult | null>> = {
    openrouter: async () => {
      if (!hasOpenRouterKey()) return null;
      const r = await safe(callOpenRouter(userPrompt));
      if (r.ok) return r;
      console.error(
        `plan: openrouter ${OPENROUTER_MODEL} failed (${r.status}): ${r.detail.slice(0, 500)}`,
      );
      return null;
    },
    anthropic: async () => {
      if (!hasAnthropicKey()) return null;
      const r = await safe(callAnthropic(userPrompt));
      if (r.ok) return r;
      console.error(`plan: anthropic failed (${r.status}): ${r.detail.slice(0, 500)}`);
      return null;
    },
    gemini: async () => {
      if (!hasGeminiKey()) return null;
      for (const model of GEMINI_MODELS) {
        const r = await safe(callGemini(userPrompt, model));
        if (r.ok) return r;
        console.error(`plan: gemini ${model} failed (${r.status}): ${r.detail.slice(0, 500)}`);
        // Auth/quota errors fail for every model — only retry a bad model id.
        if (r.status !== 404 && r.status !== 400) return null;
      }
      return null;
    },
  };

  if (!(AI_PRIMARY in attempts)) {
    console.error(
      `AI_PRIMARY="${AI_PRIMARY}" is not one of ${Object.keys(attempts).join(", ")} — ignoring`,
    );
  }
  const order = [
    AI_PRIMARY,
    ...Object.keys(attempts).filter((p) => p !== AI_PRIMARY),
  ];
  for (const name of order) {
    result = (await attempts[name]?.()) ?? null;
    if (result) break;
  }

  const logAttempt = (ok: boolean, provider: string | null) =>
    admin.from("plan_requests").insert({
      user_id: user.id,
      action,
      prompt: action === "edit" ? instruction : null,
      provider,
      ok,
    });

  if (!result) {
    await logAttempt(false, null);
    return jsonResponse({ error: FRIENDLY.unavailable, code: "provider" }, 503);
  }

  // --- 6. Validate before it ever reaches the app ---------------------------
  const parsed = extractJson(result.text);

  // Coach asking a question is a real answer, not a failure. Only honoured for
  // edits — there is no instruction to be ambiguous about when building a new
  // program, and a question there would strand the user mid-onboarding.
  const clarify = str((parsed as Record<string, unknown>)?.clarify).slice(0, 200);
  if (action === "edit" && clarify) {
    await logAttempt(true, result.provider);
    console.log(`plan action=edit provider=${result.provider} clarify`);
    return jsonResponse({ clarify, provider: result.provider });
  }

  const program = validateProgram(parsed);
  if (!program) {
    // Log enough to tell the two failure modes apart: a reply that got cut off
    // (raise MAX_TOKENS) versus one that came back well-formed but wrong
    // (prompt problem). The old log showed only the head, which looks
    // identical in both cases.
    const text = result.text;
    const looksTruncated = !text.trimEnd().endsWith("}");
    console.error(
      `plan: unusable model output (chars=${text.length}, ` +
        `truncated=${looksTruncated}, parsed=${parsed !== null})\n` +
        `head: ${text.slice(0, 400)}\ntail: ${text.slice(-200)}`,
    );
    await logAttempt(false, result.provider);
    return jsonResponse({ error: FRIENDLY.badPlan, code: "bad_plan" }, 502);
  }

  const note = str(
    (parsed as Record<string, unknown>)?.note,
    action === "edit" ? "Updated your plan." : "Built your plan.",
  );

  // Coach's professional opinion on the request, if it had one. Capped and
  // string-checked like everything else the model produces.
  const concern =
      str((parsed as Record<string, unknown>)?.concern).slice(0, 400);

  await logAttempt(true, result.provider);
  console.log(
    `plan action=${action} provider=${result.provider} ` +
      `days=${program.days.length} concern=${concern ? "yes" : "no"}`,
  );

  return jsonResponse({
    program,
    note,
    concern: concern ? concern : null,
    provider: result.provider,
  });
});
