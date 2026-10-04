// Checks the condition search against the built medicine database.
// Skips itself when assets/db/medicines.db is missing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/conditions/data/condition_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final dbFile = File('assets/db/medicines.db');
  final ready = dbFile.existsSync() && dbFile.lengthSync() > 0;

  test('condition search understands everyday words', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      dbFile.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final service = await ConditionSearchService.load(db);

    expect(service.search('bp').first, contains('Hypertension'));
    expect(service.search('sugar'), contains('Type 2 diabetes mellitus'));
    expect(service.search('asthma').first, 'Asthma');
    expect(service.search('fev'), contains('Fever'));
    expect(service.search(''), isEmpty);
    expect(service.search('zzzzqq'), isEmpty);
    expect(service.popular(limit: 5), hasLength(5));
    await db.close();
  }, skip: ready ? false : 'medicines.db not built');
}
