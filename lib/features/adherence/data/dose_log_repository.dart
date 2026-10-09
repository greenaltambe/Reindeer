import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes [DoseLog]s, and keeps plan stock in step with them.
class DoseLogRepository {
  DoseLogRepository(this._db);

  final Database _db;

  /// Logs for doses scheduled on days [fromDay]..[toDay] inclusive, keyed by
  /// [PlannedDose.key] (`planId|doseDate|slot`).
  Future<Map<String, DoseLog>> between(DateTime fromDay, DateTime toDay) async {
    final fromDate = isoDate(fromDay);
    final toDate = isoDate(toDay);
    final fromTime = isoDateTime(dateOnly(fromDay));
    final toTime = isoDateTime(nextDay(dateOnly(toDay)));

    final rows = await _db.query(
      'dose_logs',
      where: '(dose_date >= ? AND dose_date <= ?) OR (scheduled_at >= ? AND scheduled_at < ?)',
      whereArgs: [fromDate, toDate, fromTime, toTime],
    );
    final out = <String, DoseLog>{};
    for (final r in rows) {
      final planId = r['plan_id'] as int;
      final scheduledAt = parseIso(r['scheduled_at'] as String);
      final rawDate = r['dose_date'] as String?;
      final rawSlot = r['slot'] as String?;
      final slot = rawSlot != null
          ? DaySlot.fromName(rawSlot)
          : (scheduledAt.hour < 12
                ? DaySlot.morning
                : (scheduledAt.hour < 17 ? DaySlot.afternoon : DaySlot.night));
      final doseDate = rawDate ?? isoDate(scheduledAt);
      final log = DoseLog(
        id: r['id'] as int,
        planId: planId,
        doseDate: doseDate,
        slot: slot,
        scheduledAt: scheduledAt,
        status: DoseStatus.fromName(r['status'] as String?),
        actedAt: parseIso(r['acted_at'] as String),
        amount: (r['amount'] as num).toDouble(),
      );
      // Modern stable key
      out['$planId|$doseDate|${slot.name}'] = log;
      // Also legacy key for backwards compatibility
      out['$planId|${isoDateTime(scheduledAt)}'] = log;
    }
    return out;
  }

  /// Records [status] (taken or skipped) for [dose].
  ///
  /// Taking a dose reduces the plan's tracked stock; changing a taken dose to
  /// skipped puts the stock back.
  Future<void> record({
    required PlannedDose dose,
    required DoseStatus status,
    required DateTime now,
  }) async {
    final scheduled = isoDateTime(dose.at);
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'dose_logs',
        where: '(plan_id = ? AND dose_date = ? AND slot = ?) OR (plan_id = ? AND scheduled_at = ?)',
        whereArgs: [
          dose.planId,
          dose.doseDate,
          dose.slot.name,
          dose.planId,
          scheduled,
        ],
        limit: 1,
      );
      final wasTaken =
          existing.isNotEmpty &&
          existing.first['status'] == DoseStatus.taken.name;

      await txn.insert('dose_logs', {
        'plan_id': dose.planId,
        'dose_date': dose.doseDate,
        'slot': dose.slot.name,
        'scheduled_at': scheduled,
        'status': status.name,
        'acted_at': now.toIso8601String(),
        'amount': dose.amount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (status == DoseStatus.taken && !wasTaken) {
        await _adjustStock(txn, dose.planId, -dose.amount);
      } else if (status != DoseStatus.taken && wasTaken) {
        await _adjustStock(txn, dose.planId, dose.amount);
      }
    });
  }

  /// Removes the log for [dose] (undo), restoring stock if it had been taken.
  Future<void> clear(PlannedDose dose) async {
    final scheduled = isoDateTime(dose.at);
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'dose_logs',
        where: '(plan_id = ? AND dose_date = ? AND slot = ?) OR (plan_id = ? AND scheduled_at = ?)',
        whereArgs: [
          dose.planId,
          dose.doseDate,
          dose.slot.name,
          dose.planId,
          scheduled,
        ],
        limit: 1,
      );
      if (existing.isEmpty) return;
      final wasTaken = existing.first['status'] == DoseStatus.taken.name;
      await txn.delete(
        'dose_logs',
        where: '(plan_id = ? AND dose_date = ? AND slot = ?) OR (plan_id = ? AND scheduled_at = ?)',
        whereArgs: [
          dose.planId,
          dose.doseDate,
          dose.slot.name,
          dose.planId,
          scheduled,
        ],
      );
      if (wasTaken) await _adjustStock(txn, dose.planId, dose.amount);
    });
  }

  Future<void> _adjustStock(Transaction txn, int planId, double delta) async {
    await txn.rawUpdate(
      'UPDATE plans SET stock = MAX(0, stock + ?) WHERE id = ? AND stock IS NOT NULL',
      [delta, planId],
    );
  }
}

final doseLogRepositoryProvider = Provider<DoseLogRepository>(
  (ref) => DoseLogRepository(ref.watch(appDatabaseProvider)),
);
