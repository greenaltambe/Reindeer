import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

MedicationPlan plan({
  int id = 1,
  Map<DaySlot, double>? amounts,
  MealTiming timing = MealTiming.afterFood,
  PlanStatus status = PlanStatus.active,
  DateTime? stoppedAt,
  DateTime? resumedAt,
  DateTime? created,
  DateTime? end,
  double? stock,
}) {
  return MedicationPlan(
    id: id,
    profileId: 'me',
    name: 'Dolo 650',
    kind: MedicineKind.brand,
    doseUnit: DoseUnit.tablet,
    slotAmounts:
        amounts ??
        const {DaySlot.morning: 1, DaySlot.afternoon: 0, DaySlot.night: 1},
    mealTiming: timing,
    startDate: DateTime(2026, 10, 1),
    endDate: end,
    status: status,
    stoppedAt: stoppedAt,
    resumedAt: resumedAt,
    stock: stock,
    createdAt: created ?? DateTime(2026, 10, 1),
  );
}

void main() {
  const anchors = MealAnchors(breakfast: 480, lunch: 810, dinner: 1230);
  final day = DateTime(2026, 10, 3);

  group('MedicationPlan', () {
    test('pattern and summary', () {
      final p = plan();
      expect(p.patternLabel, '1-0-1');
      expect(p.doseSummary, 'Morning 1 tablet, Night 1 tablet');
      expect(p.dailyAmount, 2);
    });

    test('doses follow meal anchors and food timing', () {
      final doses = plan().dosesOn(day, anchors);
      expect(doses.map((d) => d.at), [
        DateTime(2026, 10, 3, 8, 30),
        DateTime(2026, 10, 3, 21, 0),
      ]);
      final before = plan(timing: MealTiming.beforeFood).dosesOn(day, anchors);
      expect(before.first.at, DateTime(2026, 10, 3, 7, 30));
    });

    test('no doses outside the course', () {
      final p = plan(end: DateTime(2026, 10, 2));
      expect(p.dosesOn(day, anchors), isEmpty);
      expect(p.dosesOn(DateTime(2026, 9, 30), anchors), isEmpty);
    });

    test('stopped plan keeps only doses before it was stopped', () {
      final p = plan(
        status: PlanStatus.discontinued,
        stoppedAt: DateTime(2026, 10, 3, 12, 0),
      );
      expect(p.dosesOn(day, anchors).length, 1);
    });

    test('doses during a pause never come back after resume', () {
      final p = plan(
        stoppedAt: DateTime(2026, 10, 3, 6, 0),
        resumedAt: DateTime(2026, 10, 3, 15, 0),
      );
      final doses = p.dosesOn(day, anchors);
      expect(doses.length, 1);
      expect(doses.single.slot, DaySlot.night);
    });

    test('low stock when under three days', () {
      expect(plan(stock: 5).isLowStock, isTrue); // 2.5 days at 2 a day
      expect(plan(stock: 30).isLowStock, isFalse);
      expect(plan().isLowStock, isFalse); // untracked
    });
  });

  group('DoseTimeline', () {
    test('pending, then missed after the grace window', () {
      final p = plan(created: DateTime(2026, 10, 1));
      final early = DoseTimeline.build(
        plans: [p],
        logs: const {},
        anchors: anchors,
        fromDay: day,
        toDay: day,
        now: DateTime(2026, 10, 3, 8, 45),
      );
      expect(early.first.status, DoseStatus.scheduled);

      final late = DoseTimeline.build(
        plans: [p],
        logs: const {},
        anchors: anchors,
        fromDay: day,
        toDay: day,
        now: DateTime(2026, 10, 3, 10, 31),
      );
      expect(late.first.status, DoseStatus.missed);
      expect(late.last.status, DoseStatus.scheduled);
    });

    test('doses before the plan was created are not counted', () {
      final p = plan(created: DateTime(2026, 10, 3, 15, 0));
      final entries = DoseTimeline.build(
        plans: [p],
        logs: const {},
        anchors: anchors,
        fromDay: day,
        toDay: day,
        now: DateTime(2026, 10, 3, 16, 0),
      );
      expect(entries.length, 1);
      expect(entries.single.dose.slot, DaySlot.night);
    });

    test('logged doses use the log and adherence is computed', () {
      final p = plan(created: DateTime(2026, 10, 1));
      final doses = p.dosesOn(day, anchors);
      final logs = {
        doses.first.key: DoseLog(
          planId: 1,
          scheduledAt: doses.first.at,
          status: DoseStatus.taken,
          actedAt: doses.first.at,
          amount: 1,
        ),
      };
      final now = DateTime(2026, 10, 3, 23, 30);
      final entries = DoseTimeline.build(
        plans: [p],
        logs: logs,
        anchors: anchors,
        fromDay: day,
        toDay: day,
        now: now,
      );
      expect(entries.first.status, DoseStatus.taken);
      expect(entries.last.status, DoseStatus.missed);
      final summary = AdherenceSummary.from(entries, now);
      expect(summary.taken, 1);
      expect(summary.missed, 1);
      expect(summary.overall, 0.5);
    });
  });
}
