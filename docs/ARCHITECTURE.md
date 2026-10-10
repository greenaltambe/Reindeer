# Architecture (v2)

Flutter + Material 3, Riverpod for state, go_router for navigation, sqflite for storage.
The app is local-first: all medicines, doses and readings live in SQLite on the device and
nothing is uploaded by default. The one exception is optional **family alerts**
(`features/care`, Firebase), which only sends dose status, help requests and similar events
after the patient links a caretaker. See [FAMILY_SHARING.md](FAMILY_SHARING.md).

## Layers

Each feature folder follows:
- `domain`: Plain Dart models, business rules, and calculation engines. Free of Flutter and database imports for fast unit testing.
- `data`: SQLite repositories, migrations, and query services.
- `application`: State management, Riverpod providers, and coordinated actions.
- `presentation`: Senior-friendly UI screens, high-contrast cards, and modal bottom sheets.

## Family alerts backend

Firebase (anonymous Auth, Firestore in asia-south1, Cloud Functions in `functions/`, FCM).
`CareSync` uploads changed doses; scheduled and triggered functions send push alerts.
Security rules are in `firestore.rules`. The Android API key is supplied at build time with
`--dart-define-from-file=env.json` (template: `env.example.json`) and `google-services.json`
is git-ignored; CI writes both from secrets (`.github/workflows/release.yml`).

## Other features

Home-screen widget (`features/widget`, Android `ReindeerWidgetProvider`), backup/restore
(`features/backup`), TB DOTS programme (`features/tb`), routine learning (`features/routine`),
prescription/strip scanning with on-device ML Kit OCR and voice input (`features/medications`),
pharmacy links (`features/refills`), and Hindi/Marathi strings (`core/i18n`).

## Two Databases

| Database | Location | Purpose |
|---|---|---|
| `medicines.db` | Bundled as `assets/db/medicines.db.gz`, unpacked once on first launch (version marker in `medicine_database.dart`) | Read-only: medicines, ingredient index, and chronic conditions. Falls back gracefully if asset unpack fails. |
| `reindeer.db` | App databases folder, SQLite Schema v6 with transactional `onUpgrade` | Profiles, plans, versioned plans (`plan_versions`), pause windows (`plan_pauses`), dose logs (`dose_logs`), miss reasons (`miss_reasons`), refills, measurements, allergies, symptoms, settings. |

After every data mutation, `dataVersionProvider` is bumped so Riverpod providers that read the database automatically refresh.

---

## Core Adherence Engine & Safety

### 1. Stable Dose Identity
- **Dose Key:** Format is `$planId|$doseDate|${slot.name}` (e.g. `1|2026-10-12|morning`), replacing legacy clock-time keys (`planId|yyyy-MM-ddTHH:mm`).
- **Meal-Time Shift Stability:** When a user alters their breakfast or dinner anchor in settings, the dose key does **not** change. Past doses logged as taken remain taken and are never orphaned.
- **Legacy Compatibility:** `PlannedDose.parseKey` handles both modern 3-part keys and legacy 2-part keys.

### 2. Versioned Medication Plans & Multiple Pause Windows
- Historical doses must reflect the prescription in effect on that date.
- `plan_versions` records `effective_from`, slot amounts (`morning`, `afternoon`, `night`), `meal_timing`, `interval_days`, `weekdays`, and `change_reason`.
- `plan_pauses` records multiple distinct pause intervals (`paused_at`, `resumed_at`, `reason`).
- `MedicationPlan.dosesOn(date, anchors)` resolves against the effective version on that date and suppresses doses if the date falls inside any active pause window.

### 3. Barrier-Aware Missed-Dose Reason Loop
- When a dose is missed or skipped, Reindeer captures one of 6 barrier reasons:
  1. `Forgot`: Routine habit anchoring tip (tie reminder to morning tea or meal).
  2. `Ran out`: Immediate stock refill entry sheet.
  3. `Side effect`: Clinical note capture for doctor consultation + doctor visit flag.
  4. `Felt fine`: Clear asymptomatic education ("BP and diabetes medicines protect silent organs even when you feel well").
  5. `Cost`: Pradhan Mantri Jan Aushadhi generic savings guidance (50–80% lower cost generic equivalents).
  6. `Fasting / Travel`: Safe guidance on consulting doctor for schedule shifts rather than skipping.

### 4. Stock Forecasting & Refill Alerts
- Daily consumption rate is calculated from slot amounts and interval days.
- Run-out date is projected (`daysOfStockLeft = stock / dailyConsumption`).
- Proactive low-stock warnings when stock is under 5 days.
- Quick "I bought more" stock updates with one-pack presets.

### 5. Prescription Reconciliation & Diff
- "Doctor changed my medicines" wizard compares current regimen against previous plans using `computePrescriptionDiff`.
- Classifies changes into `Started`, `Adjusted`, `Stopped`, and `Unchanged`.
- Saves adjustments to `plan_versions` so past history remains immutable and clean.

### 6. One-Page Doctor-Visit Report
- **Visual Calendar:** 30-day grid with dual encoding (color + pattern: `✓` taken, `✕` missed, `–` skipped/partial). Fully accessible for colorblind users and TalkBack screen readers.
- **Reason Breakdown:** Summary counts of missed dose reasons and patient-recorded side effect notes.
- **Prescription Changes:** Diff of changes made since last visit.
- **Clinical Disclaimer:** Prominently marked: *"Self-recorded by patient/caregiver, not verified intake"*.
- **Export / Share:** Formatted in professional English for sharing via WhatsApp, email, or clipboard.

---

## 5-Tab Navigation Architecture

The app shell organizes chronic disease management around the chronic care loop:

1. **Today (`/`)**: Daily dosing actions, why-aware skip/miss capture, meal-time shift suggestions, and notification/alarm permission warning banner.
2. **Medicines (`/medicines`)**: Current regimen, generic salt compositions, schedule adjustments, pause/resume, and "Doctor changed my medicines" wizard.
3. **Refills (`/refills`)**: Stock counts, consumption rates, run-out forecasts, Jan Aushadhi generic hints, and "I bought more" quick entries.
4. **Reports (`/reports`)**: One-page doctor report, 30-day visual adherence calendar, missed reasons breakdown, and access to Health Vitals & Readings (`/health`).
5. **You (`/you`)**: Profile, meal anchors, OEM battery killer guidance, Language switcher (English, Hindi, Marathi), Medical ID, DPDP local data export & purge, optional TB supporter mode, and Family (caretaker linking).

Caretakers also have a **Care** home (`/care`) listing the patients they follow.
