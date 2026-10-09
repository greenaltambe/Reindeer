import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Schema v6 & Repositories Test', () {
    late Database db;
    late PlanRepository planRepo;
    late DoseLogRepository doseLogRepo;
    late MissReasonRepository missReasonRepo;

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, version) async {
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
            await db.execute('''
              CREATE TABLE plan_versions(
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
            await db.execute('''
              CREATE TABLE plan_pauses(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER NOT NULL,
                paused_at TEXT NOT NULL,
                resumed_at TEXT,
                reason TEXT
              )''');
            await db.execute('''
              CREATE TABLE miss_reasons(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER NOT NULL,
                dose_date TEXT NOT NULL,
                slot TEXT NOT NULL,
                reason TEXT NOT NULL,
                note TEXT,
                at TEXT NOT NULL,
                UNIQUE(plan_id, dose_date, slot)
              )''');
            await db.execute('''
              CREATE TABLE refills(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER NOT NULL,
                quantity REAL NOT NULL,
                at TEXT NOT NULL
              )''');
          },
        ),
      );
      planRepo = PlanRepository(db);
      doseLogRepo = DoseLogRepository(db);
      missReasonRepo = MissReasonRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('inserting plan automatically creates initial plan_version', () async {
      final id = await planRepo.insert(
        MedicationPlan(
          profileId: 'me',
          name: 'Telmisartan 40mg',
          doseUnit: DoseUnit.tablet,
          slotAmounts: const {DaySlot.morning: 1.0},
          startDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1, 9, 0),
        ),
      );

      final plan = await planRepo.byId(id);
      expect(plan, isNotNull);
      expect(plan!.versions, isNotNull);
      expect(plan.versions!.length, 1);
      expect(plan.versions!.first.changeReason, 'Initial prescription');
      expect(plan.versions!.first.amountFor(DaySlot.morning), 1.0);
    });

    test(
      'updating plan schedule creates a new version with effective_from',
      () async {
        final id = await planRepo.insert(
          MedicationPlan(
            profileId: 'me',
            name: 'Telmisartan 40mg',
            doseUnit: DoseUnit.tablet,
            slotAmounts: const {DaySlot.morning: 1.0},
            startDate: DateTime(2026, 10, 1),
            createdAt: DateTime(2026, 10, 1, 9, 0),
          ),
        );

        await planRepo.updatePlanSchedule(
          planId: id,
          slotAmounts: const {DaySlot.morning: 1.0, DaySlot.night: 0.5},
          mealTiming: MealTiming.afterFood,
          effectiveFrom: DateTime(2026, 10, 10),
          changeReason: 'Doctor added evening half tablet',
        );

        final plan = await planRepo.byId(id);
        expect(plan!.versions!.length, 2);
        expect(plan.versions![1].effectiveFrom, DateTime(2026, 10, 10));
        expect(
          plan.versions![1].changeReason,
          'Doctor added evening half tablet',
        );
        expect(plan.versions![1].amountFor(DaySlot.night), 0.5);
      },
    );

    test('miss reasons round-trip with notes and summary counts', () async {
      await missReasonRepo.record(
        planId: 1,
        doseDate: '2026-10-09',
        slot: DaySlot.morning,
        reason: MissReasonType.ranOut,
        note: 'Pharmacy was closed',
      );

      await missReasonRepo.record(
        planId: 1,
        doseDate: '2026-10-09',
        slot: DaySlot.night,
        reason: MissReasonType.sideEffect,
        note: 'Felt dizzy after standing up',
      );

      final reasonMorning = await missReasonRepo.get(
        1,
        '2026-10-09',
        DaySlot.morning,
      );
      expect(reasonMorning, isNotNull);
      expect(reasonMorning!.reason, MissReasonType.ranOut);
      expect(reasonMorning.note, 'Pharmacy was closed');

      final summary = await missReasonRepo.summaryBetween(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
      );
      expect(summary[MissReasonType.ranOut], 1);
      expect(summary[MissReasonType.sideEffect], 1);

      final notes = await missReasonRepo.notesBetween(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
      );
      expect(notes.length, 2);
    });

    test(
      'dose log repository records and queries using stable dose identity',
      () async {
        final p = MedicationPlan(
          profileId: 'me',
          name: 'Amlodipine',
          doseUnit: DoseUnit.tablet,
          slotAmounts: const {DaySlot.morning: 1.0},
          startDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
        );
        final planId = await planRepo.insert(p);
        final dose = PlannedDose(
          planId: planId,
          at: DateTime(2026, 10, 9, 8, 30),
          slot: DaySlot.morning,
          amount: 1.0,
        );

        await doseLogRepo.record(
          dose: dose,
          status: DoseStatus.taken,
          now: DateTime(2026, 10, 9, 8, 32),
        );

        final logs = await doseLogRepo.between(
          DateTime(2026, 10, 9),
          DateTime(2026, 10, 9),
        );
        expect(logs.containsKey(dose.key), isTrue);
        expect(logs[dose.key]!.status, DoseStatus.taken);
        expect(logs[dose.key]!.slot, DaySlot.morning);
        expect(logs[dose.key]!.doseDate, '2026-10-09');
      },
    );
  });
}
