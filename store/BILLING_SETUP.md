# Crux Pro — Google Play Billing setup

Everything in the app is written. This is the part only you can do, in order.
Nothing charges anyone until step 6.

The rule the whole design follows: **the server decides who is Pro.** The app
sends Google's purchase token to `verify-purchase`, which asks Google whether
that token is real and only then writes `profiles.is_pro`. A modified client
cannot grant itself Pro — the `guard_is_pro` trigger rejects any write to the
entitlement columns that doesn't come from a billing function.

---

## 1. Create the subscriptions (Play Console)

**Monetize → Products → Subscriptions → Create subscription.**

Product IDs must match the app exactly — they are in
`lib/features/paywall/data/billing_service.dart`:

| Product ID          | Base plan            | Notes                        |
| ------------------- | -------------------- | ---------------------------- |
| `crux_pro_monthly`  | monthly, auto-renew  | |
| `crux_pro_annual`   | yearly, auto-renew   | The paywall highlights this  |

Set prices per region (India first, then let Play auto-convert), then
**activate** both base plans. A product that exists but isn't active comes back
from the app as "not found" and the paywall shows the unavailable state.

> The "SAVE 42%" badge on the annual tile is hardcoded. Once you set real
> prices, either make the maths true or delete the badge — a wrong discount
> claim is the kind of thing Play rejects for.

## 2. Enable the API and make a service account

1. **Google Cloud Console** → the project linked to your Play account →
   **APIs & Services** → enable **Google Play Android Developer API**.
2. **IAM & Admin → Service Accounts → Create**. No roles needed in Cloud.
3. On the new account: **Keys → Add key → JSON**. Download it. This file is a
   credential — never commit it.
4. **Play Console → Users and permissions → Invite new users**, paste the
   service account email, and grant, for the Crux app:
   - View financial data, orders, and cancellation survey responses
   - Manage orders and subscriptions

Permission propagation takes a few minutes to a few hours the first time.

## 3. Give Supabase the secrets

```bash
supabase secrets set ANDROID_PACKAGE_NAME=com.cruxapp.crux
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat ~/Downloads/crux-play-sa.json)"
supabase secrets set RTDN_SHARED_SECRET=$(openssl rand -hex 24)   # keep this value
```

## 4. Deploy

```bash
supabase db push
supabase functions deploy verify-purchase
supabase functions deploy play-rtdn --no-verify-jwt
```

`play-rtdn` must be `--no-verify-jwt`: Google Pub/Sub can't send a Supabase
JWT. It is protected instead by the shared secret in its URL **and** by the
fact that it re-fetches every subscription from Google before changing
anything — a forged notification can't grant Pro.

## 5. Wire renewals (Real-time Developer Notifications)

Without this, nobody's subscription ever ends. Cancellations, expiries and
refunds all happen on Google's side and the app would never hear about them.

1. **Google Cloud → Pub/Sub → Create topic**, e.g. `play-rtdn`.
2. On that topic: **Add principal** `google-play-developer-notifications@system.gserviceaccount.com`
   with role **Pub/Sub Publisher**.
3. **Play Console → Monetize → Monetization setup → Real-time developer
   notifications**: paste the full topic name
   (`projects/<cloud-project>/topics/play-rtdn`) and **Send test
   notification**.
4. Back in Pub/Sub, create a **push subscription** to the topic with endpoint:

   ```
   https://<project-ref>.supabase.co/functions/v1/play-rtdn?secret=<RTDN_SHARED_SECRET>
   ```

The test notification should appear in the function logs as
`play-rtdn: test notification received — wiring is good`.

## 6. Test it (this cannot be done in the web preview)

In-app purchases only work in a build installed from a Play track, signed with
the upload key.

1. **Play Console → Setup → License testing**: add the Google accounts that
   will test. Licence testers are never charged and their renewals are
   accelerated (a monthly subscription renews every ~5 minutes).
2. Upload an AAB to **internal testing** and install it from the Play link on
   a device signed in with a tester account.
3. Buy the annual plan and check, in Supabase:

   ```sql
   select user_id, product_id, status, expires_at, auto_renewing
     from subscription_purchases order by updated_at desc limit 5;
   select id, is_pro, pro_expires_at from profiles where is_pro;
   ```

4. **Cancel** in Play Store → Subscriptions. `status` becomes `canceled`;
   `is_pro` stays true until `expires_at` passes — that's correct, they paid
   for the period.
5. **Refund** an order in Play Console. The voided-purchase notification should
   flip `is_pro` to false immediately.
6. Reinstall the app and tap **Restore** — Pro should come back without paying.

## Before you publish

- [ ] Prices set for every market you ship to, both base plans active.
- [ ] "SAVE 42%" is true, or gone.
- [ ] **Data safety** form updated: purchases are handled by Google Play; the
      app itself stores only the entitlement.
- [ ] Play listing mentions the subscription, its price and renewal terms.
- [ ] Your privacy policy and terms cover subscriptions and refunds
      (`store/PRIVACY_POLICY.md`).
- [ ] Account deletion still works for a subscribed user (it does not cancel
      their Play subscription — Google requires them to cancel in Play, and the
      app should say so).

## What is deliberately *not* here

- **iOS / StoreKit.** The `BillingService` interface is ready for it, but it
  needs its own verifier against the App Store Server API.
- **Razorpay.** `supabase/functions/razorpay-webhook` still exists and is the
  right shape for a web checkout on your own domain. It must not be used for
  in-app purchases on Android: Play requires Play Billing for digital goods,
  and shipping an alternative in-app payment path risks removal. India's User
  Choice Billing programme is the only exception, requires enrolment, and still
  requires offering Play Billing alongside it.
