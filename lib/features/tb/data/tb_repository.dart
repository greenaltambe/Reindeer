import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';
import 'package:sqflite/sqflite.dart';

/// Saves the TB programme (in settings) and supporter confirmations.
class TbRepository {
  TbRepository(this._db, this._settings);

  final Database _db;
  final SettingsRepository _settings;

  static const _kStart = 'tb_start';
  static const _kSupporter = 'tb_supporter';
  static const _kPhone = 'tb_phone';
  static const _kNikshay = 'tb_nikshay';
  static const _kPin = 'tb_pin';

  Future<TbProgramme?> load() async {
    final start = await _settings.get(_kStart);
    if (start == null || start.isEmpty) return null;
    return TbProgramme(
      start: dateOnly(DateTime.parse(start)),
      supporterName: await _settings.get(_kSupporter) ?? '',
      supporterPhone: await _settings.get(_kPhone) ?? '',
      nikshayId: await _settings.get(_kNikshay) ?? '',
      pinHash: await _settings.get(_kPin) ?? '',
    );
  }

  Future<void> save(TbProgramme p) async {
    await _settings.set(_kStart, isoDate(p.start));
    await _settings.set(_kSupporter, p.supporterName);
    await _settings.set(_kPhone, p.supporterPhone);
    await _settings.set(_kNikshay, p.nikshayId);
    await _settings.set(_kPin, p.pinHash);
  }

  Future<void> clear() async {
    for (final k in [_kStart, _kSupporter, _kPhone, _kNikshay, _kPin]) {
      await _settings.remove(k);
    }
  }

  /// Keys ([PlannedDose.key]) of doses a supporter confirmed.
  Future<Map<String, String>> observations() async {
    final rows = await _db.query('dots_observations');
    return {
      for (final r in rows)
        '${r['plan_id']}|${r['scheduled_at']}': r['observer'] as String,
    };
  }

  Future<void> observe(PlannedDose dose, String observer, DateTime now) =>
      _db.insert('dots_observations', {
        'plan_id': dose.planId,
        'scheduled_at': isoDateTime(dose.at),
        'observer': observer,
        'at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> unobserve(PlannedDose dose) => _db.delete(
    'dots_observations',
    where: 'plan_id = ? AND scheduled_at = ?',
    whereArgs: [dose.planId, isoDateTime(dose.at)],
  );
}

final tbRepositoryProvider = Provider<TbRepository>(
  (ref) => TbRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final tbProgrammeProvider = FutureProvider<TbProgramme?>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(tbRepositoryProvider).load();
});

/// Dose key -> name of the supporter who watched it.
final tbObservationsProvider = FutureProvider<Map<String, String>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(tbRepositoryProvider).observations();
});
