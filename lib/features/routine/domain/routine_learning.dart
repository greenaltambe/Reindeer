import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

/// "You usually take your morning medicines at 9:10, not 8:00."
class RoutineSuggestion {
  const RoutineSuggestion({
    required this.slot,
    required this.currentMinutes,
    required this.suggestedMinutes,
    required this.samples,
  });

  final DaySlot slot;

  /// The meal time now in use (minutes since midnight).
  final int currentMinutes;

  /// The meal time that would match what the person actually does.
  final int suggestedMinutes;

  /// How many taken doses this is based on.
  final int samples;
}

int _minutesOf(DateTime d) => d.hour * 60 + d.minute;

int _median(List<int> sorted) {
  final n = sorted.length;
  return n.isOdd
      ? sorted[n ~/ 2]
      : ((sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2).round();
}

/// Compares when doses were taken with when they were due and suggests
/// moving a meal time when the person is consistently earlier or later.
///
/// Only doses taken the same day within 3 hours of their time are used, so a
/// forgotten dose ticked off the next day does not skew the result. At least
/// [minSamples] doses and a gap of [minShift] minutes are needed.
List<RoutineSuggestion> learnRoutine({
  required Iterable<DoseLog> logs,
  required MealAnchors anchors,
  int minSamples = 7,
  int minShift = 30,
}) {
  final deltas = <DaySlot, List<int>>{for (final s in DaySlot.values) s: []};
  for (final log in logs) {
    if (log.status != DoseStatus.taken) continue;
    final due = log.scheduledAt;
    final acted = log.actedAt;
    if (acted.year != due.year ||
        acted.month != due.month ||
        acted.day != due.day) {
      continue;
    }
    final delta = _minutesOf(acted) - _minutesOf(due);
    if (delta < -60 || delta > 180) continue;
    // Which meal is this dose tied to? The nearest one, within 90 minutes.
    DaySlot? best;
    var bestGap = 91;
    for (final s in DaySlot.values) {
      final gap = (_minutesOf(due) - anchors.anchorFor(s)).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = s;
      }
    }
    if (best != null) deltas[best]!.add(delta);
  }

  final out = <RoutineSuggestion>[];
  for (final s in DaySlot.values) {
    final list = deltas[s]!..sort();
    if (list.length < minSamples) continue;
    final shift = _median(list);
    if (shift.abs() < minShift) continue;
    final suggested = ((anchors.anchorFor(s) + shift) / 5).round() * 5;
    out.add(
      RoutineSuggestion(
        slot: s,
        currentMinutes: anchors.anchorFor(s),
        suggestedMinutes: suggested.clamp(0, 24 * 60 - 1).toInt(),
        samples: list.length,
      ),
    );
  }
  return out;
}
