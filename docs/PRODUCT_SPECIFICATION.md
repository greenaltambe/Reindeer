# Reindeer --- Final Product Specification

> **v1 scope note (4 Oct 2026):** the shipped v1 differs from this document in a few
> places. It also adds barcode scanning (learns links), a conditions list, onboarding
> and a Health tab (weight, blood pressure, blood sugar, body fat, pulse). It leaves out
> appointments, diary, contacts, multiple profiles and caregiver sharing. See `README.md`
> and `docs/ROADMAP.md` for what is actually built.

> **Status:** Product definition / evolving implementation reference
>
> **Revision 2026-10-03:** added competitor-survey findings (§2.1), backend
> decision (§8.1), schedule/missed-dose/adherence rules (§5.3), Android
> reliability requirements (§12.1), medical disclaimer and minors policy
> (§16.1), excluded-feature list (§17.1), profiles (§11), and open decisions (§28).

## 1. Product Overview

**Reindeer** is an India-focused, local-first medication management and
adherence application for patients who take one or more medicines.

The application is **not intended to be another generic health
tracker**. Its primary purpose is to make it easy for a patient to:

1.  Find and understand medicines commonly available in India.
2.  Build a medication/treatment schedule without being overwhelmed.
3.  Receive reliable reminders that continue to work offline.
4.  Record whether doses were taken, skipped, or missed.
5.  Track medication adherence over time.
6.  Monitor medicine inventory and receive refill reminders.
7.  Optionally share medication/adherence information with a trusted
    caregiver.
8.  Generate useful medication/adherence summaries.
9.  Optionally synchronize data through the cloud.
10. Remain architecturally capable of future integration with India's
    digital-health ecosystem.

The application should be **local-first**: core medication data,
schedules, reminders, and adherence tracking must work without an
internet connection.

## 2. Problem Statement

Existing medication applications already provide reminders, dose
tracking, refill reminders, symptom tracking, measurements, reports, and
caregiver functionality.

The project therefore must **not** position itself as simply:

> "A medicine reminder app."

A major gap identified during competitor research is the treatment of
medicines themselves.

Many medication-management applications allow users to enter a medicine
manually, but the availability and depth of Indian medicine information
varies significantly. Generic medication databases do not necessarily
represent the Indian marketed-brand ecosystem.

The project therefore focuses on the intersection of:

-   Indian medicine information
-   medication scheduling
-   medication adherence
-   local/offline reliability
-   simple treatment-oriented UX
-   optional caregiver support

### 2.1 Competitive Survey (Google Play, October 2026)

Two established apps were reviewed by hand. These are first-hand observations
and have not been independently verified.

| Area | Medisafe | My Therapy |
|---|---|---|
| Onboarding | Multi-page | Page-by-page |
| Minors allowed | No (18+) | Yes |
| Home layout | Date strip + timeline of meds/symptoms | Date strip + to-do style timeline |
| Bottom nav (4 tabs) | Home, Updates, Medications, Manage | Today, Progress, Support, Treatment |
| Medicine database | Yes (not India-focused) | None; has a disease database |
| Add-medication flow | Single flow | Multi-page: count, doses per time, refill threshold, condition |
| Refills | Per-med count, decrements on each dose, refill history | Refill threshold asked at setup |
| Multi-profile | Not observed | Yes (manage other people) |
| Extras | Symptoms, measurements, appointments, diary, health contacts, interaction check, reports | Mood, symptoms, measurements with icons, AI chatbot, charts + list + share |
| Sharing | Share button for tracked data | Share button on Progress |
| Notification sound | Not observed | Configurable |

**Gap Reindeer targets:** neither app offers an India-brand medicine layer
(Medisafe's data is Western; My Therapy has no medicine database at all).

### 2.2 Decisions Derived From the Survey

Adopted:

-   **Page-by-page onboarding and treatment entry** (both apps do this well).
-   **Today screen = date strip + timeline** (both apps converge on it).
-   **Four-tab bottom navigation:** Today · Medications · Progress · Settings.
    Profile switching lives in the Today header, not a tab.
-   **Per-medication inventory that decrements on each taken dose**, with
    refill history (Medisafe).
-   **Local multi-profile** so a person can manage a parent's or child's
    medicines on one phone without any cloud account (My Therapy). This covers
    most real caregiver need before cloud sync exists.
-   **"What is it for?"** optional condition field on a medication (My Therapy).
-   **Selectable reminder sound** (My Therapy).
-   **Shareable adherence report** (PDF/image via the system share sheet),
    useful for showing a doctor.
-   **Minors are allowed**; no age gate (see §16.1).

Deliberately not adopted (see §17.1): symptom/mood/measurement tracking,
diary, appointments, health contacts, news feed, AI chatbot, drug-interaction
checking.

## 3. Product Vision

> **Help people manage the medicines they have actually been prescribed,
> using an India-aware medicine knowledge layer and a reliable
> local-first adherence system.**

The application should feel like a **medication companion**, not a
hospital-management system or a general-purpose health super-app.

## 4. Target Users

### Primary User

A person who takes one or more medications and needs help remembering,
organizing, and tracking them.

### Secondary User

A trusted caregiver or family member who helps another person manage
medications.

### Design Priority

The application should remain usable by users with limited technical
familiarity.

Important UX principles:

-   progressive disclosure
-   clear language
-   large touch targets
-   obvious actions
-   minimal unnecessary navigation
-   accessible typography
-   clear status indicators
-   avoid overwhelming forms

## 5. Core Product Pillars

### 5.1 Indian Medicine Knowledge

Provide searchable information about medicines commonly marketed in
India.

A medicine record may contain:

-   brand name
-   generic/active ingredient
-   strength
-   dosage form
-   manufacturer
-   pack size
-   price when available
-   prescription/OTC classification when available
-   source
-   source update date
-   aliases/search terms

The database should support:

``` text
Brand
  ↓
Active ingredient / salt
  ↓
Strength
  ↓
Dosage form
```

The application must distinguish between information sourced from a
medicine database and information manually entered by the user.

**Custom medicines.** No dataset is complete. If search finds nothing, the
user can add a custom medicine (name, optional strength and dosage form) and
continue the same flow without friction. Such records carry `source = user`
and are shown as "added by you", never as database-verified.

### 5.2 Treatment Builder

Users should create treatment plans through a guided flow rather than
one giant form.

Example:

``` text
Medicine → Dose → Timing → Frequency → Duration → Inventory
```

Builder rules:

-   One decision per screen, with a sensible default on each.
-   Going back preserves what was entered.
-   Optional step: "What is it for?" (free text).
-   The final screen is a plain-language summary (for example "Dolo 650 —
    1 tablet, after breakfast, every day for 5 days") shown before saving.

Dose units must cover Indian dosage forms, not only tablets: tablet, capsule,
ml (syrup/suspension), drops, puffs (inhaler), units (insulin), injection,
application (ointment/cream), sachet. Inventory uses the same base unit and may
carry an optional pack size (for example a strip of 10 tablets).

### 5.3 Reminder and Adherence Engine

Each scheduled dose should support:

-   scheduled time
-   dose
-   instructions
-   taken
-   skipped
-   missed/unconfirmed
-   snooze/reschedule
-   actual time taken

**Schedule types.**

-   MVP: fixed times daily; specific weekdays; every N days; start date with an
    end date or number of days.
-   Later: every N hours, as-needed (PRN), cyclic/tapering courses.

**Dose lifecycle.** Dose slots are derived from the plan and schedule. A
`DoseLog` row is persisted when the user acts on a slot, or when the slot
expires.

-   A slot becomes `missed` when its grace window passes with no action. The
    grace window defaults to 2 hours or until the next dose of the same plan,
    whichever is earlier.
-   Taking a dose inside the grace window records `taken` with the actual time.
-   Snooze defaults to 10 minutes, at most 3 times, never past the grace window.
-   Past slots may be edited later by the user (forgot to tap), and edits are
    recorded as such.

**Adherence definition.**

```text
adherence % = taken / (taken + skipped + missed)
```

over slots whose time has passed. Pending/snoozed slots, as-needed doses, and
paused or discontinued periods are excluded. Taken-on-time versus taken-late
may be reported separately, but a late dose inside the window counts as taken.

Reminders must be generated locally. Internet availability must not be
required for ordinary medication reminders.

### 5.4 Medication Inventory and Refill

Each medication may optionally have an inventory count.

Support:

-   initial quantity
-   current quantity
-   refill
-   refill history
-   low-stock threshold
-   estimated doses remaining
-   refill reminder

### 5.5 Caregiver Support

A patient may grant a trusted caregiver access to selected information.

Potential shared information:

-   medication list
-   today's medication status
-   adherence percentage
-   missed doses
-   refill status

Caregiver functionality should use cloud synchronization because it
requires communication between devices.

## 6. Main Application Areas

### Home / Today

The primary screen shows:

-   today's date
-   upcoming medication
-   medication timeline
-   taken/missed status
-   quick action to mark a dose
-   adherence summary
-   low-stock warnings

The Home screen should prioritize **what the user needs to do now**.

### Medications

Shows the user's medication list with:

-   medicine name
-   strength
-   dose
-   schedule
-   treatment status
-   inventory
-   next dose

Actions:

-   add
-   edit
-   pause
-   discontinue
-   refill
-   view history

### Medicine Search / Database

Search by:

-   brand name
-   generic/active ingredient
-   manufacturer
-   strength
-   dosage form
-   aliases

Search should tolerate common user input variations.

### Adherence / Progress

Show:

-   overall adherence
-   adherence by medication
-   adherence over 7/30/custom days
-   missed doses
-   adherence trends

Useful observations may include frequently missed medications or time
periods. The application should report observations rather than make
medical diagnoses.

### Inventory

Show:

-   remaining quantity
-   low-stock medicines
-   refill history
-   estimated remaining doses
-   refill reminders

### Caregiver

If enabled:

-   connected caregivers
-   shared medication status
-   permissions
-   caregiver notification preferences

### Settings

Include:

-   theme
-   notification preferences
-   reminder sound
-   accessibility
-   account/sync
-   caregiver settings
-   privacy
-   medicine database information
-   about/source information

## 7. Medicine Database Architecture

Preferred pipeline:

``` text
Public Indian medicine sources
          ↓
Data acquisition
          ↓
Cleaning / normalization
          ↓
Deduplication
          ↓
Brand → generic normalization
          ↓
Validation / source metadata
          ↓
SQLite/Drift database
          ↓
Flutter application
```

The bundled database should support offline search.

Potential sources:

-   public Indian medicine datasets
-   Indian medicine databases/APIs
-   official regulatory information where usable
-   other appropriately licensed sources

Before shipping or publishing the database, verify the
license/redistribution terms of each source.

### 7.1 Primary Dataset: junioralive/Indian-Medicine-Dataset (assessed 2026-10-03)

-   253,973 rows, all `allopathy`. Fields: id, name, price, discontinued flag,
    manufacturer, pack size label, and up to two compositions with strength
    embedded in the text (for example `Paracetamol (650mg)`).
-   **Licence:** the repository is MIT, but the README does not say where the
    data was originally collected. MIT on the repository does not by itself
    establish rights to the underlying data, so redistribution is treated as
    **unverified**. Before any public release, ask the maintainer about
    provenance or rebuild from official sources.
-   Bundle factual fields only. Do not ship the description, side-effect, or
    interaction text from `updated_indian_medicine_data.csv` (about 97% empty
    anyway, and the same provenance question applies).
-   No source date and no dosage-form column. The pipeline adds source metadata
    (§5.1) and derives dosage form from the name and pack label.
-   Prices are a snapshot. Never present them as the current price.
-   No Ayurvedic, homeopathic, or other non-allopathic products. The custom
    medicine fallback (§5.1) covers these.
-   Cleaning needed: whitespace noise in compositions (about 7,000 rows), about
    4,600 duplicate names (2,900 with the same manufacturer), 3.1% discontinued
    (keep, flag, rank lower), 4 non-positive prices, pack labels such as
    `strip of 10 tablets` parsed into unit and count for inventory.
-   Measured size: about 81 MB as SQLite with an FTS5 trigram index (about 30 MB
    compressed). Options: drop unused columns, deliver the database as a
    first-run download or Play asset pack, or use a prefix index.
-   Trigram search matches substrings (a search for `dolo` also hits
    `Aldoloc`), so ranking must favour word-start and prefix matches.

### 7.2 Dataset Strategy (layered)

A search of Kaggle and GitHub (2026-10-03) found several community datasets
(A-Z Medicine Dataset of India, Extensive A-Z Medicines Dataset, India
Medicines and Drug Info Dataset, Indian Pharmaceutical Products). Their pages
state no clear licence; one says its data is from 1mg, and the field layout of
the §7.1 dataset matches this family. They are probably one lineage, so extra
community datasets add little coverage and carry the same licensing doubt.
This is unconfirmed for the §7.1 dataset.

Official sources to evaluate for licence and format:

-   Jan Aushadhi (PMBJP) product list: government generic medicines with MRP.
-   National List of Essential Medicines (NLEM 2022): essential medicines by
    form and strength.
-   NPPA ceiling prices: official prices for scheduled formulations.

A government publication is not automatically openly licensed; check each.

Layers, each tagged by the record `source` field:

1.  **Core generics (official sources):** safe to ship if licences allow.
2.  **Brand layer (community dataset):** development and demo; ship only after
    §28 #1 is resolved.
3.  **User-entered medicines:** always available (§5.1).

The app must remain fully usable with layers 1 and 3 alone.

### 7.3 Search Requirements (measured 2026-10-03)

Names differ between sources and from what people read off a bottle. The
community dataset stores base ingredient names (`Ambroxol`); Jan Aushadhi names
include salts and strengths in a different order (`Ambroxol Hydrochloride 15 mg,
Guaifenesin 50 mg and Levosalbutamol Sulphate 1 mg Syrup`); users type
misspellings (`Levosalbutanol`, `Ambroxal`, `guaiphenesin`).

Search must therefore:

-   ignore word order;
-   ignore salt and form words (hydrochloride, sulphate, sodium, syrup, ...);
-   map known alternate spellings (guaiphenesin/guaifenesin, acetaminophen/
    paracetamol);
-   spell-correct words against the dataset vocabulary, but never change numbers;
-   search brand names and ingredients in one box;
-   work fully offline and answer fast enough to feel instant on a mid-range phone.

A prototype (`tools/search_reference.py`) reached 99.6% top-1 on noisy
ingredient queries and 79.5% on noisy brand queries (plain substring matching:
7.1% and 19.1%). The queries are synthetic; a real-query test set is still needed.

The community dataset keeps only two compositions per product, so products with
three or more ingredients are incomplete; the pipeline must recover the count
from the name and prefer sources with full compositions.

## 8. Local-First Architecture

> **The core medication experience must work without the cloud.**

### Local responsibilities

-   user profile
-   medicine database
-   medication plans
-   schedules
-   dose logs
-   inventory
-   refill history
-   notification schedules
-   settings

### Cloud responsibilities

-   authentication
-   backup
-   multi-device synchronization
-   caregiver sharing
-   remote synchronization

Recommended initial cloud technology:

-   Firebase Authentication
-   Cloud Firestore

Firebase must not be required for ordinary medication reminders.

### 8.1 Backend Decision

**Reindeer does not need a custom backend server.**

-   The MVP ships with no backend at all: the medicine database is a bundled
    SQLite file, and everything else is on-device.
-   Medicine data updates (later) can be shipped as a new app version or a
    versioned static file download. This needs no API server.
-   When cloud is introduced (Phase 8), use Firebase as a managed service
    (Auth + Firestore with security rules). That is a backend-as-a-service, not
    a server to build and operate.
-   The one place server code appears is caregiver alerts to another device
    (for example "dose not confirmed"): push delivery needs FCM plus a small
    Cloud Function. This is optional and late.
-   Revisit only if a licensed medicine API, ABDM integration, or server-side
    analytics becomes a real requirement.

## 9. Proposed Technology Stack

### Frontend

-   Flutter
-   Dart
-   Material 3
-   Riverpod
-   GoRouter
-   Lottie

### Local Data

-   SQLite
-   Drift

### Notifications

-   Flutter local notifications / platform notification APIs

### Cloud

-   Firebase Authentication
-   Cloud Firestore

Cloud functionality should be introduced only after the local-first core
is stable.

## 10. Proposed Feature Architecture

The existing project should evolve rather than be discarded.

Recommended future structure:

``` text
features/
├── home/
├── medications/
├── medicine_database/
├── treatment/
├── adherence/
├── inventory/
├── caregiver/
├── notifications/
├── profile/
└── settings/
```

Where appropriate:

``` text
feature/
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
├── data/
│   ├── models/
│   ├── datasources/
│   └── repositories/
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

Do not create unnecessary abstractions. Architecture should remain
proportional to the project.

## 11. Core Domain Model

Conceptually:

``` text
User
 ├── MedicationPlan
 │    ├── Medicine
 │    ├── Schedule
 │    ├── Inventory
 │    └── DoseLog
 │
 ├── CaregiverRelationship
 │
 └── Settings
```

### Medicine

Information from the medicine database.

### MedicationPlan

The user's actual use of a medicine.

Example:

``` text
Medicine:
Dolo 650
Paracetamol 650 mg

MedicationPlan:
1 tablet
after breakfast
for 5 days
```

### Schedule

When a medication should be taken.

### DoseLog

What happened with a scheduled dose.

Possible status:

``` text
scheduled
taken
skipped
missed
snoozed
```

### Inventory

The user's physical supply.

Medicine information, treatment instructions, adherence, and inventory
are separate concepts.

### Profiles

A **Profile** owns medication plans. One device holds one or more local
profiles (for example Self, Mom, a child). Every `MedicationPlan`, `DoseLog`,
and inventory record belongs to a profile. The schema includes profiles from
day one even if the MVP UI exposes only one, because retrofitting ownership
later is expensive. A profile requires only a display name; birth year is
optional.

A `MedicationPlan` has at minimum: profile, medicine reference (database id or
custom), dose amount and unit, meal/timing instruction, schedule, start and
end date, optional condition ("what is it for"), optional notes, and a status
(active, paused, discontinued).

## 12. Notifications

The notification system should:

1.  Read schedules from the local database.
2.  Schedule local notifications.
3.  Allow notification actions where supported.
4.  Record the resulting dose action.
5.  Reschedule future notifications.
6.  Recover after application/device restart where required.

Potential actions:

-   Taken
-   Skip
-   Snooze

Do not rely exclusively on background network requests.

### 12.1 Reminder Reliability Requirements (Android first)

A medication reminder that silently fails is the worst failure mode of this
product. Requirements:

-   Request the Android 13+ notification permission with a clear explanation.
-   Handle the exact-alarm permission flow on Android 12+/14+; fall back to
    inexact scheduling with a visible warning rather than failing silently.
-   Reschedule after reboot, app update, and timezone/time change.
-   Schedule a rolling window (for example the next 7 days) and refresh it on
    app open, on boot, and daily. Do not schedule unbounded notifications
    (also required by the iOS pending-notification cap).
-   Guide the user through battery-optimization/autostart settings during
    onboarding. Many Indian-market Android skins (Xiaomi, Oppo, Vivo, Realme,
    Samsung) kill background work aggressively.
-   Provide a "Reminder health check" screen: notification permission, exact
    alarm, battery optimization, and a test notification.
-   If notifications are blocked, show a persistent banner on Today. Never
    imply reminders are active when they are not.
-   Use a high-importance notification channel with user-selectable sound.
-   Test matrix before sign-off: reboot, force-stop, Doze, timezone change,
    notifications denied, app updated.

## 13. Optional Smart Features

Only introduce intelligence after the core product is reliable.

Potential features:

### Adherence pattern detection

``` text
Evening medication has been missed
3 times this week.
```

### Time-pattern analysis

``` text
Most missed doses occur between
8 PM and 10 PM.
```

### Personalized reminder escalation

``` text
8:00 PM → normal reminder
8:30 PM → follow-up
```

AI should not be added merely for the sake of saying the project uses
AI.

## 14. Prescription Input --- Future Extension

Potential workflow:

``` text
Prescription image
       ↓
OCR
       ↓
Medicine extraction
       ↓
Indian medicine database matching
       ↓
User confirmation
       ↓
Treatment plan
```

Extracted information must be confirmed by the user before creating a
medication schedule.

This is a future enhancement, not an MVP prerequisite.

## 15. Indian Digital Health Integration

The architecture should remain compatible with India's digital-health
ecosystem.

Potential future integration:

-   ABHA/ABDM
-   digital prescriptions
-   health-record interoperability
-   consent-based data sharing

However:

> **ABDM integration is not a core dependency of the initial
> application.**

The first version must function independently.

## 16. Privacy and Security Principles

Medication information is sensitive.

Follow:

-   local-first storage
-   minimal cloud data
-   explicit caregiver permissions
-   secure authentication
-   encrypted network communication
-   minimal personal-data collection
-   clear sync controls
-   account-free core usage where practical

### 16.1 Medical Disclaimer and Minors

-   Reindeer organizes and reminds. It does not prescribe, diagnose, or advise
    on dosing. First-run onboarding and the Settings "About" screen state this.
-   Medicine database information is reference data from third-party sources
    and may be incomplete or out of date. Users should follow their doctor's
    prescription and the pharmacist's label.
-   There is no age gate. Profiles may be for children and are expected to be
    managed by a parent or guardian. Collect no more personal data than a
    display name (birth year optional).

## 17. Scope Boundaries

Do not turn the application into:

-   diagnosis
-   medical advice
-   AI doctor functionality
-   symptom diagnosis
-   emergency decision-making
-   hospital marketplace
-   pharmacy marketplace
-   calorie tracking
-   generic fitness tracking
-   comprehensive EHR
-   medical encyclopedia

The product center remains:

> **Medicine discovery → treatment schedule → reminder → adherence →
> inventory → optional caregiver support.**

### 17.1 Features Seen in Competitors and Excluded

| Feature | Why excluded |
|---|---|
| Symptom, mood, measurement (BP, weight, body composition) tracking | Generic health tracking; makes the UI heavy and does not answer the §27 questions |
| Diary / notes section | Per-dose and per-medication notes are enough |
| Appointments and calendar sync | Not medication management |
| Health contacts (doctor, pharmacy, emergency) | Not medication management; the phone dialer exists |
| News / updates feed | Content product, not ours |
| AI chatbot | No real benefit; see §13 |
| Drug-interaction checking | Needs licensed clinical data and carries liability; reconsider only with a vetted source and clear disclaimers |

This list can be revisited after the MVP, one item at a time, using the §27 test.

## 18. MVP

### Must Have

-   Flutter application shell
-   local database
-   Indian medicine database
-   medicine search
-   add medication
-   treatment schedule
-   local reminders
-   taken/skipped/missed tracking
-   today's medication timeline
-   medication history
-   basic adherence percentage
-   medication inventory
-   refill reminder
-   custom (user-entered) medicine fallback
-   notification permission and reminder health check (§12.1)
-   first-run medical disclaimer (§16.1)

**Target platform:** Android first. iOS later, after reminders are proven.

### Should Have

-   progressive medication onboarding
-   adherence charts
-   low-stock warnings
-   multiple medication support
-   medicine source information
-   accessibility improvements
-   multiple local profiles (manage a family member's medicines)
-   shareable adherence report (PDF/image via share sheet)
-   local data export/import (JSON) as backup before cloud exists
-   selectable reminder sound

### Later

-   Firebase authentication
-   cloud backup
-   caregiver sharing
-   caregiver notifications
-   prescription OCR
-   advanced adherence analytics
-   ABDM-related prototype
-   additional regional-language support

## 19. Iterative Development Strategy

The project will be built iteratively with AI-assisted development.

Each iteration:

``` text
Understand
    ↓
Inspect existing code
    ↓
Implement one bounded feature
    ↓
Run/analyze tests
    ↓
Fix issues
    ↓
Review architecture
    ↓
Document important decisions
    ↓
Move to next feature
```

AI coding agents must inspect the existing implementation before
modifying it and should not rewrite working architecture unnecessarily.

## 20. Development Priorities

### Phase 0 --- Foundation

Current:

-   Flutter project
-   Material 3
-   Riverpod
-   GoRouter
-   theme
-   error handling
-   reusable widgets

### Phase 1 --- Local Database

-   Drift/SQLite
-   schema
-   repositories
-   migrations
-   seed/test medicine records
-   profile-owned schema (Profile → MedicationPlan → DoseLog / Inventory)
-   pure-Dart domain models and schedule logic with unit tests

### Phase 2 --- Medicine Database

-   **Gate:** identify the dataset and verify license/redistribution terms before bundling (§28)
-   import Indian medicine dataset
-   normalization
-   search
-   medicine details

### Phase 3 --- Medication Management

-   medication plans
-   treatment builder
-   medication list
-   edit/pause/discontinue

### Phase 4 --- Reminder Engine

-   schedules
-   local notifications
-   notification actions
-   reboot/restart recovery

### Phase 5 --- Adherence

-   dose logs
-   taken/skipped/missed
-   history
-   adherence calculations
-   basic charts

### Phase 6 --- Inventory

-   quantity
-   refill
-   low-stock
-   refill history

### Phase 7 --- Product Polish

-   onboarding
-   accessibility
-   empty states
-   loading/error states
-   animations
-   responsive layouts
-   dark/light themes

### Phase 8 --- Cloud

Only after the local product is stable:

-   Firebase authentication
-   backup
-   sync
-   caregiver sharing

### Phase 9 --- Advanced Features

Only if time permits:

-   prescription OCR
-   adaptive adherence insights
-   ABDM-related prototype
-   additional languages

## 21. Product Success Criteria

The finished application should demonstrate this end-to-end scenario:

> A user searches for an Indian medicine, selects the correct medicine,
> creates a treatment schedule through a guided flow, receives a
> reminder without internet access, records the dose as taken, sees the
> dose reflected in adherence statistics, sees remaining inventory
> decrease, receives a refill warning when appropriate, and can
> optionally share medication status with a caregiver.

That end-to-end workflow is more important than having dozens of
disconnected screens.

## 22. Product Differentiation

The product differentiates through the combination of:

1.  India-aware medicine data.
2.  Local-first medication management.
3.  Progressive treatment creation.
4.  Reliable offline reminders.
5.  Adherence analytics.
6.  Inventory/refill tracking.
7.  Optional caregiver synchronization.

No single feature is assumed to be unique.

## 23. Design Direction

The UI should be:

-   clean
-   calm
-   readable
-   modern
-   approachable
-   information-dense where useful
-   not visually overwhelming

Use animations sparingly.

The most important UI principle:

> **The user should be able to answer "What medicine do I need to take
> now?" immediately after opening the application.**

### 23.1 UI Toolkit Decision (2026-10-03)

Reindeer uses a **custom design system built on Material 3 components**.
Cupertino is not used as the app's look: it feels foreign on Android, has far
fewer components, and the target users rely on familiar patterns. Custom styling
(shape, colour, type, spacing, motion) lives in the theme layer and
`shared/widgets`. Use stock Material widgets wherever a custom one would be
complex or hurt accessibility (text fields, date/time pickers, dialogs, sheets,
navigation semantics). Screens use the shared wrappers so the style can change
in one place.

## 24. Current Repository State

The project currently has:

``` text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── errors/
│   ├── router/
│   ├── theme/
│   └── utils/
├── shared/
│   └── widgets/
└── features/
    ├── home/
    └── settings/
```

Existing foundations include:

-   Material 3
-   Riverpod
-   GoRouter
-   typed Result/AppException handling
-   reusable widgets
-   theme management
-   responsive foundations

The existing foundation should be retained and evolved.

As of 2026-10-03: Home is demo content (architecture stat cards and a test
counter) and must be replaced by the real Today screen; `test/widget_test.dart`
asserts that demo text and will need replacing at the same time. No persistence,
notification, or database packages are installed yet; add each when its phase
starts.

## 25. Source-of-Truth Hierarchy

When decisions conflict:

1.  **Actual repository/code** --- ultimate technical truth.
2.  **This document** --- intended product direction.
3.  **Verified research/source documents** --- evidence for product
    decisions.
4.  **AI-generated suggestions** --- proposals only.

AI coding agents must not treat their own previous output as
authoritative.

If implementation reality conflicts with this document, make an
intentional decision and update this document.

## 26. Definition of Done

A feature is complete when:

-   the user workflow works end-to-end
-   data is persisted correctly
-   errors are handled
-   loading states are handled
-   empty states are handled
-   offline behavior is appropriate
-   notification behavior is tested where applicable
-   multiple medications work correctly
-   architecture remains maintainable
-   UI is consistent
-   duplicate logic is avoided

## 27. Guiding Principle

> **Build a medication-management product, not a collection of health
> features.**

Every feature should answer one of these questions:

-   What medicine am I taking?
-   Why/for what treatment is it recorded?
-   When should I take it?
-   Did I take it?
-   How well am I following my schedule?
-   How much medicine do I have left?
-   Do I need a refill?
-   Can someone I trust help me manage it?

If a proposed feature does not meaningfully support one of these
questions, treat it as scope expansion and evaluate it separately.

## 28. Open Decisions

| # | Decision | Needed by | Current default |
|---|---|---|---|
| 1 | Is redistribution of the chosen dataset (§7.1) permitted? | Before public release | Use for development; provenance unverified |
| 2 | Android only, or iOS too? | Phase 4 | Android first |
| 3 | Hindi (and other regional languages) in MVP or Later? | Phase 7 | Later |
| 4 | Cloud auth method (Google sign-in, email link, phone OTP) | Phase 8 | Google sign-in (avoids SMS cost) |
| 5 | Caregiver model: invite code, link by email, or QR | Phase 8 | Invite code, patient-controlled permissions |
| 6 | Hard deadline / demo date for the college submission | Now | Unknown; determines how much of Phases 5–8 is realistic |
| 7 | ~~UI toolkit~~ | Decided | Custom design system on Material 3 (§23.1) |
| 8 | v1 scope and order of work | Decided | See `docs/ROADMAP.md` |

## 29. Differentiator Candidates (portfolio track)

Candidates only; none is committed. Each passes the §27 test and none is added
to the MVP. Pick two or three after the core workflow works end to end.

| Candidate | What it is | Why it is meaningful | Risk |
|---|---|---|---|
| Indian prescription shorthand | The v1 add-medication wizard shows `1-0-1` as three big Morning / Afternoon / Night tiles with steppers and before/after-food buttons. Typing a line such as `1-0-1 x 5 days AC` (`BD`, `TDS`, `SOS`, `HS`) is a later optional shortcut that fills the same screen for confirmation | India-specific, deterministic, testable offline; simple enough for older users because they never see the notation | Low |
| Typo-tolerant offline brand search with a measured accuracy score | Ranked FTS plus spelling and word-start handling; a fixed noisy-query test set reports top-1/top-3 accuracy | Gives a real number for the README | Low |
| Same-composition finder | Group brands by identical composition and strength; show them as information with a "ask your doctor or pharmacist" notice, never as advice to switch | India-specific; uses data already being normalized | Medium (wording, stale prices) |
| Meal-anchored schedules (**planned for v1**) | Set breakfast, lunch, dinner, sleep once; "after breakfast" resolves to a time; "shift my day by 2h" (later) moves dependent doses | Many medicines are taken relative to food; also handles travel and fasting | Medium |
| Refill date prediction and shareable refill list | "Runs out on 14 Oct"; share a refill list through the system share sheet (for example to WhatsApp) | Practical, simple, in scope | Low |
| End-to-end encrypted caregiver sharing | Only ciphertext is stored in Firestore; the key travels in the invite QR | Strong privacy story; relevant to India's Digital Personal Data Protection Act, 2023 | High |
| Pack barcode / QR scan (v1.1) | Scan a pack and use the decoded text to find the medicine, then confirm. Since 2023-08-01, the top 300 brand drugs (for example Dolo 650, Calpol, Combiflam) must carry a barcode or QR encoding a product code, name, manufacturer, batch, manufacturing and expiry dates and licence number | Fast, accurate entry; expiry date as a bonus | Medium: code contents vary by manufacturer, older stock and many brands have none, so test on real packs and always fall back to search |
| Strip or prescription scan | On-device OCR matched against the database, always confirmed by the user | Flagship demo; printed text is feasible, handwriting is not reliable | High |

Portfolio packaging: CI running analyze and tests, a README with architecture
and measured results, a short demo video, and a written note on the
local-first and privacy decisions.
