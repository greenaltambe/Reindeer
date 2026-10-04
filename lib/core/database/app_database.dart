import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's own SQLite database (profiles, plans, dose logs, settings).
///
/// This is separate from the read-only medicine database; see
/// `MedicineDatabase`.
abstract final class AppDatabase {
  static const int _version = 2;
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
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE dose_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL,
        acted_at TEXT NOT NULL,
        amount REAL NOT NULL,
        UNIQUE(plan_id, scheduled_at)
      )''');
    await db.execute('''
      CREATE TABLE refills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await _createV2Tables(db);
    await db.insert('profiles', {'id': defaultProfileId, 'name': 'Me'});
  }

  /// v1 -> v2: profile details, conditions, health readings, barcode links.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE profiles ADD COLUMN height_cm REAL');
      await _createV2Tables(db);
    }
  }

  /// Tables added in version 2 (also created on a fresh install).
  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS barcode_links(
        key TEXT PRIMARY KEY,
        medicine_id INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )''');
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
