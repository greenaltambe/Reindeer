import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's own SQLite database (profiles, plans, dose logs, settings).
///
/// This is separate from the read-only medicine database; see
/// `MedicineDatabase`.
abstract final class AppDatabase {
  static const int _version = 6;
  static const String fileName = 'reindeer.db';
  static const String defaultProfileId = 'me';

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, fileName),
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        birth_year INTEGER,
        height_cm REAL
      )''');
    await db.execute('''
      CREATE TABLE plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        medicine_id INTEGER,
        name TEXT NOT NULL,
        composition TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL,
        condition TEXT,
        dose_unit TEXT NOT NULL,
        morning REAL NOT NULL DEFAULT 0,
        afternoon REAL NOT NULL DEFAULT 0,
        night REAL NOT NULL DEFAULT 0,
        meal_timing TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT NOT NULL,
        stopped_at TEXT,
        resumed_at TEXT,
        stock REAL,
        low_threshold REAL,
        pack_qty REAL,
        created_at TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 1,
        weekdays INTEGER NOT NULL DEFAULT 0,
        alt_morning REAL,
        alt_afternoon REAL,
        alt_night REAL
      )''');
    await db.execute('''
      CREATE TABLE dose_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        dose_date TEXT NOT NULL,
        slot TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL,
        acted_at TEXT NOT NULL,
        amount REAL NOT NULL,
        UNIQUE(plan_id, dose_date, slot)
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS dose_logs_date ON dose_logs(dose_date)',
    );
    await db.execute('''
      CREATE TABLE refills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        at TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS refills_plan ON refills(plan_id)',
    );
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _createDotsTable(db);
    await _createV6Tables(db);
    await db.insert('profiles', {'id': defaultProfileId, 'name': 'Me'});
  }

  /// Upgrades through versions 1 -> 6.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE profiles ADD COLUMN height_cm REAL');
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
    }
    if (oldVersion < 4) {
      await _addPlanScheduleColumns(db);
    }
    if (oldVersion < 5) {
      await _createDotsTable(db);
    }
    if (oldVersion < 6) {
      await _upgradeToV6(db);
    }
  }

  /// Version 6: stable dose identity, plan versions, pause windows, miss reasons.
  static Future<void> _createV6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_versions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        effective_from TEXT NOT NULL,
        morning REAL NOT NULL DEFAULT 0,
        afternoon REAL NOT NULL DEFAULT 0,
        night REAL NOT NULL DEFAULT 0,
        meal_timing TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 1,
        weekdays INTEGER NOT NULL DEFAULT 0,
        alt_morning REAL,
        alt_afternoon REAL,
        alt_night REAL,
        change_reason TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS plan_versions_eff ON plan_versions(plan_id, effective_from)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_pauses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        paused_at TEXT NOT NULL,
        resumed_at TEXT,
        reason TEXT
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS plan_pauses_plan ON plan_pauses(plan_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS miss_reasons(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        dose_date TEXT NOT NULL,
        slot TEXT NOT NULL,
        reason TEXT NOT NULL,
        note TEXT,
        at TEXT NOT NULL,
        UNIQUE(plan_id, dose_date, slot)
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS miss_reasons_date ON miss_reasons(dose_date)',
    );
  }

  static Future<void> _upgradeToV6(Database db) async {
    await _createV6Tables(db);

    // 1. Upgrade dose_logs to include dose_date and slot with UNIQUE constraint
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dose_logs_v6(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        dose_date TEXT NOT NULL,
        slot TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL,
        acted_at TEXT NOT NULL,
        amount REAL NOT NULL,
        UNIQUE(plan_id, dose_date, slot)
      )''');

    // Populate dose_logs_v6 from existing dose_logs
    try {
      await db.execute('''
        INSERT OR REPLACE INTO dose_logs_v6 (
          id, plan_id, dose_date, slot, scheduled_at, status, acted_at, amount
        )
        SELECT
          id,
          plan_id,
          SUBSTR(scheduled_at, 1, 10),
          CASE
            WHEN CAST(SUBSTR(scheduled_at, 12, 2) AS INTEGER) < 12 THEN 'morning'
            WHEN CAST(SUBSTR(scheduled_at, 12, 2) AS INTEGER) < 17 THEN 'afternoon'
            ELSE 'night'
          END,
          scheduled_at,
          status,
          acted_at,
          amount
        FROM dose_logs
      ''');
      await db.execute('DROP TABLE dose_logs');
      await db.execute('ALTER TABLE dose_logs_v6 RENAME TO dose_logs');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS dose_logs_date ON dose_logs(dose_date)',
      );
    } catch (_) {
      // If table already has correct schema or is empty, continue
    }

    // 2. Populate initial plan_versions from existing plans
    try {
      await db.execute('''
        INSERT OR IGNORE INTO plan_versions (
          plan_id, effective_from, morning, afternoon, night,
          meal_timing, interval_days, weekdays, alt_morning, alt_afternoon, alt_night,
          change_reason, created_at
        )
        SELECT
          id,
          SUBSTR(start_date, 1, 10),
          morning,
          afternoon,
          night,
          meal_timing,
          interval_days,
          weekdays,
          alt_morning,
          alt_afternoon,
          alt_night,
          'Initial prescription',
          created_at
        FROM plans
      ''');
    } catch (_) {}

    // 3. Populate plan_pauses from existing plans that have stopped_at
    try {
      await db.execute('''
        INSERT OR IGNORE INTO plan_pauses (plan_id, paused_at, resumed_at, reason)
        SELECT id, stopped_at, resumed_at, 'Previous pause'
        FROM plans WHERE stopped_at IS NOT NULL
      ''');
    } catch (_) {}

    // 4. Drop dead barcode_links table
    await db.execute('DROP TABLE IF EXISTS barcode_links');
  }

  /// Version 5: doses a TB treatment supporter watched being taken.
  static Future<void> _createDotsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dots_observations(
        plan_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        observer TEXT NOT NULL,
        at TEXT NOT NULL,
        PRIMARY KEY(plan_id, scheduled_at)
      )''');
  }

  /// Version 4: doses on some days only, and a second set of amounts.
  static Future<void> _addPlanScheduleColumns(Database db) async {
    await db.execute(
      'ALTER TABLE plans ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE plans ADD COLUMN weekdays INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE plans ADD COLUMN alt_morning REAL');
    await db.execute('ALTER TABLE plans ADD COLUMN alt_afternoon REAL');
    await db.execute('ALTER TABLE plans ADD COLUMN alt_night REAL');
  }

  /// Tables added in version 3: allergies and the symptom diary.
  static Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS allergies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        name TEXT NOT NULL,
        UNIQUE(profile_id, name)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS symptoms(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        symptom TEXT NOT NULL,
        severity INTEGER NOT NULL,
        note TEXT,
        logged_at TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS symptoms_time ON symptoms(logged_at)',
    );
  }

  /// Tables added in version 2 (also created on a fresh install).
  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profile_conditions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        name TEXT NOT NULL,
        UNIQUE(profile_id, name)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS measurements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        value2 REAL,
        context TEXT,
        measured_at TEXT NOT NULL,
        note TEXT
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS measurements_type_time ON measurements(type, measured_at)',
    );
  }
}

/// The app database. Overridden in `main` once the database is open.
final appDatabaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

/// Bumped after every write so providers that read the database refresh.
class DataVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final dataVersionProvider = NotifierProvider<DataVersionNotifier, int>(
  DataVersionNotifier.new,
);
