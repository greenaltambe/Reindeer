# Architecture (v1)

Flutter + Material 3, Riverpod for state, go_router for navigation, sqflite for storage.
Everything runs on the device; there is no backend.

## Layers

Each feature folder follows `domain` (plain Dart models and rules), `data` (SQLite
repositories), `application` (actions that change data), `presentation` (screens).
Domain code has no Flutter or database imports, so it is easy to unit test.

## Two databases

| Database | Where | Purpose |
|---|---|---|
| `medicines.db` | bundled as `assets/db/medicines.db.gz`, unpacked once on first launch (version marker in `medicine_database.dart`) | read-only: medicines, ingredient index, conditions |
| `reindeer.db` | app databases folder, schema version 2 with `onUpgrade` | profile, conditions, plans, dose logs, refills, measurements, barcode links, settings |

After every write, `dataVersionProvider` is bumped so providers that read the database
refresh.

## Doses and adherence

- A plan stores amounts per slot (morning / afternoon / night), meal timing, course dates,
  pause window (`stoppedAt`, `resumedAt`) and stock.
- Doses are **derived** from the plan and the person's meal times, never stored in advance.
  Editing a plan therefore never rewrites history.
- Only actions are stored in `dose_logs` (taken or skipped). A dose is "missed" if it is
  more than 2 hours old with no log. Adherence = taken / (taken + skipped + missed).
- Taking a dose reduces stock; low stock is flagged by a unit threshold or under 3 days.

## Reminders (`features/reminders/reminder_service.dart`)

- `flutter_local_notifications` with exact alarms where allowed, otherwise inexact.
- A rolling 7-day window is rescheduled on start, resume and after any change.
- Taken / Skip / Snooze buttons work with the app open (foreground handler) and closed
  (background isolate that opens the database itself).
- Snooze ids end in 5-7 and survive a reschedule. Measurement reminders use ids
  `9000000 + type * 10` and repeat daily or weekly.

## Search

`medicine_search_service.dart` is a Dart port of `tools/search_reference.py`, checked by
`test/search_parity_test.dart` against fixtures produced by the Python version. See
`docs/DATA.md`. Conditions are searched by `condition_search_service.dart` (word-prefix
match over names and everyday aliases such as "bp" or "sugar").

## Health tab

`MeasureType` (weight, blood pressure, blood sugar, body fat, pulse) and `Measurement`
live in `features/health/domain`. Blood pressure uses `value` and `value2`. Reminders are
stored as settings keys `mrem_<type>` = `HH:MM|daily` or `HH:MM|w<weekday>`. Charts are a
small custom painter (`trend_chart.dart`). Readings are never interpreted.

## Navigation

Five tabs (Today, Medicines, Health, Progress, Settings) in a `StatefulShellRoute`. The
add-medicine wizard, scanner, onboarding and profile are full-screen routes.
