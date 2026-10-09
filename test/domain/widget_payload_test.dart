import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/widget/domain/widget_payload.dart';

void main() {
  final plan = MedicationPlan(
    id: 1,
    profileId: 'p',
    name: 'Metformin',
    doseUnit: DoseUnit.tablet,
    slotAmounts: const {DaySlot.morning: 1, DaySlot.night: 1},
    startDate: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 10, 1),
  );

  DoseEntry entry(int hour, DoseStatus status, {int day = 7}) => DoseEntry(
    plan: plan,
    dose: PlannedDose(
      planId: 1,
      at: DateTime(2026, 10, day, hour),
      slot: hour < 12 ? DaySlot.morning : DaySlot.night,
      amount: 1,
    ),
    status: status,
  );

  final now = DateTime(2026, 10, 7, 12);

  test('empty list says no medicines', () {
    final p = buildWidgetPayload(const [], now);
    expect(p.header, 'No medicines yet');
    expect(p.rows, isEmpty);
  });

  test('counts taken doses and lists the waiting one', () {
    final p = buildWidgetPayload([
      entry(8, DoseStatus.taken),
      entry(20, DoseStatus.scheduled),
    ], now);
    expect(p.header, 'Today: 1 of 2 taken');
    expect(p.rows.length, 1);
    expect(p.rows.first.late, isFalse);
    expect(p.rows.first.text, contains('Metformin'));
  });

  test('a waiting dose in the past is late', () {
    final p = buildWidgetPayload([entry(8, DoseStatus.scheduled)], now);
    expect(p.rows.first.late, isTrue);
  });

  test('all done shows tomorrow first dose', () {
    final p = buildWidgetPayload([
      entry(8, DoseStatus.taken),
      entry(20, DoseStatus.taken),
      entry(8, DoseStatus.scheduled, day: 8),
    ], now);
    expect(p.header, 'All done today (2 of 2)');
    expect(p.rows.first.text, startsWith('Tomorrow'));
  });

  test('encode puts header first and prefixes rows', () {
    final p = buildWidgetPayload([entry(20, DoseStatus.scheduled)], now);
    final lines = p.encode().split('\n');
    expect(lines.first, p.header);
    expect(lines[1], startsWith('N\t'));
  });

  test('rows carry the dose key', () {
    final p = buildWidgetPayload([entry(20, DoseStatus.scheduled)], now);
    expect(p.rows.first.key, startsWith('1|'));
    expect(p.encode().split('\n')[1].split('\t')[1], p.rows.first.key);
  });
}
