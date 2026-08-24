# Crux — Release runbook (Google Play)

Everything needed to go from this repo to a live listing. Steps marked
**[you]** need a human — an account, a password, or a device.

---

## 0. One-time setup

### 0.1 Create the upload keystore **[you]**

**Do this before your first build.** Without it Play rejects the upload with
*"You uploaded an APK or Android App Bundle that was signed in debug mode."*

Easiest path — one command from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File tool\setup_signing.ps1
```

It finds `keytool`, asks for a password, creates `%USERPROFILE%\crux-upload.jks`
and writes `android/key.properties` (both git-ignored).

<details>
<summary>Manual alternative</summary>

`keytool` ships with the JDK; if it isn't on PATH, Android Studio bundles one at
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

```bash
keytool -genkey -v -keystore %USERPROFILE%\crux-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias crux
```

Then copy `android/key.properties.example` → `android/key.properties` and fill
in the four values.
</details>

> ⚠️ **Back up the `.jks` file and its password.** It is not in this repo by
> design. With Play App Signing a lost upload key can be reset via Google
> support, but keep it safe regardless.

Building an App Bundle without `android/key.properties` now **fails the build**
with instructions, rather than producing a debug-signed file that only Play
rejects minutes later.

### 0.1b Enable Google sign-in **[you]**

The app supports Google sign-in, but the button **only appears when the
Supabase project actually has the provider switched on** — it asks
`/auth/v1/settings` on launch. A visible button for a disabled provider doesn't
fail politely; it opens a browser page reading *"Unsupported provider: provider
is not enabled"*, which reads as a broken app. Enable it and the button returns
by itself, with no app update.

Check the current state any time:

```bash
curl -s -H "apikey: <anon-key>" https://ryklcllmzkpaxxpbsitg.supabase.co/auth/v1/settings
```

`"google": false` → not enabled yet. To turn it on:

1. **Google Cloud Console** → the same project you used for Play billing →
   **APIs & Services → OAuth consent screen**. External, fill in app name,
   support email, and the privacy-policy URL from §0.2. Add yourself as a test
   user while it's unverified.
2. **Credentials → Create credentials → OAuth client ID → Web application.**
   Not "Android" — the app signs in through the browser, so Supabase is the
   OAuth client, and a native Android client would need a SHA-1 we don't use.
   Under **Authorised redirect URIs** add exactly:

   ```
   https://ryklcllmzkpaxxpbsitg.supabase.co/auth/v1/callback
   ```

3. **Supabase → Authentication → Providers → Google**: enable, paste the
   **Client ID** and **Client secret** from step 2, save.
4. **Supabase → Authentication → URL Configuration → Redirect URLs**: add

   ```
   io.supabase.crux://login-callback/
   ```

   This is the deep link the Android app returns through; it's already
   registered in `AndroidManifest.xml`. Without it Google sends the user back
   to a URL Supabase refuses, and sign-in dies on the last step.
5. Re-run the curl above — `"google": true` — and the button is back.

Sign-in through the browser cannot be tested in the web preview or with a
sideloaded debug build unless the redirect URL matches; test it on the
internal-testing build.

### 0.2 Privacy policy **[you]**

**In-app: already done.** The policy and terms ship inside the binary
(`lib/features/legal/domain/legal_docs.dart`), reachable from Settings → About
and from the sign-in screen. No domain, no hosting, works offline, and always
matches the installed build.

**Play Console: still needs a public URL.** The App content → Privacy policy
field only accepts a reachable URL — an in-app screen cannot satisfy it. You do
not need a domain for this.

**Recommended — Supabase Legal Edge Function (Live & Rendering):**

Three ready-to-use, dark-mode aware pages served with `Content-Type: text/html`:

- `https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/legal/privacy` — Privacy Policy
- `https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/legal/terms` — Terms of Use
- `https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/legal/account-deletion` — Account Deletion (satisfies Play Console Data deletion)

Paste these URLs into **two separate places** in Google Play Console:
1. **App content → Privacy policy → Privacy policy URL** → `https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/legal/privacy`
2. **App content → Data deletion** → `https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/legal/account-deletion`, then answer:
   - *can a user request deletion without the app installed* → Yes
   - *is all data deleted, not just account-essential data* → Yes

Keep `store/PRIVACY_POLICY.md` in sync with `legal_docs.dart` whenever either
changes.

Also set up the `privacy@crux.app` inbox, **or** change the address in both
`legal_docs.dart` and `store/PRIVACY_POLICY.md` to one you actually read —
right now that address does not exist, and Play requires a working contact for
data requests.

### 0.3 Deploy the backend **[you]**

```bash
supabase link --project-ref ryklcllmzkpaxxpbsitg
supabase db push                                    # migrations, incl. plan_requests + workout backup
supabase functions deploy coach
supabase functions deploy plan                      # AI program build + schedule edits
supabase functions deploy delete-account            # REQUIRED by Play policy
supabase functions deploy verify-purchase           # Pro subscriptions — grants entitlement
supabase functions deploy play-rtdn --no-verify-jwt # renewals, cancels, refunds
supabase functions deploy razorpay-webhook --no-verify-jwt
```

Billing needs its own secrets and a Play Console setup — the full sequence is in
[`store/BILLING_SETUP.md`](store/BILLING_SETUP.md):

```bash
supabase secrets set ANDROID_PACKAGE_NAME=com.cruxapp.crux
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
supabase secrets set RTDN_SHARED_SECRET=<random>
```

**Smoke-test the service account before you ship** (needs a signed-in user's
JWT — copy it from the app's local storage in the web preview):

```bash
curl -s -X POST https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/verify-purchase \
  -H "Authorization: Bearer <user-jwt>" -H "Content-Type: application/json" \
  -d '{"purchaseToken":"not-a-real-token","productId":"crux_pro_annual"}'
```

- `{"code":"invalid_token"}` → **correct**: Google was reached and rejected a
  fake receipt. Billing is wired.
- `{"code":"unavailable"}` → `GOOGLE_PLAY_SERVICE_ACCOUNT` isn't set.
- `{"code":"upstream"}` → Google refused *our* credentials. The service account
  isn't invited to the app in Play Console, its permissions haven't propagated
  (can take hours), or `ANDROID_PACKAGE_NAME` is wrong. The function logs say
  which.

Check all three are live (`401` = deployed, `404` = missing):

```bash
for f in coach plan delete-account; do printf "%-16s " $f; curl -s -o /dev/null -w "%{http_code}\n" -X POST https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/$f; done
```

Secrets (server-side only — never in the app):

```bash
supabase secrets set OPENROUTER_API_KEY=sk-or-...
```

That is all you need. `coach` and `plan` both default to OpenRouter with
`deepseek/deepseek-v4-flash`.

Optional, and only if you want to change something:

```bash
supabase secrets set OPENROUTER_MODEL=deepseek/deepseek-v4-pro  # different model
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...               # adds a fallback
supabase secrets set GEMINI_API_KEY=AIza...                     # adds a fallback
supabase secrets set AI_PRIMARY=anthropic                       # promote a fallback
```

**How the chain works.** Both functions try `AI_PRIMARY` first (default
`openrouter`), then every other provider that has a key, in order. A provider
with no key is skipped silently. So:

- Adding `ANTHROPIC_API_KEY` makes Claude a **backup** — it costs nothing until
  OpenRouter fails.
- To make Claude the primary later, set `AI_PRIMARY=anthropic`. No code change,
  no redeploy of the app — just `supabase secrets set` and the functions pick it
  up on the next invocation.

⚠️ Changing the AI provider is a **privacy-policy change**. Section 5 of both
`store/PRIVACY_POLICY.md` and `lib/features/legal/domain/legal_docs.dart` names
who receives coach messages. Keep them accurate — Play's Data Safety
declaration has to match.

**`delete-account` is not optional.** Until it is deployed, Settings → Delete my
account fails — the endpoint 404s and the app (correctly) refuses to pretend the
data is gone. Check it is live:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://ryklcllmzkpaxxpbsitg.supabase.co/functions/v1/delete-account
```

`401` = deployed (it rejected an unauthenticated call, which is right).
`404` = not deployed — run `supabase functions deploy delete-account`.

**Then verify it end-to-end before you submit** — Play tests it: sign in on a
throwaway account, Settings → Delete my account, then confirm in Supabase →
Table editor that the `profiles` row and the auth user are gone.

---

## 1. Pre-flight checks

```bash
flutter clean
flutter pub get
flutter analyze          # must be 0 errors, 0 warnings
flutter test             # must be all green
```

Bump the version in `pubspec.yaml` for every upload — Play rejects a reused
`versionCode`:

```yaml
version: 1.0.0+1      # <major.minor.patch>+<versionCode>
#              ^ increment this every single upload
```

---

## 2. Build the App Bundle

Play requires an **`.aab`**, not an APK. The Supabase URL and anon key are
compile-time constants, so they must be passed here or the app ships with the
cloud layer switched off (it will still run, fully local — but no sync, no AI):

```bash
flutter build appbundle --release ^
  --dart-define=SUPABASE_URL=https://ryklcllmzkpaxxpbsitg.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_aEyoZCvFj0ZCWct6dCOCRw_ClP3_7ww
```
*(PowerShell/CMD line-continuation is `^`; on macOS/Linux use `\`.)*

Output: `build/app/outputs/bundle/release/app-release.aab`

The anon key is safe to ship — it is public by design and Row Level Security is
what actually protects the data.

### Confirm the bundle is release-signed (10 seconds, saves a failed upload)

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Look at the **Owner** line:
- `CN=Crux, OU=Crux, ...` → ✅ correctly release-signed, upload it
- `CN=Android Debug, O=Android, C=US` → ❌ still debug-signed; `key.properties`
  is missing or wasn't picked up. Re-run `tool\setup_signing.ps1`, then
  `flutter clean` and rebuild.

### Test the exact release build on a real device first

```bash
flutter build apk --release ^
  --dart-define=SUPABASE_URL=https://ryklcllmzkpaxxpbsitg.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_aEyoZCvFj0ZCWct6dCOCRw_ClP3_7ww
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release builds are minified (R8) and behave differently from debug. **Smoke-test
these specifically**, since they're the things obfuscation can break:

- [ ] App launches; splash matches the theme (no white flash)
- [ ] Sign up → onboarding → program generated
- [ ] Log a set; rest timer starts
- [ ] Lock the screen mid-rest → notification rings on time
- [ ] Reopen mid-rest → countdown resumed correctly (not reset)
- [ ] Background the app mid-rest → notification fires **without** reopening
- [ ] Leave the workout screen and come back → session clock kept counting
- [ ] Settings → Automatic backup: change frequency and time, both persist
- [ ] Finish a workout → summary + PR celebration
- [ ] AI Coach answers (needs Anthropic credits or the Gemini fallback)
- [ ] Settings → Delete my account actually deletes server rows
- [ ] Kill and relaunch → data still there

**Purchases can't be tested this way.** A sideloaded APK has no Play licence
context, so the paywall will show "Google Play isn't offering the subscription
on this device". That is expected here and is *not* a bug — billing is verified
after the internal-testing upload, per `store/BILLING_SETUP.md` §6.

---

## 3. Play Console

1. **Create the app** — name `Crux`, English (US), App, Free.
2. **Store listing** — copy from `store/PLAY_LISTING.md`; upload
   `store/play/icon-512.png` and `store/play/feature-graphic-1024x500.png`,
   plus 2–8 phone screenshots (list of shots is in that file).
3. **App content** — privacy policy URL, ads = No, content rating
   questionnaire, target audience, data safety (answers in
   `store/PLAY_LISTING.md`), and the **`SCHEDULE_EXACT_ALARM` declaration**
   (text provided there).
4. **App access** — ⚠️ **Guest mode has been removed**, so the app is now
   entirely behind a login. You *must* choose "All or some functionality is
   restricted" and give Play a working email/password test account, or the
   review fails on "we couldn't access the app". Create a real account with
   email sign-up, complete onboarding once so the reviewer lands on a working
   app, and keep it alive — don't delete it between submissions.
5. **Testing track first.** Start with **Internal testing** (instant, up to 100
   testers), then Closed → Production. A brand-new personal developer account
   must run a **closed test with 12+ testers for 14 days** before it can
   publish to production — plan for that.
6. Upload the `.aab`, add release notes (in `store/PLAY_LISTING.md`), roll out.
   **Then verify billing on that internal-testing build before promoting
   anywhere** — `store/BILLING_SETUP.md` §6. An untested paywall is the one
   thing you cannot check from here: a purchase that fails verification is
   auto-refunded by Google after three days, and you would only find out from
   the refund.
7. After upload, when Play asks for the **deobfuscation file**, give it
   `build/app/outputs/mapping/release/mapping.txt` so crash reports are readable.

---

## 4. Known gaps to decide on before launch

| Item | Impact | Note |
|---|---|---|
| Anthropic account credits | AI Coach + AI plan building fall back to templates | Add credits, or rely on Gemini |
| `plan` function not deployed | Onboarding still produces a curated plan, but it isn't AI-personalised, and "ask Coach to change my schedule" only handles the built-in shortcuts | `supabase functions deploy plan` + `supabase db push` |
| Automatic backup runs on app open, not at 02:00 | Sessions logged since the last open aren't in the cloud yet | Inherent to Android background limits — stated plainly in Settings and §9 of the Terms. A true overnight upload needs WorkManager |
| Paywall is a mock `BillingService` | Nothing charges yet | Fine for launch **only if** you don't advertise Pro. If you list a paid tier, wire real billing first or Play will flag it |
| iOS build | Not configured | Android-only release for now |

---

## 5. After launch

- Watch **Android vitals** (crash-free rate, ANRs) in the first 48h.
- Crash reports appear de-obfuscated only if you uploaded `mapping.txt`.
- Each update: bump `versionCode`, rebuild, upload, and keep using the same
  keystore.
