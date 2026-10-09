import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:sqflite/sqflite.dart';

/// The bundled, read-only medicine database (built by
/// `tools/build_medicine_db.py`).
///
/// It ships gzip-compressed as an asset and is unpacked once into the app's
/// databases folder. If unpacking fails (e.g. low storage), it falls back
/// gracefully to an empty database so the app still functions with custom medicines.
abstract final class MedicineDatabase {
  static const String assetPath = 'assets/db/medicines.db.gz';
  static const String fileName = 'medicines.db';
  static const int bundledVersion = 4;

  /// Opens the database, unpacking it first if needed.
  ///
  /// [onInstalling] is called before a (slow) first-time unpack.
  static Future<Database> open({void Function()? onInstalling}) async {
    final dir = await getDatabasesPath();
    final dbPath = p.join(dir, fileName);
    final marker = File('$dbPath.version');

    try {
      final installed =
          await File(dbPath).exists() &&
          await marker.exists() &&
          (await marker.readAsString()).trim() == '$bundledVersion';
      if (!installed) {
        onInstalling?.call();
        await _install(dbPath, marker);
      }
      return await openDatabase(dbPath, readOnly: true);
    } catch (e, st) {
      AppLogger.error(
        'Failed to unpack or open bundled medicine database, falling back',
        error: e,
        stackTrace: st,
      );
      return _openFallback(dbPath);
    }
  }

  static Future<void> _install(String dbPath, File marker) async {
    await Directory(p.dirname(dbPath)).create(recursive: true);
    final tmpPath = '$dbPath.tmp';
    final tmp = File(tmpPath);
    if (await tmp.exists()) await tmp.delete();

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final out = tmp.openWrite();
    final decoder = gzip.decoder.startChunkedConversion(out);
    const chunk = 256 * 1024;
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = i + chunk < bytes.length ? i + chunk : bytes.length;
      decoder.add(bytes.sublist(i, end));
      // Let the UI breathe between chunks.
      await Future<void>.delayed(Duration.zero);
    }
    decoder.close();
    await out.done;

    final target = File(dbPath);
    if (await target.exists()) await target.delete();
    await tmp.rename(dbPath);
    await marker.writeAsString('$bundledVersion');
  }

  static Future<Database> _openFallback(String dbPath) async {
    final fallbackPath = '$dbPath.fallback';
    return openDatabase(
      fallbackPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS medicines(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            composition TEXT NOT NULL,
            form TEXT,
            pack_qty REAL,
            is_generic INTEGER,
            price_inr REAL,
            discontinued INTEGER DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salts(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            is_high_risk INTEGER DEFAULT 0,
            class_name TEXT
          )''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS medicine_salts(
            medicine_id INTEGER NOT NULL,
            salt_id INTEGER NOT NULL,
            strength TEXT
          )''');
      },
    );
  }
}

/// The medicine database. Overridden in `main` once it is open.
final medicineDatabaseProvider = Provider<Database>(
  (ref) =>
      throw UnimplementedError('medicineDatabaseProvider must be overridden'),
);
