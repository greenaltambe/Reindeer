import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes [MedicationPlan]s in the app database.
class PlanRepository {
  PlanRepository(this._db);

  final Database _db;

  Future<List<MedicationPlan>> all() async {
    final rows = await _db.query('plans', orderBy: 'id ASC');
    return rows.map(_fromRow).toList();
  }

  Future<MedicationPlan?> byId(int id) async {
    final rows = await _db.query(
      'plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Saves a new plan and returns its id.
  Future<int> insert(MedicationPlan plan) => _db.insert('plans', _toRow(plan));

  Future<void> setStatus(int id, PlanStatus status, DateTime now) async {
    final current = await byId(id);
    if (current == null) return;
    final Map<String, Object?> values;
    if (status == PlanStatus.active) {
      // Keep stopped_at: it marks the start of the pause window.
      values = {'status': status.name, 'resumed_at': isoDateTime(now)};
    } else if (current.isActive) {
      values = {
        'status': status.name,
        'stopped_at': isoDateTime(now),
        'resumed_at': null,
      };
    } else {
      // Paused -> stopped: the plan has been inactive since the pause began.
      values = {'status': status.name};
    }
    await _db.update('plans', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('dose_logs', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('refills', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('plans', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Adds [quantity] to the stock (starting from 0 if untracked) and records a refill.
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
    );
  }
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(ref.watch(appDatabaseProvider)),
);

/// All plans (any status); refreshes after any write.
final plansProvider = FutureProvider<List<MedicationPlan>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(planRepositoryProvider).all();
});
