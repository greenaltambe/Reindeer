import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

void main() {
  const anchors = MealAnchors();
  final start = DateTime(2026, 10, 5); // a Monday

  MedicationPlan plan({
    int interval = 1,
    int weekdays = 0,
    Map<DaySlot, double>? alt,
    double? stock,
  }) => MedicationPlan(
    id: 1,
    profileId: 'p',
    name: 'Test',
    doseUnit: DoseUnit.tablet,
    slotAmounts: const {DaySlot.morning: 1, DaySlot.night: 1},
    startDate: start,
    createdAt: start,
    intervalDays: interval,
    weekdays: weekdays,
    altAmounts: alt,
    stock: stock,
  );

  DateTime day(int n) => DateTime(2026, 10, 5 + n);

  test('every day by default', () {
    final p = plan();
    expect(p.hasCustomDays, isFalse);
    for (var i = 0; i < 4; i++) {
      expect(p.dosesOn(day(i), anchors).length, 2);
    }
    expect(p.frequencyLabel, '');
  });

  test('every other day starts on the first day', () {
    final p = plan(interval: 2);
    expect(p.dosesOn(day(0), anchors).length, 2);
    expect(p.dosesOn(day(1), anchors), isEmpty);
    expect(p.dosesOn(day(2), anchors).length, 2);
    expect(p.frequencyLabel, 'Every other day');
    expect(p.averageDailyAmount, 1);
  });

  test('every 3 days', () {
    final p = plan(interval: 3);
    expect(
      [for (var i = 0; i < 7; i++) p.dosesOn(day(i), anchors).isNotEmpty],
      [true, false, false, true, false, false, true],
    );
  });

  test('chosen weekdays (Mon, Wed, Fri)', () {
    final p = plan(weekdays: 1 | 4 | 16);
    // start is Monday
    expect(
      [for (var i = 0; i < 7; i++) p.dosesOn(day(i), anchors).isNotEmpty],
      [true, false, true, false, true, false, false],
    );
    expect(p.frequencyLabel, 'Mon, Wed, Fri');
    expect(p.averageDailyAmount, closeTo(2 * 3 / 7, 1e-9));
  });

  test('alternate amounts every other due day', () {
    final p = plan(
      alt: const {DaySlot.morning: 2, DaySlot.afternoon: 0, DaySlot.night: 2},
    );
    expect(p.dosesOn(day(0), anchors).map((d) => d.amount), [1, 1]);
    expect(p.dosesOn(day(1), anchors).map((d) => d.amount), [2, 2]);
    expect(p.dosesOn(day(2), anchors).map((d) => d.amount), [1, 1]);
    expect(p.altPatternLabel, '2-0-2');
    expect(p.averageDailyAmount, 3);
  });

  test('alternate amounts of zero skip those days', () {
    final p = plan(
      alt: const {DaySlot.morning: 0, DaySlot.afternoon: 0, DaySlot.night: 0},
    );
    expect(p.dosesOn(day(1), anchors), isEmpty);
    expect(p.dosesOn(day(2), anchors).length, 2);
  });

  test('stock lasts longer on an every-other-day plan', () {
    expect(plan(stock: 10).daysOfStockLeft, 5);
    expect(plan(interval: 2, stock: 10).daysOfStockLeft, 10);
  });

  test('doses before the start are not due', () {
    expect(plan(interval: 2).dosesOn(day(-2), anchors), isEmpty);
  });
}
