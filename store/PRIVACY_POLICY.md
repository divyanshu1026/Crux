# Crux — Privacy Policy

**Last updated: 3 August 2026**

Crux ("we", "the app") is a gym training app. This policy explains exactly
what we store, why, and what we never collect. It is written to be read, not to
be survived.

**Short version:** your training data lives on your phone. If you sign in, it is
also backed up to our server so you can restore it on a new device. We do not
sell your data, we do not run ads, and we do not track you across other apps.

---

## 1. Who we are

Crux is operated by the developer of the Crux app.
Contact for privacy questions and data requests: **privacy@crux.app**

---

## 2. What we collect

### 2.1 Data you enter (the app's whole purpose)

| Data | Why | Where it lives |
|---|---|---|
| Name or nickname | To address you in the app | Device + your account |
| Sex, date of birth / age, height, bodyweight | To calibrate starting weights, strength standards and calorie/protein targets | Device + your account |
| Training goal, experience level, available equipment, injuries you list | To generate and adjust your program safely | Device + your account |
| Workouts, sets, reps, weights, per-set notes, personal records | The core training log | Device + your account |
| Bodyweight log, optional body measurements | Progress tracking and nutrition targets | Device + your account |
| Water and protein entries | Daily habit tracking | Device + your account |
| Messages you send to the AI Coach | To answer them, and to review safety of AI responses | Device + your account |

### 2.2 Account data

If you create an account, we store your **email address** (or, for Google/Apple
sign-in, the identifier that provider returns) and an authentication token.
You can also use the app **without an account**, fully offline — in that case
nothing leaves your phone.

### 2.3 Progress photos

Progress photos you add **stay on your device only**. They are never uploaded
to our servers.

### 2.4 What we do NOT collect

- We do not collect your precise location.
- We do not collect your contacts, calendar, call logs or SMS.
- We do not use advertising identifiers, and we show no ads.
- We do not track you across other apps or websites.
- We do not sell or rent your personal data to anyone. Ever.

---

## 3. Permissions we ask for, and why

| Permission | Why we ask | Optional? |
|---|---|---|
| Notifications | Rest-timer alerts, training-day and hydration reminders | Yes — the app works without it |
| Alarms & reminders (exact alarms) | So the rest-timer alert fires on time when your screen is off mid-workout | Yes — falls back to approximate timing |
| Photos / media | Only when you choose to add a progress photo | Yes |
| Vibration | Haptic feedback when logging sets and when rest ends | — |

We only request a permission at the moment the related feature is used.

---

## 4. How your data is used

We use your data solely to run the app for you:

1. **To generate and adapt your training program** (progression, volume, rest).
2. **To show your progress** (charts, records, streaks, weekly summaries).
3. **To answer your AI Coach questions.** When you send a coach message, we
   send that message together with a summary of your own training data
   (profile, recent workouts, bodyweight trend, recent records) to our AI
   provider so the answer is personalised. See section 5.
4. **To back up and restore your data** across your devices, if you sign in.

### 4.1 Automatic backup

When you are signed in, Crux backs up your training log, profile and
bodyweight history to your own account on a schedule you control in
**Settings → Cloud backup**:

- **How often:** daily, weekly (default), monthly, or every 3 months.
- **When:** due after a time you choose — 02:00 by default, so a backup can
  never start in the middle of a workout.
- **Off:** you can disable automatic backup entirely and back up manually.

The upload goes only to your own account. If you are not signed in, nothing is
uploaded at all and the app remains fully local.

We do **not** use your data to build advertising profiles, and we do not use
your personal training data to train third-party AI models.

---

## 5. Third parties we share data with

We keep this list as short as possible.

| Provider | What they receive | Purpose |
|---|---|---|
| **Supabase** (database & auth hosting) | Your account and the training data listed in 2.1 | Storing your account and backup |
| **OpenRouter** (AI routing) | Your coach message + a summary of your training data | Routing the request to a model provider |
| **The model provider** (currently **DeepSeek**) | The same, passed on by OpenRouter | Generating the AI Coach reply or training plan |
| **Anthropic** (Claude) and **Google** (Gemini) | The same, only when the primary provider is unavailable | Fallback so the coach still answers |

AI providers process your message to produce a response. We send only what is
needed to answer well, and we never send your email address, progress photos,
or precise identity to them. We ask these providers not to train on your
inputs.

Because we route through OpenRouter, the specific model answering you may
change over time. We name the current provider above and update this section
when it changes.

If you never use the AI Coach or ask Coach to build a plan, nothing is ever
sent to an AI provider.

---

## 6. How long we keep data

- **While your account exists:** we keep your data so you can use and restore it.
- **When you delete your account:** we delete your account and its data from our
  servers. Deletion is immediate and permanent.
- **Local data:** stays on your device until you clear it, delete your account,
  or uninstall the app.
- **Payment records:** if you ever purchase a subscription, we keep transaction
  records (without linking them to your deleted account) for as long as tax and
  accounting law requires.

---

## 7. Deleting your data

You are in control, from inside the app:

- **Settings → Clear data on this device** — wipes everything locally and signs
  you out. Any cloud backup is untouched.
- **Settings → Delete my account** — permanently deletes your account and **all**
  associated data from our servers, then wipes this device.
- **Settings → Automatic backup** — controls what is uploaded and how often,
  and can be switched off.

You can also email **privacy@crux.app** from your account's email address to
request deletion, or to request a copy of your data in a portable format, and
we will action it within 30 days.

---

## 8. Your rights

Depending on where you live (for example the EEA/UK under GDPR, or California
under CCPA/CPRA), you have the right to access, correct, export, or delete your
personal data, to object to or restrict certain processing, and to complain to
your data protection authority. The in-app delete tools cover erasure
instantly; for a copy of your data, or anything else, email
**privacy@crux.app** and we will respond within 30 days.

We do not "sell" or "share" personal information as those terms are defined
under California law.

---

## 9. Security

Data in transit is encrypted with TLS. Data on our servers is stored with
per-user access rules, so one account cannot read another's rows. AI provider
keys are held only on our server and are never shipped inside the app. No system
is perfectly secure, but we keep the amount of data we hold deliberately small.

---

## 10. Children

Crux is not intended for children under 13 (or the minimum age of digital
consent in your country). We do not knowingly collect data from children. If you
believe a child has provided us data, email **privacy@crux.app** and we will
delete it.

---

## 11. Health disclaimer

Crux provides general fitness information and AI-generated training
guidance. It is **not** medical, dietetic, or physiotherapy advice, and it is not
a substitute for a qualified professional. Consult a professional before
starting a new exercise or nutrition programme, and stop exercising if you
experience pain.

---

## 12. Changes to this policy

If we make a material change, we will update the "Last updated" date above and
notify you in the app before the change takes effect.

---

## 13. Contact

**privacy@crux.app**
