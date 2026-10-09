import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/plan_version.dart';
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

  /// Calendar date string `yyyy-MM-dd`.
  String get doseDate => isoDate(at);

  /// Stable identity across meal-time changes: `planId|yyyy-MM-dd|slot`.
  ///
  /// Preserves dose logging when meal anchors shift (e.g. breakfast moved 8:00 -> 8:30).
  String get key => '$planId|$doseDate|${slot.name}';

  /// Legacy clock-time key: `planId|yyyy-MM-ddTHH:mm`.
  String get legacyKey => '$planId|${isoDateTime(at)}';

  /// Parses either modern (`planId|yyyy-MM-dd|slot`) or legacy (`planId|yyyy-MM-ddTHH:mm`) keys.
  static ({int planId, String date, String slot})? parseKey(String key) {
    final parts = key.split('|');
    if (parts.length == 3) {
      final pid = int.tryParse(parts[0]);
      if (pid != null) {
        return (planId: pid, date: parts[1], slot: parts[2]);
      }
    } else if (parts.length == 2) {
      final pid = int.tryParse(parts[0]);
      final dt = DateTime.tryParse(parts[1]);
      if (pid != null && dt != null) {
        final slot = dt.hour < 12
            ? DaySlot.morning.name
            : (dt.hour < 17 ? DaySlot.afternoon.name : DaySlot.night.name);
        return (planId: pid, date: isoDate(dt), slot: slot);
      }
    }
    return null;
  }
}

/// How one profile takes one medicine: amounts per part of day, food timing,
/// duration, and stock. Supports versioning and multiple pause windows.
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
    this.intervalDays = 1,
    this.weekdays = 0,
    this.altAmounts,
    this.versions,
    this.pauses,
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

  /// Legacy fields kept for backward compatibility and simple status queries.
  final DateTime? stoppedAt;
  final DateTime? resumedAt;

  /// Units left (tablets, ml, ...); null when stock is not tracked.
  final double? stock;
  final double? lowStockThreshold;

  /// Pack size from the database, offered as a quick refill amount.
  final double? packQty;
  final DateTime createdAt;

  /// Doses are due every this many days from [startDate] (1 = every day,
  /// 2 = every other day).
  final int intervalDays;

  /// Days of the week doses are due, as a bit mask: bit 0 = Monday ...
  /// bit 6 = Sunday. 0 means no weekday rule (see [intervalDays]).
  final int weekdays;

  /// A second set of amounts used on every other due day (for example 1 tablet
  /// one day and 2 the next). Null when every dose is the same.
  final Map<DaySlot, double>? altAmounts;

  /// Versioned history of schedule/amount changes.
  final List<PlanVersion>? versions;

  /// Historical and current pause windows.
  final List<PlanPause>? pauses;

  bool get isActive => status == PlanStatus.active;

  double amountFor(DaySlot slot) => slotAmounts[slot] ?? 0;

  /// True when doses are not simply every day.
  bool get hasCustomDays => intervalDays > 1 || weekdays != 0;

  /// Returns the specific version effective on [day], if any.
  PlanVersion? versionFor(DateTime day) {
    final v = versions;
    if (v == null || v.isEmpty) return null;
    final d = dateOnly(day);
    PlanVersion? match;
    for (final candidate in v) {
      if (!dateOnly(candidate.effectiveFrom).isAfter(d)) {
        if (match == null ||
            dateOnly(candidate.effectiveFrom)
                .isAfter(dateOnly(match.effectiveFrom))) {
          match = candidate;
        }
      }
    }
    return match;
  }

  /// Whether the dose pattern is due on [day], ignoring start/end dates.
  bool isDueOn(DateTime day) {
    final v = versionFor(day);
    final w = v?.weekdays ?? weekdays;
    final i = v?.intervalDays ?? intervalDays;
    final d = dateOnly(day);
    if (w != 0) {
      return w & (1 << (d.weekday - 1)) != 0;
    }
    if (i > 1) return _dayIndex(d) % i == 0;
    return true;
  }

  int _dayIndex(DateTime d) => d.difference(dateOnly(startDate)).inDays;

  /// Amounts per part of the day on [day]: the second set ([altAmounts]) on
  /// every other due day, otherwise the usual amounts.
  Map<DaySlot, double> amountsOn(DateTime day) {
    final v = versionFor(day);
    final base = v?.slotAmounts ?? slotAmounts;
    final alt = v?.altAmounts ?? altAmounts;
    final w = v?.weekdays ?? weekdays;
    final i = v?.intervalDays ?? intervalDays;
    if (alt == null || w != 0) return base;
    final d = dateOnly(day);
    final n = i < 1 ? 1 : i;
    final occurrence = _dayIndex(d) ~/ n;
    return occurrence.isOdd ? alt : base;
  }

  /// Average amount taken per calendar day, for working out how long stock
  /// lasts.
  double get averageDailyAmount {
    double sum(Map<DaySlot, double> m) =>
        DaySlot.values.fold<double>(0, (a, s) => a + (m[s] ?? 0));
    final alt = altAmounts;
    final perDueDay = (alt == null || weekdays != 0)
        ? sum(slotAmounts)
        : (sum(slotAmounts) + sum(alt)) / 2;
    if (weekdays != 0) {
      var days = 0;
      for (var i = 0; i < 7; i++) {
        if (weekdays & (1 << i) != 0) days++;
      }
      return perDueDay * days / 7;
    }
    return perDueDay / (intervalDays < 1 ? 1 : intervalDays);
  }

  /// "Every other day", "Mon, Wed, Fri" or "" for every day.
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

  /// The alternate amounts as `2-0-2`, or "" when there are none.
  String get altPatternLabel {
    final alt = altAmounts;
    if (alt == null) return '';
    return DaySlot.values.map((s) => formatAmount(alt[s] ?? 0)).join('-');
  }

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
    final avg = averageDailyAmount;
    if (s == null || avg <= 0) return null;
    return s / avg;
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
  ///
  /// Uses the effective version on [day] so past dosing records remain untouched.
  List<PlannedDose> dosesOn(DateTime day, MealAnchors anchors) {
    final planId = id;
    if (planId == null || !coversDay(day)) return const [];

    if (!isDueOn(day)) return const [];

    final v = versionFor(day);
    final timing = v?.mealTiming ?? mealTiming;
    final amounts = amountsOn(day);
    final d = dateOnly(day);
    final out = <PlannedDose>[];
    for (final slot in DaySlot.values) {
      if ((amounts[slot] ?? 0) <= 0) continue;
      final minutes = anchors.minutesFor(slot, timing);
      final at = DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);

      if (pauses != null && pauses!.isNotEmpty) {
        if (pauses!.any((p) => p.contains(at))) continue;
      }
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
          amount: amounts[slot] ?? 0,
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
    DateTime? resumedAt,
    double? stock,
    double? lowStockThreshold,
    double? packQty,
    Map<DaySlot, double>? slotAmounts,
    MealTiming? mealTiming,
    int? intervalDays,
    int? weekdays,
    Map<DaySlot, double>? altAmounts,
    List<PlanVersion>? versions,
    List<PlanPause>? pauses,
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
      slotAmounts: slotAmounts ?? this.slotAmounts,
      mealTiming: mealTiming ?? this.mealTiming,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
      resumedAt: resumedAt ?? this.resumedAt,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      packQty: packQty ?? this.packQty,
      createdAt: createdAt,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      altAmounts: altAmounts ?? this.altAmounts,
      versions: versions ?? this.versions,
      pauses: pauses ?? this.pauses,
    );
  }
}
