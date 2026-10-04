import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';

/// One scheduled dose of one plan at one time.
class PlannedDose {
  const PlannedDose({
    required this.planId,
    required this.at,
    required this.slot,
    required this.amount,
  });

  final int planId;
  final DateTime at;
  final DaySlot slot;
  final double amount;

  /// Stable identity used to match logs and notifications: `planId|yyyy-MM-ddTHH:mm`.
  String get key => '$planId|${isoDateTime(at)}';
}

/// How one profile takes one medicine: amounts per part of day, food timing,
/// duration, and stock.
class MedicationPlan {
  MedicationPlan({
    this.id,
    required this.profileId,
    this.medicineId,
    required this.name,
    this.composition = '',
    this.kind = MedicineKind.custom,
    this.condition,
    required this.doseUnit,
    required this.slotAmounts,
    this.mealTiming = MealTiming.anytime,
    required this.startDate,
    this.endDate,
    this.status = PlanStatus.active,
    this.stoppedAt,
    this.resumedAt,
    this.stock,
    this.lowStockThreshold,
    this.packQty,
    required this.createdAt,
  }) : assert(name != '', 'A plan needs a medicine name');

  /// Database id; null until saved.
  final int? id;
  final String profileId;

  /// Row id in the bundled medicine database, or null for a custom medicine.
  final int? medicineId;
  final String name;
  final String composition;
  final MedicineKind kind;

  /// Optional "what is it for", free text.
  final String? condition;
  final DoseUnit doseUnit;

  /// Amount per dose for each part of the day; missing or 0 means no dose.
  final Map<DaySlot, double> slotAmounts;
  final MealTiming mealTiming;
  final DateTime startDate;

  /// Last day (inclusive) a dose is due; null means ongoing.
  final DateTime? endDate;
  final PlanStatus status;

  /// When the plan was paused or stopped; doses at or after this are not due.
  final DateTime? stoppedAt;

  /// When a paused plan was resumed; doses between [stoppedAt] and this are
  /// not due (the pause), so they never show up as missed.
  final DateTime? resumedAt;

  /// Units left (tablets, ml, ...); null when stock is not tracked.
  final double? stock;
  final double? lowStockThreshold;

  /// Pack size from the database, offered as a quick refill amount.
  final double? packQty;
  final DateTime createdAt;

  bool get isActive => status == PlanStatus.active;

  double amountFor(DaySlot slot) => slotAmounts[slot] ?? 0;

  List<DaySlot> get activeSlots => [
    for (final s in DaySlot.values)
      if (amountFor(s) > 0) s,
  ];

  double get dailyAmount =>
      DaySlot.values.fold<double>(0, (sum, s) => sum + amountFor(s));

  /// `1-0-1` style pattern.
  String get patternLabel =>
      DaySlot.values.map((s) => formatAmount(amountFor(s))).join('-');

  /// For example `Morning 1 tablet, Night 1 tablet`.
  String get doseSummary => activeSlots
      .map((s) => '${s.label} ${doseUnit.describe(amountFor(s))}')
      .join(', ');

  double? get daysOfStockLeft {
    final s = stock;
    if (s == null || dailyAmount <= 0) return null;
    return s / dailyAmount;
  }

  /// True when stock is tracked and at or below the threshold, or under 3 days.
  bool get isLowStock {
    final s = stock;
    if (s == null || !isActive) return false;
    final threshold = lowStockThreshold;
    if (threshold != null && s <= threshold) return true;
    final days = daysOfStockLeft;
    return days != null && days <= 3;
  }

  /// Whole days left in the course, counting today; null if ongoing.
  int? daysLeftInCourse(DateTime now) {
    final end = endDate;
    if (end == null) return null;
    final left = dateOnly(end).difference(dateOnly(now)).inDays + 1;
    return left < 0 ? 0 : left;
  }

  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(dateOnly(startDate))) return false;
    final end = endDate;
    if (end != null && d.isAfter(dateOnly(end))) return false;
    return true;
  }

  /// Doses due on [day], resolved through the meal [anchors].
  List<PlannedDose> dosesOn(DateTime day, MealAnchors anchors) {
    final planId = id;
    if (planId == null || !coversDay(day)) return const [];
    final d = dateOnly(day);
    final out = <PlannedDose>[];
    for (final slot in activeSlots) {
      final minutes = anchors.minutesFor(slot, mealTiming);
      final at = DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
      final stopped = stoppedAt;
      if (!isActive) {
        if (stopped == null || !at.isBefore(stopped)) continue;
      } else {
        final resumed = resumedAt;
        if (stopped != null &&
            resumed != null &&
            !at.isBefore(stopped) &&
            at.isBefore(resumed)) {
          continue;
        }
      }
      out.add(
        PlannedDose(
          planId: planId,
          at: at,
          slot: slot,
          amount: amountFor(slot),
        ),
      );
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  MedicationPlan copyWith({
    PlanStatus? status,
    DateTime? stoppedAt,
    bool clearStoppedAt = false,
    double? stock,
  }) {
    return MedicationPlan(
      id: id,
      profileId: profileId,
      medicineId: medicineId,
      name: name,
      composition: composition,
      kind: kind,
      condition: condition,
      doseUnit: doseUnit,
      slotAmounts: slotAmounts,
      mealTiming: mealTiming,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
      resumedAt: resumedAt,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold,
      packQty: packQty,
      createdAt: createdAt,
    );
  }
}
