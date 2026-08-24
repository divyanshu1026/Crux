# Crux — Play Console listing content

Copy-paste source for the Play Console "Main store listing", "Data safety" and
"App content" sections. Character limits are Google's; counts below are current.

---

## Main store listing

### App name (30 chars max)
```
Crux: Gym Workout Coach
```
*(27 chars)*

### Short description (80 chars max)
```
Log workouts, get AI coaching, and see exactly what to lift — every session.
```
*(75 chars)*

### Full description (4000 chars max)

```
Crux is the gym app that actually coaches you.

Most trackers assume you already know what to do. Crux tells you what to
lift today, how much, and why — then adapts every session based on what you
logged last time.

BUILT FOR PEOPLE WHO WANT TO STOP GUESSING

• Your weights are pre-filled. Every exercise opens with the exact weight and
  reps you should hit, calculated from your last session using double
  progression — the method coaches actually use.
• Know the reason. Every suggestion comes with a plain-English explanation, so
  you learn the logic instead of following a black box.
• Never wonder how an exercise works. Tap any movement for step-by-step form
  cues, common mistakes, and what to focus on mid-set.

FAST LOGGING THAT RESPECTS YOUR TIME

• Three taps per set. Giant numbers, one big Log button, no menu hunting.
• Automatic rest timer that keeps running when your screen locks — and rings
  on time so you never sit there scrolling.
• Your session survives anything. Lock your phone, take a call, close the app;
  reopen and you're exactly where you left off.

A PLAN THAT FITS YOUR WEEK

• Choose from proven programs — PPL, Upper/Lower, Full Body, glute-focused,
  home dumbbell and more — or build your own.
• See your whole week at a glance. Move a workout to another day, swap
  exercises, edit sets, reps and rest with a tap.
• Missed a day? Crux offers to fit it in later in the week instead of
  writing the week off.

AN AI COACH THAT KNOWS YOUR NUMBERS

• Ask anything about your training, nutrition or recovery, and get an answer
  based on your real logged data — not generic advice.
• Get a nutrition plan calculated from your bodyweight, height and goal, with
  a daily calorie range and protein target you can track in the app.
• Honest, safe guidance: no crash diets, no shame for rest days, and it always
  defers to a professional on pain or injury.

PROGRESS YOU CAN SEE

• Automatic personal-record detection with a celebration you'll actually
  enjoy.
• Charts for bodyweight trend, weekly volume per muscle, estimated 1RM, and a
  consistency heatmap.
• Optional XP, levels, streaks and quests — or switch on Zen mode and hide all
  of it for a clean, quiet tracker.

WORKS OFFLINE

Your gym has no signal? Doesn't matter. Everything except the AI Coach works
fully offline, and your data is stored on your device first. Sign in only if
you want cloud backup across devices.

PRIVACY FIRST

No ads. No data selling. Progress photos never leave your phone. Delete your
account and all its data from inside the app whenever you want.

Crux provides general fitness information, not medical advice. Consult a
qualified professional before starting a new exercise or nutrition program.
```
*(~2,300 chars — within limit)*

---

## Graphics checklist

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit, no transparency | ✅ `store/play/icon-512.png` |
| Feature graphic | 1024×500 PNG/JPG, no transparency | ✅ `store/play/feature-graphic-1024x500.png` |
| Phone screenshots | 2–8 images, 16:9 or 9:16, min 1080px on the short side | ⬜ **Capture from device** |
| 7-inch tablet | optional | ⬜ |
| 10-inch tablet | optional | ⬜ |

**Screenshots to capture** (in this order — the story sells the app):
1. Today screen with a training day loaded
2. Active workout — giant weight/reps + Log set
3. Rest timer running
4. PR celebration
5. Weekly schedule with the program guide
6. AI Coach answering a nutrition question
7. Dashboard — charts + nutrition card
8. Exercise guide sheet

---

## Data safety form — answers

Play Console → App content → Data safety. Answer exactly as below.

**Does your app collect or share any of the required user data types?** → **Yes**
**Is all of the user data collected by your app encrypted in transit?** → **Yes**
**Do you provide a way for users to request that their data is deleted?** → **Yes**
(deletion URL: `https://crux.app/privacy#deleting-your-data`, and in-app via
Settings → Delete my account)

### Data types to declare

| Category | Type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|---|
| Personal info | Name | Yes | No | Required* | App functionality |
| Personal info | Email address | Yes | No | Optional | App functionality, Account management |
| Personal info | Other info (sex, date of birth) | Yes | No | Optional | App functionality, Personalisation |
| Health & fitness | Health info (bodyweight, measurements, water/protein) | Yes | No | Optional | App functionality, Personalisation |
| Health & fitness | Fitness info (workouts, sets, reps, PRs) | Yes | No | Required* | App functionality, Personalisation |
| Messages | Other in-app messages (AI Coach chat) | Yes | **Yes** | Optional | App functionality |
| Photos & videos | Photos | **No** — stays on device | No | Optional | — |
| App activity | App interactions | No | No | — | — |

\* "Required" = needed for the app's core purpose; the user chooses whether to
use an account at all.

**Note on the Messages row:** mark *Shared = Yes* because coach messages are sent
to an AI provider (Anthropic / Google) to generate the reply. Under "Reason for
sharing" choose **App functionality**.

**Data not collected** (leave unchecked): Location, Financial info, Contacts,
Calendar, Web browsing, Installed apps, Device IDs, Advertising ID, Audio, Files.

---

## App content declarations

| Section | Answer |
|---|---|
| Privacy policy URL | `https://crux.app/privacy` |
| App access | All functionality available without special access. **Provide test credentials** if you gate anything behind sign-in — reviewers need a working login, or note that Guest mode is available on the sign-in screen. |
| Ads | **No ads** |
| Content rating | Complete the questionnaire → expect **Everyone / PEGI 3**. Health & fitness app, no violence, no user-generated content sharing, no gambling. |
| Target audience | 18+ recommended (13+ minimum). Do **not** opt into "Designed for Families". |
| News app | No |
| COVID-19 tracing | No |
| Data safety | See above |
| Government app | No |
| Financial features | No |
| Health apps declaration | Declare as a **fitness/wellness** app (not a medical device). Confirm it does not provide medical diagnosis or treatment. |

### Sensitive permission declarations

**`SCHEDULE_EXACT_ALARM` — you must justify this in Play Console.**
Declaration text to use:

```
Crux is a gym training app whose core feature is a rest timer between
exercise sets. Rest periods are typically 60–180 seconds, and the alert must
fire at the exact moment rest ends — the user is mid-workout with their screen
locked, and a delayed notification makes the feature useless. We use exact
alarms only for this user-initiated rest timer, scheduled only while a workout
is in progress and cancelled as soon as the set is logged or the workout ends.
If the permission is unavailable we fall back to inexact scheduling.
```

If this declaration is rejected, remove the `SCHEDULE_EXACT_ALARM` permission
from `AndroidManifest.xml`; the app already falls back to inexact alarms
automatically (the timer stays accurate on screen, only the background ring
loses precision).

---

## Release notes (first release)

```
First release.

• Workouts that tell you exactly what to lift, adapting each session from your
  last one
• Fast set logging with a rest timer that keeps time while your screen is off
• AI coach that answers using your real training data
• Nutrition targets calculated from your stats
• Weekly schedule you can edit, plus proven ready-made programs
• Progress charts, personal records, and optional XP and streaks
• Works offline
```
