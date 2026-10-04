import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/progress/domain/doctor_summary.dart';

void main() {
  test('summary lists medicines and handles no data', () {
    final plan = MedicationPlan(
      id: 1,
      profileId: 'me',
      name: 'Dolo 650',
      doseUnit: DoseUnit.tablet,
      slotAmounts: const {
        DaySlot.morning: 1,
        DaySlot.afternoon: 0,
        DaySlot.night: 1,
      },
      mealTiming: MealTiming.afterFood,
      condition: 'fever',
      startDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
    );
    final text = buildDoctorSummary(
      plans: [plan],
      summary: AdherenceSummary.from(const [], DateTime(2026, 10, 3)),
      days: 30,
      now: DateTime(2026, 10, 3),
    );
    expect(text, contains('Dolo 650: 1-0-1'));
    expect(text, contains('after food'));
    expect(text, contains('for fever'));
    expect(text, contains('not enough data'));
  });

  test('summary includes conditions and latest readings when given', () {
    final text = buildDoctorSummary(
      plans: const [],
      summary: AdherenceSummary.from(const [], DateTime(2026, 10, 3)),
      days: 7,
      now: DateTime(2026, 10, 3),
      readings: const ['Weight: 72 kg (3 Oct 2026)'],
      conditions: const ['Asthma'],
    );
    expect(text, contains('Conditions: Asthma'));
    expect(text, contains('Latest readings'));
    expect(text, contains('Weight: 72 kg'));
  });
}
