// Checks the Dart search against results produced by the Python reference
// (tools/search_reference.py vectors).
//
// Needs the built database and a desktop SQLite:
//   python3 tools/build_medicine_db.py
//   flutter pub add --dev sqflite_common_ffi
// The test skips itself when assets/db/medicines.db is missing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final dbFile = File('assets/db/medicines.db');
  final fixtureFile = File('test/fixtures/search_cases.json');
  final ready =
      dbFile.existsSync() &&
      dbFile.lengthSync() > 0 &&
      fixtureFile.existsSync();

  test('Dart search matches the Python reference', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      dbFile.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final service = await MedicineSearchService.load(db);
    final cases = jsonDecode(fixtureFile.readAsStringSync()) as List<dynamic>;
    expect(cases, isNotEmpty);

    for (final c in cases) {
      final query = c['query'] as String;
      final asYouType = c['asYouType'] as bool;
      final expected = [
        for (final t in c['top'] as List<dynamic>)
          (t as List<dynamic>)[0] as int,
      ];
      final rows = await service.searchRows(
        query,
        asYouType: asYouType,
        limit: 5,
      );
      final actual = [for (final r in rows) r['id'] as int];
      expect(actual, expected, reason: 'query: $query');
    }
    await db.close();
  }, skip: ready ? false : 'assets/db/medicines.db not built');
}
