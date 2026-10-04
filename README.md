# Reindeer 🦌

An India-focused, **local-first medicine reminder** for Android, built with Flutter.
No account, no server: everything stays on the phone.

> Reindeer is a reminder tool. It does not give medical advice and does not check
> doses or interactions. Always follow your doctor's prescription.

## What it does

- **Search Indian medicines** by brand or ingredient, offline, tolerant of misspellings
  and any word order. Custom medicines can be added when something is not in the list.
- **Simple guided adding.** One question per page: how often, how much, with food, for
  how long, what it is for, stock. Big tiles and +/- buttons, so little typing.
- **Meal-based reminders.** "After breakfast" instead of only a clock time, with
  Taken / Skip / Snooze buttons on the notification.
- **Today screen** with the next dose, today's doses and a low-stock warning.
- **Progress.** Adherence over 7 or 30 days, per medicine, plus a summary you can copy
  and send to your doctor.
- **Health tab.** Weight, blood pressure, blood sugar, body fat and pulse, with charts,
  history and optional measurement reminders.
- **Conditions list** (built from the medicine data) to say what each medicine is for.
- **Barcode scan** that learns: scan a pack once, pick the medicine, and it is
  remembered next time.
- A small reindeer mascot with a few easter eggs.

## Getting started

Requirements: Flutter (Dart 3.x), Python 3, an Android phone or emulator.

```bash
flutter pub get

# One-time: build the bundled medicine database (see docs/DATA.md)
#   put Extensive_A_Z_medicines_dataset_of_India.csv in data/ first
python3 tools/build_medicine_db.py

flutter run
```

The build script writes `assets/db/medicines.db.gz` (the file the app bundles) and
`assets/db/medicines.db` (used by the tests). Both are git-ignored because of their size.

Checks:

```bash
dart format .
flutter analyze
flutter test
```

Reminders need the notification and exact-alarm permissions. If they arrive late, set the
app to "Unrestricted" under phone Settings > Apps > Reindeer > Battery. Settings has a
reminder check and a test notification.

## Project layout

```text
lib/
  core/        database, router, theme, utilities
  features/    adherence, barcode, conditions, health, medications,
               medicine_database, onboarding, profile, progress,
               reminders, settings, today
  shared/      reusable widgets
tools/         Python: build the medicine database, regenerate icons
test/          domain, search-parity and widget tests
docs/          architecture, data, user guide, roadmap, specification
```

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/DATA.md](docs/DATA.md), [docs/USER_GUIDE.md](docs/USER_GUIDE.md),
[docs/ROADMAP.md](docs/ROADMAP.md).

## Status

v1.0.0, a college project. Android only. Medicine data comes from public lists of
unverified provenance and may be incomplete: treat it as demo data and check against the
strip or prescription.
