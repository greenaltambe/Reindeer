import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/adherence_calculator.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

/// One dose with its effective status.
class DoseEntry {
  const DoseEntry({
    required this.plan,
    required this.dose,
    required this.status,
    this.actedAt,
  });

  final MedicationPlan plan;
  final PlannedDose dose;

  /// `taken` / `skipped` from the log, otherwise `missed` once the grace window
  /// has passed, otherwise `scheduled` (still pending).
  final DoseStatus status;
  final DateTime? actedAt;

  bool get isPending => status == DoseStatus.scheduled;
  bool get isOpen =>
      status == DoseStatus.scheduled || status == DoseStatus.missed;
}

/// Expands plans into doses over a date range and merges them with the logs.
abstract final class DoseTimeline {
  /// Builds entries for days [fromDay]..[toDay] inclusive, sorted by time.
  ///
  /// [logs] is keyed by [PlannedDose.key]. A dose due before its plan was
  /// created is skipped unless it was logged, so adding a medicine at 3 pm does
  /// not mark the 8 am dose as missed.
  static List<DoseEntry> build({
    required List<MedicationPlan> plans,
    required Map<String, DoseLog> logs,
    required MealAnchors anchors,
    required DateTime fromDay,
    required DateTime toDay,
    required DateTime now,
  }) {
    final out = <DoseEntry>[];
    final last = dateOnly(toDay);
    for (final plan in plans) {
      final doses = <PlannedDose>[];
      for (var d = dateOnly(fromDay); !d.isAfter(last); d = nextDay(d)) {
        doses.addAll(plan.dosesOn(d, anchors));
      }
      for (var i = 0; i < doses.length; i++) {
        final dose = doses[i];
        final log = logs[dose.key];
        if (log != null) {
          out.add(
            DoseEntry(
              plan: plan,
              dose: dose,
              status: log.status,
              actedAt: log.actedAt,
            ),
          );
          continue;
        }
        if (dose.at.isBefore(plan.createdAt)) continue;
        final next = i + 1 < doses.length ? doses[i + 1].at : null;
        final deadline = missedDeadline(dose.at, nextScheduledAt: next);
        out.add(
          DoseEntry(
            plan: plan,
            dose: dose,
            status: now.isAfter(deadline)
                ? DoseStatus.missed
                : DoseStatus.scheduled,
          ),
        );
      }
    }
    out.sort((a, b) => a.dose.at.compareTo(b.dose.at));
    return out;
  }
}

/// Adherence numbers for a set of entries.
class AdherenceSummary {
  const AdherenceSummary({
    required this.overall,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.byPlan,
    required this.missedBySlot,
    required this.byDay,
  });

  /// Fraction 0..1, or null when nothing has been resolved yet.
  final double? overall;
  final int taken;
  final int skipped;
  final int missed;
  final Map<int, double?> byPlan;
  final Map<DaySlot, int> missedBySlot;
  final Map<DateTime, double?> byDay;

  /// A plain observation, not a diagnosis; null when there is nothing to say.
  String? get observation {
    DaySlot? worst;
    var worstCount = 0;
    missedBySlot.forEach((slot, count) {
      if (count > worstCount) {
        worst = slot;
        worstCount = count;
      }
    });
    final slot = worst;
    if (slot == null || worstCount < 2) return null;
    return '${slot.label} doses were missed $worstCount times in this period.';
  }

  static AdherenceSummary from(List<DoseEntry> entries, DateTime now) {
    final past = entries.where((e) => !e.dose.at.isAfter(now)).toList();
    final planStatuses = <int, List<DoseStatus>>{};
    final dayStatuses = <DateTime, List<DoseStatus>>{};
    final missedBySlot = <DaySlot, int>{};
    var taken = 0, skipped = 0, missed = 0;
    for (final e in past) {
      planStatuses.putIfAbsent(e.dose.planId, () => []).add(e.status);
      dayStatuses.putIfAbsent(dateOnly(e.dose.at), () => []).add(e.status);
      switch (e.status) {
        case DoseStatus.taken:
          taken++;
        case DoseStatus.skipped:
          skipped++;
        case DoseStatus.missed:
          missed++;
          missedBySlot[e.dose.slot] = (missedBySlot[e.dose.slot] ?? 0) + 1;
        case DoseStatus.scheduled:
        case DoseStatus.snoozed:
          break;
      }
    }
    return AdherenceSummary(
      overall: adherenceFraction(past.map((e) => e.status)),
      taken: taken,
      skipped: skipped,
      missed: missed,
      byPlan: {
        for (final e in planStatuses.entries) e.key: adherenceFraction(e.value),
      },
      missedBySlot: missedBySlot,
      byDay: {
        for (final e in dayStatuses.entries) e.key: adherenceFraction(e.value),
      },
    );
  }
}
