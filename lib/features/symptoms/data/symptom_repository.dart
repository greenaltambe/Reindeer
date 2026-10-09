import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the symptom diary.
class SymptomRepository {
  SymptomRepository(this._db);

  final Database _db;

  Future<int> add(SymptomEntry e) => _db.insert('symptoms', {
    'profile_id': AppDatabase.defaultProfileId,
    'symptom': e.symptom,
    'severity': e.severity.level,
    'note': (e.note ?? '').trim().isEmpty ? null : e.note!.trim(),
    'logged_at': isoDateTime(e.at),
  });

  Future<void> delete(int id) =>
      _db.delete('symptoms', where: 'id = ?', whereArgs: [id]);

  /// Entries from the last [days] days, newest first.
  Future<List<SymptomEntry>> recent({int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _db.query(
      'symptoms',
      where: 'logged_at >= ?',
      whereArgs: [isoDateTime(since)],
      orderBy: 'logged_at DESC',
    );
    return [
      for (final r in rows)
        SymptomEntry(
          id: r['id'] as int,
          symptom: r['symptom'] as String,
          severity: Severity.fromLevel((r['severity'] as int?) ?? 1),
          note: r['note'] as String?,
          at: DateTime.parse(r['logged_at'] as String),
        ),
    ];
  }
}

final symptomRepositoryProvider = Provider<SymptomRepository>(
  (ref) => SymptomRepository(ref.watch(appDatabaseProvider)),
);

final symptomsProvider = FutureProvider<List<SymptomEntry>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(symptomRepositoryProvider).recent();
});
