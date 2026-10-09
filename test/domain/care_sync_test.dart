import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/care/application/care_sync.dart';
import 'package:reindeer/features/care/presentation/help_sheet.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

MedicationPlan plan({
  int id = 1,
  String name = 'Metformin',
  Map<DaySlot, double> amounts = const {
    DaySlot.morning: 1,
    DaySlot.afternoon: 0,
    DaySlot.night: 1,
  },
  PlanStatus status = PlanStatus.active,
}) => MedicationPlan(
  id: id,
  profileId: 'me',
  name: name,
  doseUnit: DoseUnit.tablet,
  slotAmounts: amounts,
  mealTiming: MealTiming.anytime,
  startDate: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  status: status,
);

List<SharedDose> build(
  List<MedicationPlan> plans, {
  Map<String, DoseLog> logs = const {},
  Map<String, String> reasons = const {},
  DateTime? now,
}) => buildSharedDoses(
  plans: plans,
  logs: logs,
  reasons: reasons,
  now: now ?? DateTime(2026, 10, 9, 12),
  dosesOn: (p, day) => p.dosesOn(day, const MealAnchors()),
);

void main() {
  test('shares yesterday, today and the next two days', () {
    final doses = build([plan()]);
    final dates = doses.map((d) => d.data['date']).toSet();
    expect(dates, {'2026-10-08', '2026-10-09', '2026-10-10', '2026-10-11'});
    expect(doses, hasLength(8));
    expect(doses.every((d) => d.data['status'] == 'pending'), isTrue);
  });

  test('paused medicines are not shared', () {
    expect(build([plan(status: PlanStatus.paused)]), isEmpty);
  });

  test('ids are stable and readable', () {
    final first = build([plan(id: 7)]).first;
    expect(first.id, '2026-10-08_7_morning');
  });

  test('deadline is the grace window, or the next dose if sooner', () {
    final doses = build([plan()]);
    for (final d in doses) {
      final at = d.data['at']! as DateTime;
      expect(d.deadline.difference(at), lessThanOrEqualTo(defaultGraceWindow));
      expect(d.deadline.isAfter(at), isTrue);
    }
  });

  test('taken and skipped doses carry when and why', () {
    final p = plan();
    final today = p.dosesOn(DateTime(2026, 10, 9), const MealAnchors());
    final morning = today.first;
    final night = today.last;
    final doses = build(
      [p],
      logs: {
        morning.key: DoseLog(
          planId: 1,
          scheduledAt: morning.at,
          status: DoseStatus.taken,
          actedAt: DateTime(2026, 10, 9, 8, 20),
          amount: 1,
          doseDate: morning.doseDate,
          slot: morning.slot,
        ),
        night.key: DoseLog(
          planId: 1,
          scheduledAt: night.at,
          status: DoseStatus.skipped,
          actedAt: DateTime(2026, 10, 9, 11),
          amount: 1,
          doseDate: night.doseDate,
          slot: night.slot,
        ),
      },
      reasons: {night.key: 'fastingTravel'},
    );
    final taken = doses.firstWhere((d) => d.id == '2026-10-09_1_morning');
    expect(taken.data['status'], 'taken');
    expect(taken.data['doneTime'], '8:20 AM');
    expect(taken.data.containsKey('reason'), isFalse);
    final skipped = doses.firstWhere((d) => d.id == '2026-10-09_1_night');
    expect(skipped.data['status'], 'skipped');
    expect(skipped.data['reason'], 'fastingTravel');
  });

  test('fingerprint changes only when what caretakers see changes', () {
    final a = build([plan()]).first;
    final b = build([plan()]).first;
    expect(a.fingerprint, b.fingerprint);
    final renamed = build([plan(name: 'Glycomet')]).first;
    expect(renamed.fingerprint, isNot(a.fingerprint));
  });

  test('WhatsApp numbers get the India code when it is missing', () {
    expect(whatsappNumber('98765 43210'), '919876543210');
    expect(whatsappNumber('098765-43210'), '919876543210');
    expect(whatsappNumber('+91 98765 43210'), '919876543210');
    expect(whatsappNumber('+44 7700 900123'), '447700900123');
  });
}
