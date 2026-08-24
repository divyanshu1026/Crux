// ============================================================================
// Crux — Edge Function: `play-rtdn`
// ----------------------------------------------------------------------------
// Google Play Real-time Developer Notifications, delivered by Cloud Pub/Sub.
//
// Without this, `verify-purchase` grants Pro at checkout and nothing ever takes
// it away: renewals, cancellations, refunds, expiries and account holds all
// happen on Google's side, silently. Someone who subscribes once keeps Pro
// forever, and someone who is refunded keeps it too.
//
// Pub/Sub push delivers { message: { data: <base64 JSON> } }. We decode it for
// the purchase token only — every state decision is re-fetched from Google, so
// a forged notification can't grant anything.
//
// Deploy with --no-verify-jwt (Pub/Sub can't send a Supabase JWT) and set
// RTDN_SHARED_SECRET, then subscribe with the URL ?secret=<same value>.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fetchSubscription, hasPlayCredentials } from "../_shared/google_play.ts";
import { applyEntitlement } from "../_shared/entitlement.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RTDN_SHARED_SECRET = (Deno.env.get("RTDN_SHARED_SECRET") ?? "").trim();

/// Pub/Sub retries anything that isn't a 2xx, forever, with backoff. A 200 on
/// "I can't do anything with this" is deliberate: it stops a poison message
/// from looping, and the log line is how we notice.
const ACK = new Response(JSON.stringify({ received: true }), {
  status: 200,
  headers: { "Content-Type": "application/json" },
});

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (RTDN_SHARED_SECRET) {
    const provided = new URL(req.url).searchParams.get("secret") ?? "";
    if (provided !== RTDN_SHARED_SECRET) {
      console.warn("play-rtdn: bad or missing shared secret");
      return new Response("Forbidden", { status: 403 });
    }
  }

  let envelope: { message?: { data?: string } };
  try {
    envelope = await req.json();
  } catch {
    console.warn("play-rtdn: unparseable envelope");
    return ACK;
  }

  const encoded = envelope.message?.data;
  if (!encoded) {
    // Pub/Sub sends a test message with no data when you create the
    // subscription. Acknowledge it so the topic validates.
    console.log("play-rtdn: empty message (topic test?)");
    return ACK;
  }

  let notification: {
    subscriptionNotification?: { notificationType?: number; purchaseToken?: string };
    voidedPurchaseNotification?: { purchaseToken?: string };
    testNotification?: unknown;
  };
  try {
    notification = JSON.parse(atob(encoded));
  } catch {
    console.warn("play-rtdn: message data is not JSON");
    return ACK;
  }

  if (notification.testNotification) {
    console.log("play-rtdn: test notification received — wiring is good");
    return ACK;
  }

  const purchaseToken = notification.subscriptionNotification?.purchaseToken ??
    notification.voidedPurchaseNotification?.purchaseToken;
  if (!purchaseToken) {
    console.log("play-rtdn: notification carries no purchase token, ignoring");
    return ACK;
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Which account this token belongs to was decided at checkout. Notifications
  // never carry a user id, and we would not trust one if they did.
  const { data: purchase } = await admin
    .from("subscription_purchases")
    .select("user_id")
    .eq("provider", "google_play")
    .eq("purchase_token", purchaseToken)
    .maybeSingle();

  if (!purchase) {
    // A renewal can genuinely arrive before the app finishes checkout. The
    // next verify-purchase call will pick up the current state anyway.
    console.warn("play-rtdn: no local purchase for this token yet");
    return ACK;
  }

  // A voided (refunded/charged-back) purchase revokes Pro outright, whatever
  // the subscription record says.
  if (notification.voidedPurchaseNotification) {
    await admin
      .from("profiles")
      .update({ is_pro: false, pro_expires_at: null })
      .eq("id", purchase.user_id);
    await admin
      .from("subscription_purchases")
      .update({ status: "voided", updated_at: new Date().toISOString() })
      .eq("provider", "google_play")
      .eq("purchase_token", purchaseToken);
    console.log(`play-rtdn: voided purchase, Pro revoked for ${purchase.user_id}`);
    return ACK;
  }

  if (!hasPlayCredentials()) {
    console.error("play-rtdn: GOOGLE_PLAY_SERVICE_ACCOUNT is not set");
    return ACK;
  }

  try {
    const sub = await fetchSubscription(purchaseToken);
    if (!sub) {
      console.warn("play-rtdn: Google no longer recognises this token");
      return ACK;
    }
    await applyEntitlement(admin, purchase.user_id, sub, purchaseToken);
  } catch (err) {
    // Here a retry genuinely helps — Google was unreachable, not wrong.
    console.error("play-rtdn: refresh failed, asking Pub/Sub to retry", err);
    return new Response("Retry", { status: 500 });
  }

  return ACK;
});
