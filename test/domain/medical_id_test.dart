import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/safety/domain/medical_id.dart';

void main() {
  test('medical id lists allergies, conditions and medicines', () {
    final plan = MedicationPlan(
      id: 1,
      profileId: 'me',
      name: 'Amlodipine 5',
      doseUnit: DoseUnit.tablet,
      slotAmounts: const {
        DaySlot.morning: 1,
        DaySlot.afternoon: 0,
        DaySlot.night: 0,
      },
      mealTiming: MealTiming.anytime,
      startDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
    );
    final text = buildMedicalIdText(
      name: 'Asha',
      age: 62,
      allergies: ['Penicillins'],
      conditions: ['High blood pressure'],
      plans: [plan],
    );
    expect(text, contains('Asha, age 62'));
    expect(text, contains('Allergies: Penicillins'));
    expect(text, contains('Conditions: High blood pressure'));
    expect(text, contains('- Amlodipine 5: 1-0-0'));
  });

  test('empty lists say none', () {
    final text = buildMedicalIdText(
      name: '',
      allergies: [],
      conditions: [],
      plans: [],
    );
    expect(text, contains('none noted'));
    expect(text, contains('- none'));
  });
}
