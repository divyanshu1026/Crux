// ============================================================================
// Google Play Developer API — subscription verification
// ----------------------------------------------------------------------------
// Shared by `verify-purchase` (client hands us a token after checkout) and
// `play-rtdn` (Google tells us something changed). Both resolve the same way:
// ask Google what the subscription actually is. We never trust a state the
// caller reports — only a purchase token, which we then look up ourselves.
//
// Secrets:
//   GOOGLE_PLAY_SERVICE_ACCOUNT  the service account JSON, verbatim
//   ANDROID_PACKAGE_NAME         e.g. com.cruxapp.crux
// ============================================================================

const PACKAGE_NAME = (Deno.env.get("ANDROID_PACKAGE_NAME") ?? "com.cruxapp.crux").trim();
const SERVICE_ACCOUNT_RAW = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT") ?? "";

export function hasPlayCredentials(): boolean {
  return SERVICE_ACCOUNT_RAW.trim().length > 0;
}

/// What the rest of the system cares about, independent of Google's shape.
export interface PlaySubscription {
  productId: string;
  /// Lowercased Google state without the SUBSCRIPTION_STATE_ prefix:
  /// active | in_grace_period | on_hold | paused | canceled | expired | pending
  status: string;
  expiresAt: string | null;
  autoRenewing: boolean;
  /// True when this subscription should unlock Pro right now.
  entitled: boolean;
  /// Google's payload, kept for reconciliation.
  raw: unknown;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

let cachedToken: { value: string; expiresAt: number } | null = null;

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function encodeSegment(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

/// Turns the PEM in the service account JSON into a signing key.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (ch) => ch.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/// Service-account OAuth: sign a JWT with the private key, swap it for an
/// access token. Cached in module scope — a warm function reuses it rather
/// than paying the round trip on every purchase.
async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(SERVICE_ACCOUNT_RAW) as ServiceAccount;
  } catch {
    throw new Error("GOOGLE_PLAY_SERVICE_ACCOUNT is not valid JSON");
  }
  if (!sa.client_email || !sa.private_key) {
    throw new Error("GOOGLE_PLAY_SERVICE_ACCOUNT is missing client_email/private_key");
  }

  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${encodeSegment({ alg: "RS256", typ: "JWT" })}.${encodeSegment(claim)}`;
  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!resp.ok) {
    throw new Error(`Google token exchange failed (${resp.status}): ${await resp.text()}`);
  }
  const json = await resp.json() as { access_token: string; expires_in: number };
  cachedToken = {
    value: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedToken.value;
}

/// Looks up a purchase token. Throws on transport/auth problems; returns null
/// when Google says the token is not a real purchase (410/404), which is the
/// answer to "is this receipt forged?".
export async function fetchSubscription(
  purchaseToken: string,
): Promise<PlaySubscription | null> {
  const token = await accessToken();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(PACKAGE_NAME)}/purchases/subscriptionsv2/tokens/` +
    `${encodeURIComponent(purchaseToken)}`;

  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  // Three different failures that must not be conflated:
  //
  //   400/404/410 — Google knows this token isn't a purchase. Permanent, and
  //                 the user's problem to hear about ("not recognised").
  //   401/403     — *our* credentials are wrong: service account not invited
  //                 to the app in Play Console, permissions not propagated, or
  //                 the wrong package name. Nothing the user can do.
  //   anything else — transient; worth a retry.
  //
  // Reporting a forged receipt as "we couldn't reach Google Play, it will
  // restore automatically" told the user to wait for something that was never
  // going to happen, and buried a misconfiguration that looks identical.
  if (resp.status === 400 || resp.status === 404 || resp.status === 410) {
    console.warn(`play: token rejected by Google (${resp.status})`);
    return null;
  }
  if (resp.status === 401 || resp.status === 403) {
    const detail = await resp.text();
    console.error(
      `play: Google refused OUR credentials (${resp.status}). Check the ` +
        `service account is invited to ${PACKAGE_NAME} in Play Console with ` +
        `"Manage orders and subscriptions", and that ANDROID_PACKAGE_NAME is ` +
        `right. Detail: ${detail}`,
    );
    throw new Error(`Play API auth failed (${resp.status})`);
  }
  if (!resp.ok) {
    throw new Error(`Play API failed (${resp.status}): ${await resp.text()}`);
  }

  const data = await resp.json() as {
    subscriptionState?: string;
    lineItems?: {
      productId?: string;
      expiryTime?: string;
      autoRenewingPlan?: { autoRenewEnabled?: boolean };
    }[];
  };

  const line = data.lineItems?.[0] ?? {};
  const status = (data.subscriptionState ?? "")
    .replace(/^SUBSCRIPTION_STATE_/, "")
    .toLowerCase();
  const expiresAt = line.expiryTime ?? null;
  const stillPaidFor = expiresAt !== null && Date.parse(expiresAt) > Date.now();

  return {
    productId: line.productId ?? "",
    status: status || "unknown",
    expiresAt,
    autoRenewing: line.autoRenewingPlan?.autoRenewEnabled ?? false,
    // A cancelled subscription keeps its benefits until the period it was paid
    // for runs out — cutting someone off the moment they cancel is both wrong
    // and a refund request waiting to happen.
    entitled: status === "active" ||
      status === "in_grace_period" ||
      (status === "canceled" && stillPaidFor),
    raw: data,
  };
}
