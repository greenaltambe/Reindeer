// Matches scanned prescription text against the real medicine database.
//
// Needs the built database and a desktop SQLite (see search_parity_test.dart).
// The test skips itself when assets/db/medicines.db is missing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/prescription_scan_parser.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final dbFile = File('assets/db/medicines.db');
  final ready = dbFile.existsSync() && dbFile.lengthSync() > 0;
  late MedicineSearchService search;

  setUpAll(() async {
    if (!ready) return;
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      dbFile.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    search = await MedicineSearchService.load(db);
  });

  Future<List<ScannedPrescriptionItem>> parse(String rx) =>
      PrescriptionScanParser.parse(rx, searchService: search);

  test('finds the medicines on a typical prescription', () async {
    final items = await parse('''
Dr. Mehta Clinic
Rx
T. Pan 40          1-0-0  before food
Tab Augmentin 625 Duo     1-0-1 x 5 days
Syp Ascoril LS 5ml TDS
Adv: plenty of fluids, rest
Tab Dolo 650 SOS for fever
Tab Rosuvas 10 0-0-1
''');
    expect(items.map((i) => i.name), [
      'PAN 40 Tablet',
      'Augmentin 625 Duo Tablet',
      'Ascoril LS Syrup',
      'Dolo 650 Tablet',
      'Rosuvas 10 Tablet',
    ]);
    expect(items.every((i) => i.isMatched && i.isSelected), isTrue);
  }, skip: ready ? false : 'assets/db/medicines.db not built');

  test('corrects common OCR misreads of the name', () async {
    final items = await parse('''
Tab Telrna 40 1-0-0
Tab Glyc0met 500 1-0-1
''');
    expect(items.map((i) => i.name), ['Telma 40 Tablet', 'Glycomet Tablet']);
  }, skip: ready ? false : 'assets/db/medicines.db not built');

  test('does not invent a medicine from an unknown name', () async {
    final items = await parse('Tab Zqxwvy 20 1-0-1');
    expect(items, hasLength(1));
    expect(items.single.isMatched, isFalse);
    expect(items.single.isSelected, isFalse);
    expect(items.single.name, 'Zqxwvy 20');
  }, skip: ready ? false : 'assets/db/medicines.db not built');
}
