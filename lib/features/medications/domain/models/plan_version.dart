import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// A version of a medication plan effective from a specific date.
///
/// Ensures past dosing schedules, doses, and adherence remain true to what
/// was prescribed at that time, even when the doctor changes doses later.
class PlanVersion {
  const PlanVersion({
    this.id,
    required this.planId,
    required this.effectiveFrom,
    required this.slotAmounts,
    required this.mealTiming,
    this.intervalDays = 1,
    this.weekdays = 0,
    this.altAmounts,
    this.changeReason,
    required this.createdAt,
  });

  final int? id;
  final int planId;

  /// First calendar day this version applies to.
  final DateTime effectiveFrom;
  final Map<DaySlot, double> slotAmounts;
  final MealTiming mealTiming;
  final int intervalDays;
  final int weekdays;
  final Map<DaySlot, double>? altAmounts;

  /// Note explaining the change (e.g. "Doctor increased dose", "Switched to after meals").
  final String? changeReason;
  final DateTime createdAt;

  double amountFor(DaySlot slot) => slotAmounts[slot] ?? 0;

  List<DaySlot> get activeSlots => [
    for (final s in DaySlot.values)
      if (amountFor(s) > 0) s,
  ];

  String get patternLabel =>
      DaySlot.values.map((s) => formatAmount(amountFor(s))).join('-');

  String get altPatternLabel {
    final alt = altAmounts;
    if (alt == null) return '';
    return DaySlot.values.map((s) => formatAmount(alt[s] ?? 0)).join('-');
  }

  String doseSummary(DoseUnit doseUnit) => activeSlots
      .map((s) => '${s.label} ${doseUnit.describe(amountFor(s))}')
      .join(', ');

  String get frequencyLabel {
    if (weekdays != 0) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return [
        for (var i = 0; i < 7; i++)
          if (weekdays & (1 << i) != 0) tr(names[i]),
      ].join(', ');
    }
    if (intervalDays == 2) return tr('Every other day');
    if (intervalDays > 2) return trf('Every {n} days', {'n': '$intervalDays'});
    return '';
  }
}

/// A specific time window during which taking this medication was paused.
class PlanPause {
  const PlanPause({
    this.id,
    required this.planId,
    required this.pausedAt,
    this.resumedAt,
    this.reason,
  });

  final int? id;
  final int planId;
  final DateTime pausedAt;
  final DateTime? resumedAt;
  final String? reason;

  /// True if currently in active pause (no resume date recorded yet).
  bool get isOngoing => resumedAt == null;

  /// Whether a dose at [at] falls inside this pause window (not due).
  bool contains(DateTime at) {
    if (at.isBefore(pausedAt)) return false;
    final r = resumedAt;
    if (r == null) return true;
    return at.isBefore(r);
  }
}
