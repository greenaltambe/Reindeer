import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/routine/domain/routine_learning.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

void main() {
  const anchors = MealAnchors(); // breakfast 8:00

  DoseLog taken(int day, int dueH, int dueM, int actH, int actM) => DoseLog(
    planId: 1,
    scheduledAt: DateTime(2026, 10, day, dueH, dueM),
    status: DoseStatus.taken,
    actedAt: DateTime(2026, 10, day, actH, actM),
    amount: 1,
  );

  test('suggests a later breakfast when doses are taken late', () {
    final logs = [for (var d = 1; d <= 8; d++) taken(d, 8, 0, 9, 10)];
    final s = learnRoutine(logs: logs, anchors: anchors);
    expect(s.length, 1);
    expect(s.first.slot, DaySlot.morning);
    expect(s.first.suggestedMinutes, 9 * 60 + 10);
    expect(s.first.samples, 8);
  });

  test('nothing when on time or too few samples', () {
    final onTime = [for (var d = 1; d <= 8; d++) taken(d, 8, 0, 8, 10)];
    expect(learnRoutine(logs: onTime, anchors: anchors), isEmpty);
    final few = [for (var d = 1; d <= 3; d++) taken(d, 8, 0, 9, 30)];
    expect(learnRoutine(logs: few, anchors: anchors), isEmpty);
  });

  test('ignores next-day and skipped doses', () {
    final logs = [
      for (var d = 1; d <= 8; d++)
        DoseLog(
          planId: 1,
          scheduledAt: DateTime(2026, 10, d, 8),
          status: DoseStatus.taken,
          actedAt: DateTime(2026, 10, d + 1, 9),
          amount: 1,
        ),
      for (var d = 1; d <= 8; d++)
        DoseLog(
          planId: 1,
          scheduledAt: DateTime(2026, 10, d, 8),
          status: DoseStatus.skipped,
          actedAt: DateTime(2026, 10, d, 10),
          amount: 1,
        ),
    ];
    expect(learnRoutine(logs: logs, anchors: anchors), isEmpty);
  });

  test('after-food doses still map to the breakfast meal', () {
    // After breakfast = 8:30 due, taken 9:40: shift of 70 minutes.
    final logs = [for (var d = 1; d <= 8; d++) taken(d, 8, 30, 9, 40)];
    final s = learnRoutine(logs: logs, anchors: anchors);
    expect(s.single.suggestedMinutes, 9 * 60 + 10);
  });
}
