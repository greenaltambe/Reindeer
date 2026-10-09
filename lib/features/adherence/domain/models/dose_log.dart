import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// What happened to a scheduled dose.
///
/// `taken` and `skipped` are stored. `missed` and `scheduled` (still pending)
/// are derived from the clock when no log exists. `snoozed` is reserved.
enum DoseStatus {
  scheduled,
  taken,
  skipped,
  missed,
  snoozed;

  static DoseStatus fromName(String? name) => DoseStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => DoseStatus.scheduled,
  );
}

/// Stored outcome of one scheduled dose of one medication plan.
class DoseLog {
  DoseLog({
    this.id,
    required this.planId,
    required this.scheduledAt,
    required this.status,
    required this.actedAt,
    required this.amount,
    String? doseDate,
    DaySlot? slot,
  }) : doseDate = doseDate ?? isoDate(scheduledAt),
       slot =
           slot ??
           (scheduledAt.hour < 12
               ? DaySlot.morning
               : (scheduledAt.hour < 17 ? DaySlot.afternoon : DaySlot.night));

  final int? id;
  final int planId;
  final String doseDate;
  final DaySlot slot;
  final DateTime scheduledAt;
  final DoseStatus status;

  /// When the person tapped Taken or Skip.
  final DateTime actedAt;
  final double amount;

  /// Stable dose identity key: `planId|doseDate|slot`.
  String get doseKey => '$planId|$doseDate|${slot.name}';
}

/// Default grace window before an unanswered dose becomes `missed`.
const Duration defaultGraceWindow = Duration(hours: 2);

/// Time at which an unanswered dose scheduled at [scheduledAt] becomes missed:
/// [grace] after the slot, or the next dose of the same plan, whichever is
/// earlier.
DateTime missedDeadline(
  DateTime scheduledAt, {
  DateTime? nextScheduledAt,
  Duration grace = defaultGraceWindow,
}) {
  final byGrace = scheduledAt.add(grace);
  if (nextScheduledAt != null && nextScheduledAt.isBefore(byGrace)) {
    return nextScheduledAt;
  }
  return byGrace;
}
