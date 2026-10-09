import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

void main() {
  group('Stable Dose Identity & Meal-Time Shifts', () {
    final day = DateTime(2026, 10, 9);
    final initialAnchors = const MealAnchors(
      breakfast: 8 * 60, // 08:00
      lunch: 13 * 60 + 30, // 13:30
      dinner: 20 * 60 + 30, // 20:30
    );

    MedicationPlan createPlan() => MedicationPlan(
      id: 1,
      profileId: 'me',
      name: 'Amlodipine 5mg',
      doseUnit: DoseUnit.tablet,
      slotAmounts: const {DaySlot.morning: 1.0, DaySlot.night: 1.0},
      mealTiming: MealTiming.afterFood, // +30 min
      startDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1, 8, 0),
    );

    test('dose key format is stable and based on planId|date|slot', () {
      final p = createPlan();
      final doses = p.dosesOn(day, initialAnchors);
      expect(doses.length, 2);

      final morningDose = doses.first;
      expect(morningDose.slot, DaySlot.morning);
      expect(morningDose.at, DateTime(2026, 10, 9, 8, 30));
      expect(morningDose.key, '1|2026-10-09|morning');

      final nightDose = doses.last;
      expect(nightDose.slot, DaySlot.night);
      expect(nightDose.key, '1|2026-10-09|night');
    });

    test(
      'shifting breakfast time in settings does NOT orphan a logged dose',
      () {
        final p = createPlan();

        // 1. Doses generated with breakfast at 8:00 (dose at 8:30)
        final dosesInitial = p.dosesOn(day, initialAnchors);
        final morningInitial = dosesInitial.first;
        expect(morningInitial.key, '1|2026-10-09|morning');
        expect(morningInitial.at, DateTime(2026, 10, 9, 8, 30));

        // 2. User logs dose as taken
        final log = DoseLog(
          planId: morningInitial.planId,
          doseDate: morningInitial.doseDate,
          slot: morningInitial.slot,
          scheduledAt: morningInitial.at,
          status: DoseStatus.taken,
          actedAt: DateTime(2026, 10, 9, 8, 35),
          amount: morningInitial.amount,
        );

        final logs = <String, DoseLog>{morningInitial.key: log};

        // 3. User later changes breakfast anchor to 9:15 (+75 min shift!)
        final shiftedAnchors = initialAnchors.copyWith(
          breakfast: 9 * 60 + 15, // 09:15 -> dose at 09:45
        );

        final dosesShifted = p.dosesOn(day, shiftedAnchors);
        final morningShifted = dosesShifted.first;
        expect(morningShifted.at, DateTime(2026, 10, 9, 9, 45));

        // The key MUST remain the same!
        expect(morningShifted.key, morningInitial.key);

        // 4. Build timeline with shifted anchors at 14:00
        final now = DateTime(2026, 10, 9, 14, 0);
        final entries = DoseTimeline.build(
          plans: [p],
          logs: logs,
          anchors: shiftedAnchors,
          fromDay: day,
          toDay: day,
          now: now,
        );

        final morningEntry = entries.firstWhere(
          (e) => e.dose.slot == DaySlot.morning,
        );
        // It MUST still be recognized as taken! NOT missed, NOT re-reminded!
        expect(morningEntry.status, DoseStatus.taken);
        expect(morningEntry.dose.at, DateTime(2026, 10, 9, 9, 45));
        expect(morningEntry.actedAt, DateTime(2026, 10, 9, 8, 35));
      },
    );

    test('parseKey parses both modern and legacy keys correctly', () {
      final parsedModern = PlannedDose.parseKey('42|2026-10-09|morning');
      expect(parsedModern, isNotNull);
      expect(parsedModern!.planId, 42);
      expect(parsedModern.date, '2026-10-09');
      expect(parsedModern.slot, 'morning');

      final parsedLegacy = PlannedDose.parseKey('42|2026-10-09T08:30:00.000');
      expect(parsedLegacy, isNotNull);
      expect(parsedLegacy!.planId, 42);
      expect(parsedLegacy.date, '2026-10-09');
      expect(parsedLegacy.slot, 'morning');

      final parsedLegacyNight = PlannedDose.parseKey(
        '42|2026-10-09T20:30:00.000',
      );
      expect(parsedLegacyNight, isNotNull);
      expect(parsedLegacyNight!.slot, 'night');
    });
  });
}
