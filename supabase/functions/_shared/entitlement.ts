// ============================================================================
// Writing a Pro entitlement.
//
// One place, used by both billing entry points (checkout verification and
// Google's renewal notifications), because an entitlement written two slightly
// different ways is how "I paid and it says I'm not Pro" tickets are born.
// ============================================================================

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { PlaySubscription } from "./google_play.ts";

export interface EntitlementResult {
  pro: boolean;
  expiresAt: string | null;
  status: string;
}

/// Records the purchase and sets the profile's entitlement to match.
///
/// [userId] is resolved by the caller — from the caller's JWT on checkout, or
/// from the stored purchase row on a renewal notification. It is never taken
/// from the client's request body.
export async function applyEntitlement(
  admin: SupabaseClient,
  userId: string,
  sub: PlaySubscription,
  purchaseToken: string,
  provider = "google_play",
): Promise<EntitlementResult> {
  const { error: purchaseErr } = await admin
    .from("subscription_purchases")
    .upsert({
      user_id: userId,
      provider,
      product_id: sub.productId,
      purchase_token: purchaseToken,
      status: sub.status,
      expires_at: sub.expiresAt,
      auto_renewing: sub.autoRenewing,
      raw: sub.raw,
      updated_at: new Date().toISOString(),
    }, { onConflict: "provider,purchase_token" });

  if (purchaseErr) {
    // Worth shouting about: the entitlement may still be written below, but
    // we have lost the audit trail for it.
    console.error("entitlement: purchase upsert failed", purchaseErr);
  }

  const { error: profileErr } = await admin
    .from("profiles")
    .update({
      is_pro: sub.entitled,
      pro_expires_at: sub.expiresAt,
      billing_provider: provider,
      billing_subscription_id: sub.productId || null,
    })
    .eq("id", userId);

  if (profileErr) {
    console.error("entitlement: profile update failed", profileErr);
    throw new Error("Could not save the entitlement");
  }

  console.log(
    `entitlement user=${userId} product=${sub.productId} ` +
      `status=${sub.status} pro=${sub.entitled} expires=${sub.expiresAt}`,
  );

  return { pro: sub.entitled, expiresAt: sub.expiresAt, status: sub.status };
}
