import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/safety/domain/missed_dose.dart';

void main() {
  final due = DateTime(2026, 10, 7, 8);
  final now = DateTime(2026, 10, 7, 11);

  test('ordinary medicine: take now, never double', () {
    final g = missedDoseGuidance(text: 'Pantoprazole 40', dueAt: due, now: now);
    expect(g.points.first, contains('as soon as you remember'));
    expect(g.points.any((p) => p.contains('two doses')), isTrue);
    expect(g.needsExtraCare, isFalse);
    expect(g.isAntibiotic, isFalse);
  });

  test('next dose close: skip the missed one', () {
    final g = missedDoseGuidance(
      text: 'Dolo 650 paracetamol',
      dueAt: due,
      now: now,
      nextDoseAt: DateTime(2026, 10, 7, 12),
    );
    expect(g.points.first, contains('Skip'));
  });

  test('antibiotic adds the course note', () {
    final g = missedDoseGuidance(
      text: 'Azithral 500 azithromycin',
      dueAt: due,
      now: now,
    );
    expect(g.isAntibiotic, isTrue);
    expect(g.points.any((p) => p.contains('whole course')), isTrue);
  });

  test('extra care medicines defer to a professional', () {
    final g = missedDoseGuidance(
      text: 'Thyronorm levothyroxine',
      dueAt: due,
      now: now,
    );
    expect(g.needsExtraCare, isTrue);
    expect(g.points.first, contains('call your doctor'));
  });
}
