import 'package:reindeer/features/adherence/domain/models/dose_log.dart';

/// Adherence over doses whose time has passed.
///
/// `taken / (taken + skipped + missed)`. Scheduled and snoozed doses are still
/// pending and excluded. Returns null when nothing has been resolved yet, so
/// the UI can show "no data" rather than a misleading 0% or 100%.
double? adherenceFraction(Iterable<DoseStatus> statuses) {
  var taken = 0;
  var resolved = 0;
  for (final s in statuses) {
    switch (s) {
      case DoseStatus.taken:
        taken++;
        resolved++;
      case DoseStatus.skipped:
      case DoseStatus.missed:
        resolved++;
      case DoseStatus.scheduled:
      case DoseStatus.snoozed:
        break;
    }
  }
  return resolved == 0 ? null : taken / resolved;
}
