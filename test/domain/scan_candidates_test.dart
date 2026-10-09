import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/scan_candidates.dart';

void main() {
  test('brand name with strength comes first', () {
    final c = medicineNameCandidates(
      'Each uncoated tablet contains\nParacetamol IP 650 mg\nDOLO 650\nB.No. DL230912\nMRP Rs 30.91\nMfg Lic. No. 123',
    );
    expect(c.first, 'DOLO 650');
    expect(c, contains('Paracetamol IP 650 mg'));
    expect(c.any((l) => l.contains('MRP')), isFalse);
  });

  test('numbers-only and noise lines are dropped', () {
    final c = medicineNameCandidates('12345678\nBatch No\nExp 09/27\n');
    expect(c, isEmpty);
  });

  test('duplicates are removed and the limit applies', () {
    final text = List.generate(
      12,
      (i) =>
          'Pantocid${String.fromCharCode(97 + i)}\nPantocid${String.fromCharCode(97 + i)}',
    ).join('\n');
    final c = medicineNameCandidates(text, limit: 5);
    expect(c.length, 5);
    expect(c.toSet().length, 5);
  });
}
