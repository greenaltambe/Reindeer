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
  const DoseLog({
    this.id,
    required this.planId,
    required this.scheduledAt,
    required this.status,
    required this.actedAt,
    required this.amount,
  });

  final int? id;
  final int planId;
  final DateTime scheduledAt;
  final DoseStatus status;

  /// When the person tapped Taken or Skip.
  final DateTime actedAt;
  final double amount;
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
