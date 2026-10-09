import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/models/plan_version.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes [MedicationPlan]s, [PlanVersion]s, and [PlanPause]s.
class PlanRepository {
  PlanRepository(this._db);

  final Database _db;

  Future<List<MedicationPlan>> all() async {
    final rows = await _db.query('plans', orderBy: 'id ASC');
    final plans = <MedicationPlan>[];
    for (final r in rows) {
      final p = _fromRow(r);
      final id = p.id;
      if (id != null) {
        final versions = await versionsFor(id);
        final pauses = await pausesFor(id);
        plans.add(p.copyWith(versions: versions, pauses: pauses));
      } else {
        plans.add(p);
      }
    }
    return plans;
  }

  Future<MedicationPlan?> byId(int id) async {
    final rows = await _db.query(
      'plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final plan = _fromRow(rows.first);
    final versions = await versionsFor(id);
    final pauses = await pausesFor(id);
    return plan.copyWith(versions: versions, pauses: pauses);
  }

  /// Saves a new plan and creates its initial version in [plan_versions].
  Future<int> insert(MedicationPlan plan) async {
    return await _db.transaction((txn) async {
      final id = await txn.insert('plans', _toRow(plan));
      await txn.insert('plan_versions', {
        'plan_id': id,
        'effective_from': isoDate(plan.startDate),
        'morning': plan.amountFor(DaySlot.morning),
        'afternoon': plan.amountFor(DaySlot.afternoon),
        'night': plan.amountFor(DaySlot.night),
        'meal_timing': plan.mealTiming.name,
        'interval_days': plan.intervalDays,
        'weekdays': plan.weekdays,
        'alt_morning': plan.altAmounts?[DaySlot.morning],
        'alt_afternoon': plan.altAmounts?[DaySlot.afternoon],
        'alt_night': plan.altAmounts?[DaySlot.night],
        'change_reason': 'Initial prescription',
        'created_at': plan.createdAt.toIso8601String(),
      });
      return id;
    });
  }

  /// Creates a new version for a plan effective from [effectiveFrom], preserving
  /// all past history.
  Future<void> updatePlanSchedule({
    required int planId,
    required Map<DaySlot, double> slotAmounts,
    required MealTiming mealTiming,
    int intervalDays = 1,
    int weekdays = 0,
    Map<DaySlot, double>? altAmounts,
    required DateTime effectiveFrom,
    String? changeReason,
  }) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      await txn.insert('plan_versions', {
        'plan_id': planId,
        'effective_from': isoDate(effectiveFrom),
        'morning': slotAmounts[DaySlot.morning] ?? 0,
        'afternoon': slotAmounts[DaySlot.afternoon] ?? 0,
        'night': slotAmounts[DaySlot.night] ?? 0,
        'meal_timing': mealTiming.name,
        'interval_days': intervalDays,
        'weekdays': weekdays,
        'alt_morning': altAmounts?[DaySlot.morning],
        'alt_afternoon': altAmounts?[DaySlot.afternoon],
        'alt_night': altAmounts?[DaySlot.night],
        'change_reason': changeReason ?? 'Prescription adjusted',
        'created_at': now.toIso8601String(),
      });
      await txn.update(
        'plans',
        {
          'morning': slotAmounts[DaySlot.morning] ?? 0,
          'afternoon': slotAmounts[DaySlot.afternoon] ?? 0,
          'night': slotAmounts[DaySlot.night] ?? 0,
          'meal_timing': mealTiming.name,
          'interval_days': intervalDays,
          'weekdays': weekdays,
          'alt_morning': altAmounts?[DaySlot.morning],
          'alt_afternoon': altAmounts?[DaySlot.afternoon],
          'alt_night': altAmounts?[DaySlot.night],
        },
        where: 'id = ?',
        whereArgs: [planId],
      );
    });
  }

  /// Sets status and manages pause windows in [plan_pauses].
  Future<void> setStatus(int id, PlanStatus status, DateTime now) async {
    final current = await byId(id);
    if (current == null) return;
    await _db.transaction((txn) async {
      if (status == PlanStatus.active) {
        // Resume ongoing pause if any
        await txn.rawUpdate(
          '''
          UPDATE plan_pauses
          SET resumed_at = ?
          WHERE plan_id = ? AND resumed_at IS NULL
        ''',
          [isoDateTime(now), id],
        );
        await txn.update(
          'plans',
          {'status': status.name, 'resumed_at': isoDateTime(now)},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else if (status == PlanStatus.paused) {
        // Start pause window
        await txn.insert('plan_pauses', {
          'plan_id': id,
          'paused_at': isoDateTime(now),
          'resumed_at': null,
          'reason': 'Paused by patient/caregiver',
        });
        await txn.update(
          'plans',
          {
            'status': status.name,
            'stopped_at': isoDateTime(now),
            'resumed_at': null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // Discontinued
        if (current.isActive) {
          await txn.insert('plan_pauses', {
            'plan_id': id,
            'paused_at': isoDateTime(now),
            'resumed_at': null,
            'reason': 'Stopped by doctor / discontinued',
          });
        }
        await txn.update(
          'plans',
          {'status': status.name, 'stopped_at': isoDateTime(now)},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('dose_logs', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('miss_reasons', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('refills', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('plan_versions', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('plan_pauses', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete(
        'dots_observations',
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      await txn.delete('plans', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Adds [quantity] to the stock and records a refill.
  Future<void> refill(int id, double quantity, DateTime now) async {
    await _db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE plans SET stock = COALESCE(stock, 0) + ? WHERE id = ?',
        [quantity, id],
      );
      await txn.insert('refills', {
        'plan_id': id,
        'quantity': quantity,
        'at': now.toIso8601String(),
      });
    });
  }

  /// Loads all versions of a plan, sorted earliest to latest.
  Future<List<PlanVersion>> versionsFor(int planId) async {
    final rows = await _db.query(
      'plan_versions',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'effective_from ASC, id ASC',
    );
    return rows.map(_versionFromRow).toList();
  }

  /// Loads all pause windows for a plan.
  Future<List<PlanPause>> pausesFor(int planId) async {
    final rows = await _db.query(
      'plan_pauses',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'paused_at ASC',
    );
    return rows.map(_pauseFromRow).toList();
  }

  Map<String, Object?> _toRow(MedicationPlan p) => {
    'profile_id': p.profileId,
    'medicine_id': p.medicineId,
    'name': p.name,
    'composition': p.composition,
    'kind': p.kind.name,
    'condition': p.condition,
    'dose_unit': p.doseUnit.name,
    'morning': p.amountFor(DaySlot.morning),
    'afternoon': p.amountFor(DaySlot.afternoon),
    'night': p.amountFor(DaySlot.night),
    'meal_timing': p.mealTiming.name,
    'start_date': isoDate(p.startDate),
    'end_date': p.endDate == null ? null : isoDate(p.endDate!),
    'status': p.status.name,
    'stopped_at': p.stoppedAt == null ? null : isoDateTime(p.stoppedAt!),
    'resumed_at': p.resumedAt == null ? null : isoDateTime(p.resumedAt!),
    'stock': p.stock,
    'low_threshold': p.lowStockThreshold,
    'pack_qty': p.packQty,
    'created_at': p.createdAt.toIso8601String(),
    'interval_days': p.intervalDays,
    'weekdays': p.weekdays,
    'alt_morning': p.altAmounts?[DaySlot.morning],
    'alt_afternoon': p.altAmounts?[DaySlot.afternoon],
    'alt_night': p.altAmounts?[DaySlot.night],
  };

  MedicationPlan _fromRow(Map<String, Object?> r) {
    double? num_(String key) => (r[key] as num?)?.toDouble();
    return MedicationPlan(
      id: r['id'] as int,
      profileId: r['profile_id'] as String,
      medicineId: r['medicine_id'] as int?,
      name: r['name'] as String,
      composition: (r['composition'] as String?) ?? '',
      kind: MedicineKind.fromName(r['kind'] as String?),
      condition: r['condition'] as String?,
      doseUnit: DoseUnit.fromName(r['dose_unit'] as String?),
      slotAmounts: {
        DaySlot.morning: num_('morning') ?? 0,
        DaySlot.afternoon: num_('afternoon') ?? 0,
        DaySlot.night: num_('night') ?? 0,
      },
      mealTiming: MealTiming.fromName(r['meal_timing'] as String?),
      startDate: parseIso(r['start_date'] as String),
      endDate: r['end_date'] == null ? null : parseIso(r['end_date'] as String),
      status: PlanStatus.fromName(r['status'] as String?),
      stoppedAt: r['stopped_at'] == null
          ? null
          : parseIso(r['stopped_at'] as String),
      resumedAt: r['resumed_at'] == null
          ? null
          : parseIso(r['resumed_at'] as String),
      stock: num_('stock'),
      lowStockThreshold: num_('low_threshold'),
      packQty: num_('pack_qty'),
      createdAt: parseIso(r['created_at'] as String),
      intervalDays: (r['interval_days'] as num?)?.toInt() ?? 1,
      weekdays: (r['weekdays'] as num?)?.toInt() ?? 0,
      altAmounts:
          r['alt_morning'] == null &&
              r['alt_afternoon'] == null &&
              r['alt_night'] == null
          ? null
          : {
              DaySlot.morning: num_('alt_morning') ?? 0,
              DaySlot.afternoon: num_('alt_afternoon') ?? 0,
              DaySlot.night: num_('alt_night') ?? 0,
            },
    );
  }

  PlanVersion _versionFromRow(Map<String, Object?> r) {
    double? num_(String key) => (r[key] as num?)?.toDouble();
    return PlanVersion(
      id: r['id'] as int?,
      planId: r['plan_id'] as int,
      effectiveFrom: parseIso(r['effective_from'] as String),
      slotAmounts: {
        DaySlot.morning: num_('morning') ?? 0,
        DaySlot.afternoon: num_('afternoon') ?? 0,
        DaySlot.night: num_('night') ?? 0,
      },
      mealTiming: MealTiming.fromName(r['meal_timing'] as String?),
      intervalDays: (r['interval_days'] as num?)?.toInt() ?? 1,
      weekdays: (r['weekdays'] as num?)?.toInt() ?? 0,
      altAmounts:
          r['alt_morning'] == null &&
              r['alt_afternoon'] == null &&
              r['alt_night'] == null
          ? null
          : {
              DaySlot.morning: num_('alt_morning') ?? 0,
              DaySlot.afternoon: num_('alt_afternoon') ?? 0,
              DaySlot.night: num_('alt_night') ?? 0,
            },
      changeReason: r['change_reason'] as String?,
      createdAt: parseIso(r['created_at'] as String),
    );
  }

  PlanPause _pauseFromRow(Map<String, Object?> r) => PlanPause(
    id: r['id'] as int?,
    planId: r['plan_id'] as int,
    pausedAt: parseIso(r['paused_at'] as String),
    resumedAt: r['resumed_at'] == null
        ? null
        : parseIso(r['resumed_at'] as String),
    reason: r['reason'] as String?,
  );
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(ref.watch(appDatabaseProvider)),
);

/// All plans (any status); refreshes after any write.
final plansProvider = FutureProvider<List<MedicationPlan>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(planRepositoryProvider).all();
});
