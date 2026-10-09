import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';

/// Type of change in a prescription reconciliation.
enum PlanDiffType {
  started,
  adjusted,
  stopped,
  unchanged;

  String get label => switch (this) {
    PlanDiffType.started => tr('Started'),
    PlanDiffType.adjusted => tr('Adjusted'),
    PlanDiffType.stopped => tr('Stopped'),
    PlanDiffType.unchanged => tr('Unchanged'),
  };
}

/// One difference between an old prescription regimen and a new one.
class PlanDiffItem {
  const PlanDiffItem({
    required this.type,
    required this.name,
    this.oldSummary,
    this.newSummary,
    this.reason,
  });

  final PlanDiffType type;
  final String name;
  final String? oldSummary;
  final String? newSummary;
  final String? reason;

  String get displayDiff {
    switch (type) {
      case PlanDiffType.started:
        return 'Started: $name ($newSummary)';
      case PlanDiffType.stopped:
        return 'Stopped: $name';
      case PlanDiffType.adjusted:
        return 'Adjusted: $name (was $oldSummary -> now $newSummary)';
      case PlanDiffType.unchanged:
        return '$name: unchanged';
    }
  }
}

/// Calculates the reconciliation diff between previous plans and updated plans.
List<PlanDiffItem> computePrescriptionDiff({
  required List<MedicationPlan> previousPlans,
  required List<MedicationPlan> currentPlans,
}) {
  final out = <PlanDiffItem>[];
  final prevMap = {
    for (final p in previousPlans) p.name.trim().toLowerCase(): p,
  };
  final currMap = {
    for (final p in currentPlans) p.name.trim().toLowerCase(): p,
  };

  // 1. Detect started and adjusted
  for (final curr in currentPlans) {
    final key = curr.name.trim().toLowerCase();
    final prev = prevMap[key];

    if (prev == null) {
      out.add(
        PlanDiffItem(
          type: PlanDiffType.started,
          name: curr.name,
          newSummary: '${curr.patternLabel} ${curr.doseSummary}',
        ),
      );
    } else {
      // Check if amounts or timing changed
      final amountsChanged = curr.patternLabel != prev.patternLabel;
      final timingChanged = curr.mealTiming != prev.mealTiming;
      final daysChanged =
          curr.intervalDays != prev.intervalDays ||
          curr.weekdays != prev.weekdays;

      if (amountsChanged || timingChanged || daysChanged) {
        out.add(
          PlanDiffItem(
            type: PlanDiffType.adjusted,
            name: curr.name,
            oldSummary: '${prev.patternLabel} (${prev.mealTiming.label})',
            newSummary: '${curr.patternLabel} (${curr.mealTiming.label})',
          ),
        );
      } else {
        out.add(
          PlanDiffItem(
            type: PlanDiffType.unchanged,
            name: curr.name,
            newSummary: curr.patternLabel,
          ),
        );
      }
    }
  }

  // 2. Detect stopped
  for (final prev in previousPlans) {
    final key = prev.name.trim().toLowerCase();
    if (!currMap.containsKey(key) ||
        (currMap[key]?.status == PlanStatus.discontinued &&
            prev.status != PlanStatus.discontinued)) {
      out.add(
        PlanDiffItem(
          type: PlanDiffType.stopped,
          name: prev.name,
          oldSummary: prev.patternLabel,
        ),
      );
    }
  }

  return out;
}
