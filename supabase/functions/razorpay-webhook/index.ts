// ============================================================================
// Crux — Edge Function: `razorpay-webhook`
// ----------------------------------------------------------------------------
// Receives Razorpay subscription webhooks, verifies the HMAC signature, logs
// the raw event, and flips profiles.is_pro. This is the swappable provider
// behind the client `BillingService` abstraction (plan §9, Phase 8). Store
// billing (Play/App Store) can post to a sibling function with the same shape.
//
// Razorpay maps the Crux user id into subscription `notes.user_id` at
// checkout, so we can resolve which profile to update.
//
// Secure this function with a verify header off (public) — Razorpay signs the
// body; we validate the signature ourselves.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "node:crypto";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;

// Events that grant Pro vs. revoke it.
const ACTIVATE_EVENTS = new Set([
  "subscription.activated",
  "subscription.charged",
  "subscription.resumed",
]);
const DEACTIVATE_EVENTS = new Set([
  "subscription.halted",
  "subscription.cancelled",
  "subscription.completed",
  "subscription.expired",
]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";

  // --- Verify HMAC signature (constant-time-ish compare) -------------------
  const expected = createHmac("sha256", RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  if (signature.length !== expected.length || signature !== expected) {
    console.warn("razorpay-webhook: invalid signature");
    return new Response("Invalid signature", { status: 401 });
  }

  let event: {
    event: string;
    payload?: { subscription?: { entity?: { id?: string; notes?: Record<string, string> } } };
  };
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("Bad payload", { status: 400 });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const sub = event.payload?.subscription?.entity;
  const userId = sub?.notes?.user_id ?? null;

  // Always log the raw event for auditing/reconciliation.
  await admin.from("billing_events").insert({
    user_id: userId,
    provider: "razorpay",
    event_type: event.event,
    external_id: sub?.id ?? null,
    payload: event,
  });

  // Apply the entitlement change if we can resolve the user.
  if (userId) {
    if (ACTIVATE_EVENTS.has(event.event)) {
      await admin.from("profiles").update({ is_pro: true }).eq("id", userId);
    } else if (DEACTIVATE_EVENTS.has(event.event)) {
      await admin.from("profiles").update({ is_pro: false }).eq("id", userId);
    }
  }

  // Ack quickly so Razorpay doesn't retry.
  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
