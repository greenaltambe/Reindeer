import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Saved health readings.
class MeasurementRepository {
  MeasurementRepository(this._db);

  final Database _db;

  static const _profile = AppDatabase.defaultProfileId;

  Future<int> add(Measurement m) => _db.insert('measurements', {
    'profile_id': _profile,
    'type': m.type.name,
    'value': m.value,
    'value2': m.value2,
    'context': m.context,
    'measured_at': m.at.toIso8601String(),
    'note': m.note,
  });

  Future<void> delete(int id) =>
      _db.delete('measurements', where: 'id = ?', whereArgs: [id]);

  /// Readings of [type], newest first, optionally only since [since].
  Future<List<Measurement>> forType(
    MeasureType type, {
    DateTime? since,
    int? limit,
  }) async {
    final rows = await _db.query(
      'measurements',
      where: since == null
          ? 'profile_id = ? AND type = ?'
          : 'profile_id = ? AND type = ? AND measured_at >= ?',
      whereArgs: [
        _profile,
        type.name,
        if (since != null) since.toIso8601String(),
      ],
      orderBy: 'measured_at DESC, id DESC',
      limit: limit,
    );
    return [for (final r in rows) _fromRow(r, type)];
  }

  Measurement _fromRow(Map<String, Object?> r, MeasureType type) => Measurement(
    id: r['id'] as int,
    type: type,
    value: (r['value'] as num).toDouble(),
    value2: (r['value2'] as num?)?.toDouble(),
    context: r['context'] as String?,
    at: DateTime.parse(r['measured_at'] as String),
    note: r['note'] as String?,
  );
}

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => MeasurementRepository(ref.watch(appDatabaseProvider)),
);

/// Readings of one type, newest first.
final measurementsProvider =
    FutureProvider.family<List<Measurement>, MeasureType>((ref, type) {
      ref.watch(dataVersionProvider);
      return ref.watch(measurementRepositoryProvider).forType(type);
    });

/// The reminder set for a type, or null.
final measureReminderProvider =
    FutureProvider.family<MeasureReminder?, MeasureType>((ref, type) async {
      ref.watch(dataVersionProvider);
      final v = await ref
          .watch(settingsRepositoryProvider)
          .get(MeasureReminder.settingsKey(type));
      return MeasureReminder.decode(v);
    });
