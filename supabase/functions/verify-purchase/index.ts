// ============================================================================
// Crux — Edge Function: `verify-purchase`
// ----------------------------------------------------------------------------
// The app finishes a Google Play checkout and sends us the purchase token.
// We ask Google what that token actually is, and only then grant Pro.
//
// This function is the entire paywall. Before it existed the client called
// `setPro(true)` on itself, which is exactly as strong as asking politely.
//
// Request:  POST { purchaseToken: string, productId?: string }
//           Authorization: Bearer <supabase user JWT>
// Response: { pro: boolean, expiresAt: string|null, status: string }
//
// Secrets: GOOGLE_PLAY_SERVICE_ACCOUNT, ANDROID_PACKAGE_NAME
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchSubscription, hasPlayCredentials } from "../_shared/google_play.ts";
import { applyEntitlement } from "../_shared/entitlement.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed", code: "method" }, 405);
  }

  // --- 1. Who is asking -----------------------------------------------------
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Sign in to complete your purchase.", code: "auth" }, 401);
  }
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return jsonResponse({ error: "Sign in to complete your purchase.", code: "auth" }, 401);
  }

  // --- 2. Input -------------------------------------------------------------
  let body: { purchaseToken?: string; productId?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body.", code: "bad_request" }, 400);
  }
  const purchaseToken = (body.purchaseToken ?? "").trim();
  if (!purchaseToken || purchaseToken.length > 4096) {
    return jsonResponse({ error: "Missing purchase token.", code: "bad_request" }, 400);
  }

  if (!hasPlayCredentials()) {
    // Operator problem: the function is deployed without its service account.
    // Never pretend the purchase worked — that grants Pro for free.
    console.error("verify-purchase: GOOGLE_PLAY_SERVICE_ACCOUNT is not set");
    return jsonResponse({
      error: "We can't confirm purchases right now. You have not been charged twice — " +
        "reopen the app shortly and it will restore automatically.",
      code: "unavailable",
    }, 503);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // --- 3. One token, one account -------------------------------------------
  // A receipt is proof that *someone* paid. Without this check, a leaked token
  // could be replayed from any number of accounts to mint free Pro.
  const { data: existing } = await admin
    .from("subscription_purchases")
    .select("user_id")
    .eq("provider", "google_play")
    .eq("purchase_token", purchaseToken)
    .maybeSingle();

  if (existing && existing.user_id !== user.id) {
    console.warn(
      `verify-purchase: token already bound to ${existing.user_id}, refused for ${user.id}`,
    );
    return jsonResponse({
      error: "This subscription is already linked to another Crux account. " +
        "Sign in with that account, or contact support.",
      code: "token_in_use",
    }, 409);
  }

  // --- 4. Ask Google --------------------------------------------------------
  let sub;
  try {
    sub = await fetchSubscription(purchaseToken);
  } catch (err) {
    console.error("verify-purchase: Play lookup failed", err);
    return jsonResponse({
      error: "We couldn't reach Google Play to confirm your purchase. " +
        "It will restore automatically once we can.",
      code: "upstream",
    }, 502);
  }

  if (!sub) {
    return jsonResponse({
      error: "Google Play doesn't recognise that purchase.",
      code: "invalid_token",
    }, 400);
  }

  // --- 5. Grant (or don't) --------------------------------------------------
  try {
    const result = await applyEntitlement(admin, user.id, sub, purchaseToken);
    return jsonResponse(result);
  } catch (err) {
    console.error("verify-purchase: entitlement write failed", err);
    return jsonResponse({
      error: "Your purchase went through but we couldn't save it. " +
        "Reopen the app and tap Restore — you will not be charged again.",
      code: "write_failed",
    }, 500);
  }
});
