import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';
import 'package:reindeer/features/refills/data/refill_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

void main() {
  group('Day Activity & Calendar Tracking', () {
    test('symptoms map correctly to calendar days', () {
      final oct10 = DateTime(2026, 10, 10, 14, 30);
      final oct11 = DateTime(2026, 10, 11, 9, 0);

      final symptoms = [
        SymptomEntry(
          id: 1,
          symptom: 'Headache',
          severity: Severity.moderate,
          note: 'Felt dizzy',
          at: oct10,
        ),
        SymptomEntry(
          id: 2,
          symptom: 'Nausea',
          severity: Severity.mild,
          at: oct11,
        ),
      ];

      final oct10Symptoms = [
        for (final s in symptoms)
          if (isSameDay(s.at, DateTime(2026, 10, 10))) s,
      ];
      final oct12Symptoms = [
        for (final s in symptoms)
          if (isSameDay(s.at, DateTime(2026, 10, 12))) s,
      ];

      expect(oct10Symptoms.length, 1);
      expect(oct10Symptoms.first.symptom, 'Headache');
      expect(oct12Symptoms, isEmpty);
    });

    test('refill events map correctly to calendar days', () {
      final oct10 = DateTime(2026, 10, 10, 16, 0);
      final refill = RefillRecord(
        id: 1,
        planId: 10,
        planName: 'Metformin 500mg',
        doseUnit: DoseUnit.tablet,
        quantity: 30,
        at: oct10,
      );

      expect(isSameDay(refill.at, DateTime(2026, 10, 10)), isTrue);
      expect(isSameDay(refill.at, DateTime(2026, 10, 11)), isFalse);
    });
  });
}
