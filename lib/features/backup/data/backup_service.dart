import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/backup/domain/backup_codec.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:sqflite/sqflite.dart';

/// Reads everything the person entered into a backup, and puts it back.
class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  Database get _db => _ref.read(appDatabaseProvider);

  Future<String> export() async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final t in backupTables) {
      data[t] = await _db.query(t);
    }
    return encodeBackup(data, DateTime.now());
  }

  /// Replaces all current data with [data] in one transaction: if anything
  /// fails, nothing changes.
  Future<void> restore(BackupData data) async {
    await _db.transaction((txn) async {
      for (final t in backupTables.reversed) {
        await txn.delete(t);
      }
      for (final t in backupTables) {
        for (final row in data[t] ?? const []) {
          await txn.insert(
            t,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      // A backup without a profile row would leave the app without one.
      final p = await txn.query('profiles', limit: 1);
      if (p.isEmpty) {
        await txn.insert('profiles', {
          'id': AppDatabase.defaultProfileId,
          'name': 'Me',
        });
      }
    });
    _ref.read(dataVersionProvider.notifier).bump();
    await _ref.read(reminderServiceProvider).rescheduleAll();
  }
}

final backupServiceProvider = Provider<BackupService>(BackupService.new);
