import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';

MedicationPlan _plan({String? condition = tbCondition}) => MedicationPlan(
  id: 1,
  profileId: 'me',
  name: 'TB medicines',
  condition: condition,
  doseUnit: DoseUnit.tablet,
  slotAmounts: const {DaySlot.morning: 3},
  startDate: DateTime(2026, 10, 1),
  createdAt: DateTime(2026, 10, 1),
);

DoseEntry _entry(int day, DoseStatus s, {String? condition = tbCondition}) {
  final at = DateTime(2026, 10, day, 7);
  return DoseEntry(
    plan: _plan(condition: condition),
    dose: PlannedDose(planId: 1, at: at, slot: DaySlot.morning, amount: 3),
    status: s,
  );
}

void main() {
  final p = TbProgramme(start: DateTime(2026, 10, 1), supporterName: 'Asha');

  test('day numbers and phases', () {
    expect(p.dayNumber(DateTime(2026, 10, 1)), 1);
    expect(p.phaseOn(DateTime(2026, 10, 1)), TbPhase.intensive);
    expect(p.dayNumber(DateTime(2026, 11, 25)), 56);
    expect(p.phaseOn(DateTime(2026, 11, 25)), TbPhase.intensive);
    expect(p.phaseOn(DateTime(2026, 11, 26)), TbPhase.continuation);
    expect(p.phaseOn(p.lastDay), TbPhase.continuation);
    expect(
      p.phaseOn(p.lastDay.add(const Duration(days: 2))),
      TbPhase.completed,
    );
    expect(p.phaseOn(DateTime(2026, 9, 30)), TbPhase.notStarted);
  });

  test('last day is day 168 and days left count down', () {
    expect(p.lastDay, DateTime(2027, 3, 17));
    expect(p.daysLeft(DateTime(2026, 10, 1)), 167);
    expect(p.daysLeft(DateTime(2030, 1, 1)), 0);
  });

  test('follow-ups', () {
    final f = p.followUps();
    expect(f.length, 3);
    expect(f.first.date, DateTime(2026, 11, 25));
    expect(f.last.date, p.lastDay);
  });

  test('pin hash is stable and checks four digits', () {
    expect(hashPin('1234'), hashPin(' 1234 '));
    expect(hashPin('1234') == hashPin('1235'), isFalse);
    expect(isValidPin('1234'), isTrue);
    expect(isValidPin('123'), isFalse);
    expect(isValidPin('12a4'), isFalse);
  });

  test('adherence counts, observed doses and missed streak', () {
    final now = DateTime(2026, 10, 6, 12);
    final entries = [
      _entry(1, DoseStatus.taken),
      _entry(2, DoseStatus.taken),
      _entry(3, DoseStatus.skipped),
      _entry(4, DoseStatus.missed),
      _entry(5, DoseStatus.missed),
      _entry(6, DoseStatus.scheduled),
      _entry(2, DoseStatus.taken, condition: 'Fever'),
    ];
    final a = TbAdherence.from(entries, {entries[0].dose.key}, now);
    expect(a.taken, 2);
    expect(a.skipped, 1);
    expect(a.missed, 2);
    expect(a.observed, 1);
    expect(a.missedDaysInARow, 2);
    expect(a.takenFraction, closeTo(0.4, 1e-9));
    expect(a.observedFraction, 0.5);
  });

  test('no resolved doses gives no percentage', () {
    final a = TbAdherence.from(const [], {}, DateTime(2026, 10, 2));
    expect(a.takenFraction, isNull);
    expect(a.missedDaysInARow, 0);
  });

  test('report mentions the key facts', () {
    final a = TbAdherence.from(
      [_entry(1, DoseStatus.taken)],
      {},
      DateTime(2026, 10, 2),
    );
    final r = buildDotsReport(
      patient: 'Ravi',
      programme: p,
      adherence: a,
      today: DateTime(2026, 10, 2),
    );
    expect(r, contains('Patient: Ravi'));
    expect(r, contains('Day 2 of 168'));
    expect(r, contains('Doses taken: 1'));
    expect(r, contains('Asha'));
  });
}
