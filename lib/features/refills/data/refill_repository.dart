import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:sqflite/sqflite.dart';

/// One historical refill event.
class RefillRecord {
  const RefillRecord({
    required this.id,
    required this.planId,
    required this.planName,
    required this.doseUnit,
    required this.quantity,
    required this.at,
  });

  final int id;
  final int planId;
  final String planName;
  final DoseUnit doseUnit;
  final double quantity;
  final DateTime at;
}

/// Repository for reading and recording refill logs.
class RefillRepository {
  RefillRepository(this._db);

  final Database _db;

  /// Loads the most recent refill history.
  Future<List<RefillRecord>> recent({int limit = 20}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT r.id, r.plan_id, r.quantity, r.at, p.name AS plan_name, p.dose_unit
      FROM refills r
      JOIN plans p ON r.plan_id = p.id
      ORDER BY r.at DESC
      LIMIT ?
    ''',
      [limit],
    );

    return rows.map((r) {
      return RefillRecord(
        id: r['id'] as int,
        planId: r['plan_id'] as int,
        planName: (r['plan_name'] as String?) ?? 'Medicine',
        doseUnit: DoseUnit.fromName(r['dose_unit'] as String?),
        quantity: (r['quantity'] as num).toDouble(),
        at: parseIso(r['at'] as String),
      );
    }).toList();
  }

  /// Total count of refills recorded.
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) as cnt FROM refills');
    return (rows.first['cnt'] as num).toInt();
  }
}

final refillRepositoryProvider = Provider<RefillRepository>(
  (ref) => RefillRepository(ref.watch(appDatabaseProvider)),
);

final recentRefillsProvider = FutureProvider<List<RefillRecord>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(refillRepositoryProvider).recent();
});
