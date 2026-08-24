// ============================================================================
// Crux — Edge Function: `delete-account`
// ----------------------------------------------------------------------------
// Google Play's User Data policy requires any app that lets people create an
// account to also let them request deletion of that account AND the data tied
// to it, from inside the app. This is that endpoint.
//
// It deletes the caller's own account only — identity comes from the verified
// JWT, never from the request body, so one user can't delete another.
//
// Order matters: rows first, auth user last. If anything fails midway the
// account still exists and the client can retry; deleting the auth user first
// would orphan rows that RLS then makes unreachable.
//
// Most tables are ON DELETE CASCADE from auth.users, so the explicit sweep is
// belt-and-braces for anything added later without a cascade.
//
// Request:  POST (no body needed)
// Response: { deleted: true } | { error, code }
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Every table holding user-owned rows, keyed by user_id.
const USER_TABLES = [
  "set_logs",
  "workouts",
  "programs",
  "body_logs",
  "prs",
  "quests",
  "xp_events",
  "rank_signals",
  "promotions",
  "protein_logs",
  "chat_messages",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed", code: "method" }, 405);
  }

  // --- Authenticate: the JWT is the only source of identity ----------------
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Sign in first.", code: "auth" }, 401);
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();
  if (userErr || !user) {
    return jsonResponse({ error: "Session expired. Sign in again.", code: "auth" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const uid = user.id;

  try {
    // 1. Friendships reference the user from either side.
    await admin
      .from("friendships")
      .delete()
      .or(`user_id.eq.${uid},friend_id.eq.${uid}`);

    // 2. All straightforward user-owned rows.
    for (const table of USER_TABLES) {
      const { error } = await admin.from(table).delete().eq("user_id", uid);
      // A missing table (feature not migrated yet) must not block deletion.
      if (error && !/does not exist/i.test(error.message)) {
        console.error(`delete-account: ${table} failed`, error);
        return jsonResponse(
          { error: "Couldn't delete everything. Try again.", code: "partial" },
          500,
        );
      }
    }

    // 3. Billing history is kept but de-identified — we must not retain a
    //    link to a deleted person, and payment records have their own
    //    retention obligations.
    await admin.from("billing_events").update({ user_id: null }).eq("user_id", uid);

    // 4. Profile row.
    await admin.from("profiles").delete().eq("id", uid);

    // 5. Finally the auth identity itself (this also revokes all sessions).
    const { error: authDeleteErr } = await admin.auth.admin.deleteUser(uid);
    if (authDeleteErr) {
      console.error("delete-account: auth user delete failed", authDeleteErr);
      return jsonResponse(
        { error: "Couldn't finish deleting the account. Try again.", code: "auth_delete" },
        500,
      );
    }

    console.log(`delete-account: completed for ${uid}`);
    return jsonResponse({ deleted: true });
  } catch (err) {
    console.error("delete-account: unexpected", err);
    return jsonResponse(
      { error: "Something went wrong. Try again in a moment.", code: "unknown" },
      500,
    );
  }
});
