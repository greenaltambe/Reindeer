import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/models/plan_version.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

void main() {
  group('Plan Versioning & History Preservation', () {
    const anchors = MealAnchors();

    test('past doses evaluate against previous prescription version', () {
      final v1 = PlanVersion(
        id: 1,
        planId: 10,
        effectiveFrom: DateTime(2026, 9, 1),
        slotAmounts: const {
          DaySlot.morning: 1.0, // 1 tablet in morning only
        },
        mealTiming: MealTiming.afterFood,
        changeReason: 'Initial prescription',
        createdAt: DateTime(2026, 9, 1),
      );

      final v2 = PlanVersion(
        id: 2,
        planId: 10,
        effectiveFrom: DateTime(2026, 10, 5), // Changed by doctor on Oct 5
        slotAmounts: const {
          DaySlot.morning: 1.0,
          DaySlot.night: 1.0, // Increased to morning + night!
        },
        mealTiming: MealTiming.afterFood,
        changeReason: 'Doctor increased dose to twice daily',
        createdAt: DateTime(2026, 10, 5),
      );

      final plan = MedicationPlan(
        id: 10,
        profileId: 'me',
        name: 'Metformin 500mg',
        doseUnit: DoseUnit.tablet,
        slotAmounts: const {DaySlot.morning: 1.0, DaySlot.night: 1.0},
        startDate: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 9, 1),
        versions: [v1, v2],
      );

      // On Oct 2 (before change): should have ONLY morning dose (1 tablet)
      final dosesOct2 = plan.dosesOn(DateTime(2026, 10, 2), anchors);
      expect(dosesOct2.length, 1);
      expect(dosesOct2.first.slot, DaySlot.morning);
      expect(dosesOct2.first.amount, 1.0);

      // On Oct 4 (day before change): still 1 dose
      final dosesOct4 = plan.dosesOn(DateTime(2026, 10, 4), anchors);
      expect(dosesOct4.length, 1);

      // On Oct 5 (effective date): has 2 doses (morning and night)
      final dosesOct5 = plan.dosesOn(DateTime(2026, 10, 5), anchors);
      expect(dosesOct5.length, 2);
      expect(dosesOct5[0].slot, DaySlot.morning);
      expect(dosesOct5[1].slot, DaySlot.night);

      // On Oct 9 (after change): 2 doses
      final dosesOct9 = plan.dosesOn(DateTime(2026, 10, 9), anchors);
      expect(dosesOct9.length, 2);
    });

    test(
      'multiple pause windows correctly suppress doses only during pauses',
      () {
        final pause1 = PlanPause(
          id: 1,
          planId: 5,
          pausedAt: DateTime(2026, 10, 2, 0, 0),
          resumedAt: DateTime(2026, 10, 4, 12, 0),
          reason: 'Temporary surgery pause',
        );

        final pause2 = PlanPause(
          id: 2,
          planId: 5,
          pausedAt: DateTime(2026, 10, 7, 0, 0),
          resumedAt: DateTime(2026, 10, 9, 0, 0),
          reason: 'Fasting pause',
        );

        final plan = MedicationPlan(
          id: 5,
          profileId: 'me',
          name: 'Thyroxine 50mcg',
          doseUnit: DoseUnit.tablet,
          slotAmounts: const {DaySlot.morning: 1.0},
          startDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
          pauses: [pause1, pause2],
        );

        // Oct 1: before pause 1 -> due
        expect(plan.dosesOn(DateTime(2026, 10, 1), anchors).length, 1);

        // Oct 3: inside pause 1 -> NOT due
        expect(plan.dosesOn(DateTime(2026, 10, 3), anchors), isEmpty);

        // Oct 5: between pause 1 and pause 2 -> due
        expect(plan.dosesOn(DateTime(2026, 10, 5), anchors).length, 1);

        // Oct 8: inside pause 2 -> NOT due
        expect(plan.dosesOn(DateTime(2026, 10, 8), anchors), isEmpty);

        // Oct 10: after pause 2 -> due
        expect(plan.dosesOn(DateTime(2026, 10, 10), anchors).length, 1);
      },
    );
  });
}
