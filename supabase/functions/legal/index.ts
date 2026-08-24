import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const PRIVACY_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crux — Privacy Policy</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    max-width: 720px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
    line-height: 1.6;
    color: #1b1b1f;
    background: #fff;
  }
  @media (prefers-color-scheme: dark) {
    body { color: #e7e7ea; background: #121114; }
    a { color: #ff8a5c; }
    table { border-color: #333 !important; }
    th, td { border-color: #333 !important; }
    hr { border-color: #333; }
  }
  h1 { font-size: 1.9rem; margin-bottom: 0.25rem; }
  h2 { font-size: 1.25rem; margin-top: 2.25rem; }
  .updated { color: #888; font-size: 0.9rem; margin-bottom: 1.5rem; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.95rem; }
  th, td { text-align: left; padding: 0.5rem 0.6rem; border: 1px solid #ddd; vertical-align: top; }
  th { background: rgba(128,128,128,0.08); }
  a { color: #d1541f; }
  hr { border: none; border-top: 1px solid #e2e2e2; margin: 2rem 0; }
  .short-version {
    background: rgba(128,128,128,0.08);
    border-radius: 10px;
    padding: 1rem 1.25rem;
  }
</style>
</head>
<body>

<h1>Crux — Privacy Policy</h1>
<p class="updated">Last updated: 3 August 2026</p>

<p>Crux ("we", "the app") is a gym training app. This policy explains exactly
what we store, why, and what we never collect. It is written to be read, not
to be survived.</p>

<p class="short-version"><strong>Short version:</strong> your training data
lives on your phone. If you sign in, it is also backed up to our server so you
can restore it on a new device. We do not sell your data, we do not run ads,
and we do not track you across other apps.</p>

<hr>

<h2>1. Who we are</h2>
<p>Crux is operated by the developer of the Crux app.<br>
Contact for privacy questions and data requests:
<a href="mailto:privacy@crux.app">privacy@crux.app</a></p>

<hr>

<h2>2. What we collect</h2>

<h3>2.1 Data you enter (the app's whole purpose)</h3>
<table>
<tr><th>Data</th><th>Why</th><th>Where it lives</th></tr>
<tr><td>Name or nickname</td><td>To address you in the app</td><td>Device + your account</td></tr>
<tr><td>Sex, date of birth / age, height, bodyweight</td><td>To calibrate starting weights, strength standards and calorie/protein targets</td><td>Device + your account</td></tr>
<tr><td>Training goal, experience level, available equipment, injuries you list</td><td>To generate and adjust your program safely</td><td>Device + your account</td></tr>
<tr><td>Workouts, sets, reps, weights, per-set notes, personal records</td><td>The core training log</td><td>Device + your account</td></tr>
<tr><td>Bodyweight log, optional body measurements</td><td>Progress tracking and nutrition targets</td><td>Device + your account</td></tr>
<tr><td>Water and protein entries</td><td>Daily habit tracking</td><td>Device + your account</td></tr>
<tr><td>Messages you send to the AI Coach</td><td>To answer them, and to review safety of AI responses</td><td>Device + your account</td></tr>
</table>

<h3>2.2 Account data</h3>
<p>If you create an account, we store your <strong>email address</strong> (or,
for Google/Apple sign-in, the identifier that provider returns) and an
authentication token. You can also use the app <strong>without an
account</strong>, fully offline — in that case nothing leaves your phone.</p>

<h3>2.3 Progress photos</h3>
<p>Progress photos you add <strong>stay on your device only</strong>. They are
never uploaded to our servers.</p>

<h3>2.4 What we do NOT collect</h3>
<ul>
  <li>We do not collect your precise location.</li>
  <li>We do not collect your contacts, calendar, call logs or SMS.</li>
  <li>We do not use advertising identifiers, and we show no ads.</li>
  <li>We do not track you across other apps or websites.</li>
  <li>We do not sell or rent your personal data to anyone. Ever.</li>
</ul>

<hr>

<h2>3. Permissions we ask for, and why</h2>
<table>
<tr><th>Permission</th><th>Why we ask</th><th>Optional?</th></tr>
<tr><td>Notifications</td><td>Rest-timer alerts, training-day and hydration reminders</td><td>Yes — the app works without it</td></tr>
<tr><td>Alarms &amp; reminders (exact alarms)</td><td>So the rest-timer alert fires on time when your screen is off mid-workout</td><td>Yes — falls back to approximate timing</td></tr>
<tr><td>Photos / media</td><td>Only when you choose to add a progress photo</td><td>Yes</td></tr>
<tr><td>Vibration</td><td>Haptic feedback when logging sets and when rest ends</td><td>—</td></tr>
</table>
<p>We only request a permission at the moment the related feature is used.</p>

<hr>

<h2>4. How your data is used</h2>
<p>We use your data solely to run the app for you:</p>
<ol>
  <li><strong>To generate and adapt your training program</strong> (progression, volume, rest).</li>
  <li><strong>To show your progress</strong> (charts, records, streaks, weekly summaries).</li>
  <li><strong>To answer your AI Coach questions.</strong> When you send a coach message, we
      send that message together with a summary of your own training data
      (profile, recent workouts, bodyweight trend, recent records) to our AI
      provider so the answer is personalised. See section 5.</li>
  <li><strong>To back up and restore your data</strong> across your devices, if you sign in.</li>
</ol>

<h3>4.1 Automatic backup</h3>
<p>When you are signed in, Crux backs up your training log, profile and
bodyweight history to your own account on a schedule you control in
<strong>Settings → Cloud backup</strong>:</p>
<ul>
  <li><strong>How often:</strong> daily, weekly (default), monthly, or every 3 months.</li>
  <li><strong>When:</strong> due after a time you choose — 02:00 by default, so a backup can
      never start in the middle of a workout.</li>
  <li><strong>Off:</strong> you can disable automatic backup entirely and back up manually.</li>
</ul>
<p>The upload goes only to your own account. If you are not signed in, nothing
is uploaded at all and the app remains fully local.</p>
<p>We do <strong>not</strong> use your data to build advertising profiles, and
we do not use your personal training data to train third-party AI models.</p>

<hr>

<h2>5. Third parties we share data with</h2>
<p>We keep this list as short as possible.</p>
<table>
<tr><th>Provider</th><th>What they receive</th><th>Purpose</th></tr>
<tr><td><strong>Supabase</strong> (database &amp; auth hosting)</td><td>Your account and the training data listed in 2.1</td><td>Storing your account and backup</td></tr>
<tr><td><strong>OpenRouter</strong> (AI routing)</td><td>Your coach message + a summary of your training data</td><td>Routing the request to a model provider</td></tr>
<tr><td><strong>The model provider</strong> (currently <strong>DeepSeek</strong>)</td><td>The same, passed on by OpenRouter</td><td>Generating the AI Coach reply or training plan</td></tr>
<tr><td><strong>Anthropic</strong> (Claude) and <strong>Google</strong> (Gemini)</td><td>The same, only when the primary provider is unavailable</td><td>Fallback so the coach still answers</td></tr>
</table>
<p>AI providers process your message to produce a response. We send only what
is needed to answer well, and we never send your email address, progress
photos, or precise identity to them. We ask these providers not to train on
your inputs.</p>
<p>Because we route through OpenRouter, the specific model answering you may
change over time. We name the current provider above and update this section
when it changes.</p>
<p>If you never use the AI Coach or ask Coach to build a plan, nothing is ever
sent to an AI provider.</p>

<hr>

<h2>6. How long we keep data</h2>
<ul>
  <li><strong>While your account exists:</strong> we keep your data so you can use and restore it.</li>
  <li><strong>When you delete your account:</strong> we delete your account and its data from our
      servers. Deletion is immediate and permanent.</li>
  <li><strong>Local data:</strong> stays on your device until you clear it, delete your account,
      or uninstall the app.</li>
  <li><strong>Payment records:</strong> if you ever purchase a subscription, we keep transaction
      records (without linking them to your deleted account) for as long as tax and
      accounting law requires.</li>
</ul>

<hr>

<h2>7. Deleting your data</h2>
<p>You are in control, from inside the app:</p>
<ul>
  <li><strong>Settings → Clear data on this device</strong> — wipes everything locally and signs
      you out. Any cloud backup is untouched.</li>
  <li><strong>Settings → Delete my account</strong> — permanently deletes your account and <strong>all</strong>
      associated data from our servers, then wipes this device.</li>
  <li><strong>Settings → Automatic backup</strong> — controls what is uploaded and how often,
      and can be switched off.</li>
</ul>
<p>You can also email <a href="mailto:privacy@crux.app">privacy@crux.app</a>
from your account's email address to request deletion, or to request a copy of
your data in a portable format, and we will action it within 30 days.</p>

<hr>

<h2>8. Your rights</h2>
<p>Depending on where you live (for example the EEA/UK under GDPR, or
California under CCPA/CPRA), you have the right to access, correct, export, or
delete your personal data, to object to or restrict certain processing, and to
complain to your data protection authority. The in-app delete tools cover
erasure instantly; for a copy of your data, or anything else, email
<a href="mailto:privacy@crux.app">privacy@crux.app</a> and we will respond
within 30 days.</p>
<p>We do not "sell" or "share" personal information as those terms are defined
under California law.</p>

<hr>

<h2>9. Security</h2>
<p>Data in transit is encrypted with TLS. Data on our servers is stored with
per-user access rules, so one account cannot read another's rows. AI provider
keys are held only on our server and are never shipped inside the app. No
system is perfectly secure, but we keep the amount of data we hold
deliberately small.</p>

<hr>

<h2>10. Children</h2>
<p>Crux is not intended for children under 13 (or the minimum age of digital
consent in your country). We do not knowingly collect data from children. If
you believe a child has provided us data, email
<a href="mailto:privacy@crux.app">privacy@crux.app</a> and we will delete it.</p>

<hr>

<h2>11. Health disclaimer</h2>
<p>Crux provides general fitness information and AI-generated training
guidance. It is <strong>not</strong> medical, dietetic, or physiotherapy
advice, and it is not a substitute for a qualified professional. Consult a
professional before starting a new exercise or nutrition programme, and stop
exercising if you experience pain.</p>

<hr>

<h2>12. Changes to this policy</h2>
<p>If we make a material change, we will update the "Last updated" date above
and notify you in the app before the change takes effect.</p>

<hr>

<h2>13. Contact</h2>
<p><a href="mailto:privacy@crux.app">privacy@crux.app</a></p>

<hr>
<p><a href="terms-of-use.html">Terms of Use</a> ·
   <a href="account-deletion.html">Delete your account →</a></p>

</body>
</html>`;

const TERMS_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crux — Terms of Use</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    max-width: 720px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
    line-height: 1.6;
    color: #1b1b1f;
    background: #fff;
  }
  @media (prefers-color-scheme: dark) {
    body { color: #e7e7ea; background: #121114; }
    a { color: #ff8a5c; }
    hr { border-color: #333; }
    .callout { background: rgba(255,138,92,0.12) !important; }
  }
  h1 { font-size: 1.9rem; margin-bottom: 0.25rem; }
  h2 { font-size: 1.25rem; margin-top: 2.25rem; }
  .updated { color: #888; font-size: 0.9rem; margin-bottom: 1.5rem; }
  a { color: #d1541f; }
  hr { border: none; border-top: 1px solid #e2e2e2; margin: 2rem 0; }
  .callout {
    background: rgba(209,84,31,0.08);
    border-left: 3px solid #d1541f;
    border-radius: 6px;
    padding: 0.9rem 1.1rem;
    margin: 1rem 0;
  }
  ul { padding-left: 1.3rem; }
  li { margin-bottom: 0.4rem; }
</style>
</head>
<body>

<h1>Crux — Terms of Use</h1>
<p class="updated">Last updated: 3 August 2026</p>

<p class="callout">Crux is a training log and coaching aid, not a medical
service. Train within your own limits, and stop if something hurts.</p>

<hr>

<h2>1. Agreement</h2>
<p>By using Crux you agree to these terms. If you do not agree, please stop
using the app and delete it.</p>

<h2>2. Who can use Crux</h2>
<p>You must be at least 13 years old, or the minimum age of digital consent in
your country, whichever is higher. If you are under 18, use Crux with the
involvement of a parent or guardian.</p>

<h2>3. Your account</h2>
<ul>
  <li>Keep your login credentials secure. You are responsible for activity under your account.</li>
  <li>You do not need an account to use the basic training log; offline mode works without one.</li>
  <li>You can delete your account and all associated data at any time from within the app or by emailing <a href="mailto:privacy@crux.app">privacy@crux.app</a>.</li>
</ul>

<h2>4. Training &amp; Health Disclaimer</h2>
<p>Weight training carries inherent risks. The suggestions, weights, and progressions Crux computes are mathematical models, not medical prescriptions. Always use safe technique, appropriate safety equipment (e.g. collars, spotter arms), and listen to your body.</p>

<h2>5. AI Coach</h2>
<p>The AI Coach uses automated natural language models. While designed to be safe and conservative, AI outputs may occasionally contain errors. Never rely on the AI Coach for acute injury triage or emergency medical advice.</p>

<h2>6. Subscriptions &amp; Billing</h2>
<p>Crux Pro subscriptions are billed through Google Play Billing (or Apple App Store). Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription at any time in the Google Play Store / App Store settings.</p>

<h2>7. Contact</h2>
<p>Questions about these terms: <a href="mailto:privacy@crux.app">privacy@crux.app</a></p>

<hr>
<p><a href="privacy-policy.html">Privacy Policy</a> ·
   <a href="account-deletion.html">Delete your account →</a></p>

</body>
</html>`;

const ACCOUNT_DELETION_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crux — Delete Your Account</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    max-width: 640px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
    line-height: 1.6;
    color: #1b1b1f;
    background: #fff;
  }
  @media (prefers-color-scheme: dark) {
    body { color: #e7e7ea; background: #121114; }
    a { color: #ff8a5c; }
    hr { border-color: #333; }
    input { background: #1c1b1f !important; color: #e7e7ea !important; border-color: #3a393f !important; }
    .callout { background: rgba(255,138,92,0.12) !important; }
    .card { background: #19181b !important; border-color: #2c2b30 !important; }
  }
  h1 { font-size: 1.7rem; margin-bottom: 0.25rem; }
  h2 { font-size: 1.1rem; margin-top: 0; }
  a { color: #d1541f; }
  hr { border: none; border-top: 1px solid #e2e2e2; margin: 2rem 0; }
  .callout {
    background: rgba(209,84,31,0.08);
    border-left: 3px solid #d1541f;
    border-radius: 6px;
    padding: 0.9rem 1.1rem;
    margin: 1rem 0;
    font-size: 0.95rem;
  }
  .card {
    background: rgba(128,128,128,0.06);
    border: 1px solid rgba(128,128,128,0.2);
    border-radius: 12px;
    padding: 1.25rem 1.4rem;
    margin: 1.25rem 0;
  }
  label { display: block; font-size: 0.9rem; font-weight: 600; margin: 0.9rem 0 0.3rem; }
  input {
    width: 100%;
    box-sizing: border-box;
    padding: 0.6rem 0.7rem;
    border-radius: 8px;
    border: 1px solid #ccc;
    font-size: 1rem;
  }
  button {
    width: 100%;
    margin-top: 1.25rem;
    padding: 0.75rem;
    border: none;
    border-radius: 8px;
    background: #d1541f;
    color: #fff;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
  }
  button:disabled { opacity: 0.6; cursor: not-allowed; }
  .status { margin-top: 1rem; padding: 0.75rem; border-radius: 8px; display: none; }
  .status.error { background: rgba(220,53,69,0.15); color: #dc3545; display: block; }
  .status.success { background: rgba(40,167,69,0.15); color: #28a745; display: block; }
  .status.pending { background: rgba(255,193,7,0.15); color: #856404; display: block; }
</style>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
</head>
<body>

<h1>Crux — Delete Your Account &amp; Data</h1>

<p>In accordance with Google Play and Apple requirements, you can permanently delete your Crux account and all associated personal data from this web page without needing the app installed.</p>

<div class="callout">
  <strong>⚠️ Warning:</strong> Account deletion is immediate and cannot be undone. All your backed-up workouts, personal records, body measurements, and AI coaching history will be permanently erased.
</div>

<div class="card">
  <h2>Delete with Email &amp; Password</h2>
  <p style="font-size:0.9rem; color:#888;">If your account was created with email and password, enter your credentials below to authenticate and delete all data:</p>

  <form id="delete-form">
    <label for="email">Email Address</label>
    <input type="email" id="email" required autocomplete="email" placeholder="you@example.com">

    <label for="password">Password</label>
    <input type="password" id="password" required autocomplete="current-password" placeholder="••••••••">

    <button type="submit" id="submit-btn">Permanently Delete Account &amp; All Data</button>
  </form>

  <div id="status" class="status"></div>
</div>

<div class="card">
  <h2>Google or Apple Sign-In Accounts</h2>
  <p style="font-size:0.9rem; color:#888;">If you signed in using Google or Apple (no password set), you can delete your account directly inside the Crux app under <strong>Settings → Delete my account</strong>, or email us at <a href="mailto:privacy@crux.app">privacy@crux.app</a> from the account's email address and we will process the deletion within 48 hours.</p>
</div>

<hr>
<p><a href="privacy-policy.html">Privacy Policy</a> · <a href="terms-of-use.html">Terms of Use</a></p>

<script>
  const SUPABASE_URL = "https://ryklcllmzkpaxxpbsitg.supabase.co";
  const SUPABASE_ANON_KEY = "sb_publishable_aEyoZCvFj0ZCWct6dCOCRw_ClP3_7ww";
  const client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const form = document.getElementById("delete-form");
  const statusDiv = document.getElementById("status");
  const submitBtn = document.getElementById("submit-btn");

  function setStatus(type, msg) {
    statusDiv.className = "status " + type;
    statusDiv.textContent = msg;
    statusDiv.style.display = "block";
  }

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    submitBtn.disabled = true;
    setStatus("pending", "Authenticating...");

    const email = document.getElementById("email").value.trim();
    const password = document.getElementById("password").value;

    try {
      const { data, error } = await client.auth.signInWithPassword({ email, password });
      if (error || !data.session) {
        setStatus("error", "Invalid email or password. If you signed in via Google/Apple, please delete from inside the app or email privacy@crux.app.");
        submitBtn.disabled = false;
        return;
      }

      setStatus("pending", "Deleting all account data...");
      const res = await fetch(SUPABASE_URL + "/functions/v1/delete-account", {
        method: "POST",
        headers: {
          "Authorization": "Bearer " + data.session.access_token,
          "apikey": SUPABASE_ANON_KEY,
          "Content-Type": "application/json",
        },
      });

      if (res.ok) {
        form.style.display = "none";
        setStatus("success", "Done! Your Crux account and all associated data have been permanently deleted.");
      } else {
        const err = await res.json().catch(() => ({}));
        setStatus("error", err.error || "Failed to delete account. Please email privacy@crux.app.");
        submitBtn.disabled = false;
      }
    } catch (err) {
      setStatus("error", "Error connecting to server. Please try again or email privacy@crux.app.");
      submitBtn.disabled = false;
    }
  });
</script>

</body>
</html>`;

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname.toLowerCase();
  const doc = url.searchParams.get("doc");

  let html = PRIVACY_HTML;

  if (
    path.includes("terms") ||
    path.includes("terms-of-use") ||
    doc === "terms"
  ) {
    html = TERMS_HTML;
  } else if (
    path.includes("delete") ||
    path.includes("account-deletion") ||
    doc === "delete" ||
    doc === "deletion"
  ) {
    html = ACCOUNT_DELETION_HTML;
  } else if (
    path.includes("privacy") ||
    path.includes("privacy-policy") ||
    doc === "privacy"
  ) {
    html = PRIVACY_HTML;
  }

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
      "X-Content-Type-Options": "nosniff",
    },
  });
});
