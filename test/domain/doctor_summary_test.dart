import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
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

  test('summary includes allergies and symptoms', () {
    final text = buildDoctorSummary(
      plans: const [],
      summary: AdherenceSummary.from(const [], DateTime(2026, 10, 3)),
      days: 7,
      now: DateTime(2026, 10, 3),
      allergies: const ['Penicillins'],
      symptoms: const ['Saturday, 3 October: Nausea (mild)'],
    );
    expect(text, contains('Allergies: Penicillins'));
    expect(text, contains('Symptoms I noted'));
    expect(text, contains('Nausea (mild)'));
  });

  test(
    'summary includes miss reasons, patient notes, changes, and disclaimer',
    () {
      final text = buildDoctorSummary(
        plans: const [],
        summary: AdherenceSummary.from(const [], DateTime(2026, 10, 3)),
        days: 30,
        now: DateTime(2026, 10, 3),
        missReasons: const {
          MissReasonType.forgot: 2,
          MissReasonType.sideEffect: 1,
        },
        missNotes: const ['Dizziness after evening dose'],
        prescriptionChanges: const ['Metformin dose adjusted to 1000mg'],
      );
      expect(text, contains('Self-recorded, not verified intake'));
      expect(text, contains('Missed dose reasons breakdown'));
      expect(text, contains('Patient notes & side effects'));
      expect(text, contains('Dizziness after evening dose'));
      expect(text, contains('Prescription changes since last visit'));
      expect(text, contains('Metformin dose adjusted to 1000mg'));
    },
  );
}
