// Shared CORS headers for Crux Edge Functions.
// The Flutter app calls these from mobile (no Origin) and, in dev, from the
// Supabase Studio / web; `*` is safe here because every function still
// authenticates the caller via the Supabase JWT.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
