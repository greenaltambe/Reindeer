import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// Remembers which medicine a scanned barcode belongs to.
///
/// The bundled medicine lists contain no barcodes, so Reindeer learns them: the
/// first time a pack is scanned the person picks the medicine, and every later
/// scan of that pack finds it straight away. Links stay on this phone.
class BarcodeLinkRepository {
  BarcodeLinkRepository(this._db);

  final Database _db;

  /// Medicine id linked to [key], or null.
  Future<int?> find(String key) async {
    final rows = await _db.query(
      'barcode_links',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['medicine_id'] as int?;
  }

  Future<void> link(String key, int medicineId) async {
    await _db.insert('barcode_links', {
      'key': key,
      'medicine_id': medicineId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final barcodeLinkRepositoryProvider = Provider<BarcodeLinkRepository>(
  (ref) => BarcodeLinkRepository(ref.watch(appDatabaseProvider)),
);
