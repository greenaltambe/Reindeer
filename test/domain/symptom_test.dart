import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';

MedicationPlan plan(String name, DateTime start) => MedicationPlan(
  id: 1,
  profileId: 'me',
  name: name,
  doseUnit: DoseUnit.tablet,
  slotAmounts: const {
    DaySlot.morning: 1,
    DaySlot.afternoon: 0,
    DaySlot.night: 0,
  },
  mealTiming: MealTiming.anytime,
  startDate: start,
  createdAt: start,
);

void main() {
  test('severity levels round trip', () {
    for (final s in Severity.values) {
      expect(Severity.fromLevel(s.level), s);
    }
    expect(Severity.fromLevel(99), Severity.severe);
    expect(Severity.fromLevel(0), Severity.mild);
  });

  test('recently started medicines', () {
    final at = DateTime(2026, 10, 10, 9);
    final plans = [
      plan('New', DateTime(2026, 10, 8)),
      plan('Old', DateTime(2026, 6, 1)),
      plan('Future', DateTime(2026, 10, 20)),
    ];
    expect(recentlyStarted(plans, at).map((p) => p.name), ['New']);
  });

  test('summary lines are newest first and limited', () {
    final entries = [
      SymptomEntry(
        symptom: 'Headache',
        severity: Severity.mild,
        at: DateTime(2026, 10, 1, 9),
      ),
      SymptomEntry(
        symptom: 'Rash or itching',
        severity: Severity.severe,
        note: 'on arms',
        at: DateTime(2026, 10, 5, 9),
      ),
    ];
    final lines = symptomSummaryLines(entries);
    expect(lines.first, contains('Rash or itching (severe) - on arms'));
    expect(lines.last, contains('Headache (mild)'));
    expect(symptomSummaryLines(entries, max: 1), hasLength(1));
  });
}
