import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/models/prescription_diff.dart';

void main() {
  MedicationPlan makePlan({
    int id = 1,
    required String name,
    Map<DaySlot, double> slotAmounts = const {DaySlot.morning: 1},
    MealTiming mealTiming = MealTiming.afterFood,
    PlanStatus status = PlanStatus.active,
    int intervalDays = 1,
  }) {
    return MedicationPlan(
      id: id,
      profileId: 'me',
      name: name,
      doseUnit: DoseUnit.tablet,
      slotAmounts: slotAmounts,
      mealTiming: mealTiming,
      status: status,
      intervalDays: intervalDays,
      startDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
    );
  }

  group('Prescription Reconciliation Diff', () {
    test('detects newly started medicine', () {
      final oldPlans = [makePlan(name: 'Amlodipine 5mg')];
      final newPlans = [
        makePlan(name: 'Amlodipine 5mg'),
        makePlan(name: 'Metformin 500mg'),
      ];

      final diff = computePrescriptionDiff(
        previousPlans: oldPlans,
        currentPlans: newPlans,
      );

      final started = diff
          .where((d) => d.type == PlanDiffType.started)
          .toList();
      expect(started.length, 1);
      expect(started.first.name, 'Metformin 500mg');
    });

    test('detects stopped medicine', () {
      final oldPlans = [
        makePlan(name: 'Amlodipine 5mg'),
        makePlan(name: 'Aspirin 75mg'),
      ];
      final newPlans = [makePlan(name: 'Amlodipine 5mg')];

      final diff = computePrescriptionDiff(
        previousPlans: oldPlans,
        currentPlans: newPlans,
      );

      final stopped = diff
          .where((d) => d.type == PlanDiffType.stopped)
          .toList();
      expect(stopped.length, 1);
      expect(stopped.first.name, 'Aspirin 75mg');
    });

    test('detects dose and timing adjustments', () {
      final oldPlans = [
        makePlan(
          name: 'Metformin 500mg',
          slotAmounts: const {DaySlot.morning: 1, DaySlot.night: 0},
          mealTiming: MealTiming.afterFood,
        ),
      ];
      final newPlans = [
        makePlan(
          name: 'Metformin 500mg',
          slotAmounts: const {DaySlot.morning: 1, DaySlot.night: 1},
          mealTiming: MealTiming.withFood,
        ),
      ];

      final diff = computePrescriptionDiff(
        previousPlans: oldPlans,
        currentPlans: newPlans,
      );

      final adjusted = diff
          .where((d) => d.type == PlanDiffType.adjusted)
          .toList();
      expect(adjusted.length, 1);
      expect(adjusted.first.name, 'Metformin 500mg');
      expect(adjusted.first.oldSummary, contains('1-0-0'));
      expect(adjusted.first.newSummary, contains('1-0-1'));
    });

    test('detects unchanged medicine', () {
      final oldPlans = [
        makePlan(
          name: 'Telmisartan 40mg',
          slotAmounts: const {DaySlot.morning: 1},
        ),
      ];
      final newPlans = [
        makePlan(
          name: 'Telmisartan 40mg',
          slotAmounts: const {DaySlot.morning: 1},
        ),
      ];

      final diff = computePrescriptionDiff(
        previousPlans: oldPlans,
        currentPlans: newPlans,
      );

      final unchanged = diff
          .where((d) => d.type == PlanDiffType.unchanged)
          .toList();
      expect(unchanged.length, 1);
      expect(unchanged.first.name, 'Telmisartan 40mg');
    });
  });
}
