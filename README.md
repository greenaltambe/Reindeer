# Reindeer 🦌

An India-focused, **local-first medicine reminder** for Android, built with Flutter.
No account needed: your data stays on the phone. The only thing that ever leaves it is
the optional **family alerts** feature, and only after you link a caretaker.

> Reindeer is a reminder tool. It does not give medical advice and does not check
> doses or interactions. Always follow your doctor's prescription.

## What it does

- **Search Indian medicines** by brand or ingredient, offline, tolerant of misspellings
  and any word order. Custom medicines can be added when something is not in the list.
- **Simple guided adding.** One question per page: how often, how much, with food, for
  how long, what it is for, stock. Big tiles and +/- buttons, so little typing.
- **Meal-based reminders.** "After breakfast" instead of only a clock time, with
  Taken / Skip / Snooze buttons on the notification.
- **Scan and voice entry.** Photograph a strip, bottle or whole prescription (text is read
  on the phone), or say the medicine aloud in English, Hindi or Marathi.
- **Today screen** with a week calendar, the day's doses grouped by time, health-reading
  reminders and a low-stock warning.
- **Why-aware misses.** When a dose is missed or skipped, pick a reason (forgot, ran out,
  side effect, felt fine, cost, fasting/travel) and get matching guidance.
- **Refills.** Run-out forecast from stock and daily use, low-stock warnings, "I bought
  more", Jan Aushadhi generic hints and one-tap links to online pharmacies.
- **Doctor changed my medicines.** A wizard that shows what started, changed or stopped,
  while keeping past history intact.
- **Reports.** Adherence over 7 or 30 days, a 30-day calendar, miss reasons, and a
  one-page summary you can share with your doctor.
- **Health tab.** Weight, blood pressure, blood sugar, body fat and pulse, with charts,
  history and optional measurement reminders.
- **Conditions list** (built from the medicine data) to say what each medicine is for.
- **Prescription shorthand.** Type the doctor's line as written, like
  `pan 40 1-0-0 before food 14 days` (also OD, BD, TDS, HS, AC, PC), and the
  schedule is filled in for you.
- **Same-ingredient warning** when a new medicine shares an ingredient with one you
  already take (it compares ingredient names only, not interactions).
- **Allergy guard.** Record allergies once; adding a medicine with a matching ingredient
  shows a warning first. A **Medical ID** page collects allergies, conditions and medicines.
- **Symptom diary** ("How I feel"): one-tap symptoms with severity, shown next to recently
  started medicines and included in the doctor summary.
- **Missed-dose guidance** and a one-tap **Tell my family** message (via the share sheet).
- **Unusual-reading flags** for blood pressure, sugar, pulse and weight (a general guide, not a diagnosis).
- **Share the doctor summary** to WhatsApp, email or any app.
- **Family alerts (optional).** Link caretakers who get a push notification when a dose is
  missed, you press Help, ask for medicines or your battery is low. See
  [docs/FAMILY_SHARING.md](docs/FAMILY_SHARING.md). **Note:** these caretaker features do
  not work in the release build, because the Firebase project was downgraded to the free
  tier (the Cloud Functions backend needs the Blaze plan). It will be upgraded to Blaze later
  if needed.
- **TB care (DOTS)**, a **home-screen widget**, **backup/restore**, loud repeating reminders
  and English / Hindi / Marathi throughout.
- **You** tab for personal details, conditions and meal times; app settings behind a gear.
- Smooth page, tab and list animations.
- A small reindeer mascot with a few easter eggs.

## Getting started

Requirements: Flutter (Dart 3.x), an Android phone or emulator. Python 3 is only needed to
rebuild the medicine database; Node 22 and the Firebase CLI only for the family-alerts backend.

```bash
flutter pub get

# Firebase key (never committed): copy env.example.json to env.json and fill it in,
# and put your google-services.json in android/app/
flutter run --dart-define-from-file=env.json
```

The bundled `assets/db/medicines.db.gz` is committed. To rebuild it (see docs/DATA.md),
put `Extensive_A_Z_medicines_dataset_of_India.csv` in `data/` and run
`python3 tools/build_medicine_db.py`; this also writes `assets/db/medicines.db`, which the
search tests use and which is git-ignored.

Without the Firebase files the local features still work, but family alerts will not.
Backend setup and deployment are in [docs/FAMILY_SHARING.md](docs/FAMILY_SHARING.md).
Family alerts are currently unavailable in release builds (see the note under features).

Checks:

```bash
dart format .
flutter analyze
flutter test
(cd functions && npm test)   # family-alert wording
```

Reminders need the notification and exact-alarm permissions. If they arrive late, set the
app to "Unrestricted" under phone Settings > Apps > Reindeer > Battery. Settings has a
reminder check and a test notification.

## Project layout

```text
lib/
  core/        database, router, theme, utilities
  features/    adherence, allergy, backup, care, conditions, health,
               medications, medicine_database, onboarding, profile,
               progress, refills, reminders, routine, safety, settings,
               symptoms, tb, today, widget
  shared/      reusable widgets
functions/     Firebase Cloud Functions (family alerts) and their tests
tools/         Python: build the medicine database, regenerate icons
test/          domain, search-parity and widget tests
docs/          architecture, data, user guide, family sharing, roadmap, specification
firestore.rules, firebase.json   Firestore security rules and Firebase config
```

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/DATA.md](docs/DATA.md), [docs/USER_GUIDE.md](docs/USER_GUIDE.md),
[docs/FAMILY_SHARING.md](docs/FAMILY_SHARING.md), [docs/ROADMAP.md](docs/ROADMAP.md).
Build history is in [IMPLEMENTATION_PROGRESS.md](IMPLEMENTATION_PROGRESS.md).

## Status

A college project. Android only. Medicine data comes from public lists of
unverified provenance and may be incomplete: treat it as demo data and check against the
strip or prescription.
