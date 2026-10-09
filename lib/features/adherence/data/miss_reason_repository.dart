import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes [MissReason] records in SQLite.
class MissReasonRepository {
  MissReasonRepository(this._db);

  final Database _db;

  /// Records or replaces a reason for a missed or skipped dose.
  Future<void> record({
    required int planId,
    required String doseDate,
    required DaySlot slot,
    required MissReasonType reason,
    String? note,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await _db.insert('miss_reasons', {
      'plan_id': planId,
      'dose_date': doseDate,
      'slot': slot.name,
      'reason': reason.name,
      'note': note,
      'at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Convenience method to record for a [PlannedDose].
  Future<void> recordForDose({
    required PlannedDose dose,
    required MissReasonType reason,
    String? note,
    DateTime? at,
  }) => record(
    planId: dose.planId,
    doseDate: dose.doseDate,
    slot: dose.slot,
    reason: reason,
    note: note,
    at: at,
  );

  /// Gets the reason recorded for a specific dose, if any.
  Future<MissReason?> get(int planId, String doseDate, DaySlot slot) async {
    final rows = await _db.query(
      'miss_reasons',
      where: 'plan_id = ? AND dose_date = ? AND slot = ?',
      whereArgs: [planId, doseDate, slot.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Convenience lookup by [PlannedDose].
  Future<MissReason?> forDose(PlannedDose dose) =>
      get(dose.planId, dose.doseDate, dose.slot);

  /// All miss reasons between [fromDay] and [toDay] inclusive, keyed by dose key `planId|doseDate|slot`.
  Future<Map<String, MissReason>> between(
    DateTime fromDay,
    DateTime toDay,
  ) async {
    final from = isoDate(fromDay);
    final to = isoDate(toDay);
    final rows = await _db.query(
      'miss_reasons',
      where: 'dose_date >= ? AND dose_date <= ?',
      whereArgs: [from, to],
      orderBy: 'at DESC',
    );
    final out = <String, MissReason>{};
    for (final r in rows) {
      final mr = _fromRow(r);
      out[mr.doseKey] = mr;
    }
    return out;
  }

  /// Aggregated counts by reason type over the period.
  Future<Map<MissReasonType, int>> summaryBetween(
    DateTime fromDay,
    DateTime toDay,
  ) async {
    final from = isoDate(fromDay);
    final to = isoDate(toDay);
    final rows = await _db.rawQuery(
      '''
      SELECT reason, COUNT(*) as cnt
      FROM miss_reasons
      WHERE dose_date >= ? AND dose_date <= ?
      GROUP BY reason
    ''',
      [from, to],
    );
    final out = <MissReasonType, int>{};
    for (final r in rows) {
      final reason = MissReasonType.fromName(r['reason'] as String?);
      out[reason] = (r['cnt'] as num).toInt();
    }
    return out;
  }

  /// Patient notes recorded with reasons (e.g. side effect notes) over the period.
  Future<List<MissReason>> notesBetween(
    DateTime fromDay,
    DateTime toDay,
  ) async {
    final from = isoDate(fromDay);
    final to = isoDate(toDay);
    final rows = await _db.query(
      'miss_reasons',
      where: "dose_date >= ? AND dose_date <= ? AND note IS NOT NULL AND TRIM(note) != ''",
      whereArgs: [from, to],
      orderBy: 'at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  MissReason _fromRow(Map<String, Object?> r) => MissReason(
    id: r['id'] as int?,
    planId: r['plan_id'] as int,
    doseDate: r['dose_date'] as String,
    slot: DaySlot.fromName(r['slot'] as String),
    reason: MissReasonType.fromName(r['reason'] as String?),
    note: r['note'] as String?,
    at: parseIso(r['at'] as String),
  );
}

final missReasonRepositoryProvider = Provider<MissReasonRepository>(
  (ref) => MissReasonRepository(ref.watch(appDatabaseProvider)),
);

/// Provider of all recorded miss reasons between dates.
final missReasonsBetweenProvider =
    FutureProvider.family<
      Map<String, MissReason>,
      ({DateTime from, DateTime to})
    >((ref, arg) async {
      ref.watch(dataVersionProvider);
      return ref.watch(missReasonRepositoryProvider).between(arg.from, arg.to);
    });

/// Breakdown summary of miss reasons between dates.
final missReasonsSummaryProvider =
    FutureProvider.family<
      Map<MissReasonType, int>,
      ({DateTime from, DateTime to})
    >((ref, arg) async {
      ref.watch(dataVersionProvider);
      return ref
          .watch(missReasonRepositoryProvider)
          .summaryBetween(arg.from, arg.to);
    });

/// Patient notes recorded with miss reasons between dates.
final missNotesBetweenProvider =
    FutureProvider.family<List<MissReason>, ({DateTime from, DateTime to})>((
      ref,
      arg,
    ) async {
      ref.watch(dataVersionProvider);
      return ref
          .watch(missReasonRepositoryProvider)
          .notesBetween(arg.from, arg.to);
    });
