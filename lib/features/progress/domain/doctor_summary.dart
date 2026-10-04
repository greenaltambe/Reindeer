import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';

/// Plain-text summary of current medicines and recent adherence, meant to be
/// pasted into a message or shown to a doctor.
String buildDoctorSummary({
  required List<MedicationPlan> plans,
  required AdherenceSummary summary,
  required int days,
  required DateTime now,
  List<String> readings = const [],
  List<String> conditions = const [],
}) {
  final b = StringBuffer()
    ..writeln('Reindeer medicine summary')
    ..writeln('Date: ${formatLongDate(now)}')
    ..writeln('Period: last $days days')
    ..writeln();

  if (conditions.isNotEmpty) {
    b
      ..writeln('Conditions: ${conditions.join(', ')}')
      ..writeln();
  }
  final active = plans.where((p) => p.isActive).toList();
  b.writeln('Current medicines');
  if (active.isEmpty) {
    b.writeln('- none');
  }
  for (final p in active) {
    final timing = p.mealTiming == MealTiming.anytime
        ? ''
        : ', ${p.mealTiming.label.toLowerCase()}';
    final reason = p.condition == null ? '' : ' (for ${p.condition})';
    b.writeln('- ${p.name}: ${p.patternLabel}, ${p.doseSummary}$timing$reason');
  }

  b.writeln();
  final overall = summary.overall;
  if (overall == null) {
    b.writeln('Adherence: not enough data yet.');
  } else {
    b.writeln(
      'Adherence: ${(overall * 100).round()}% '
      '(${summary.taken} taken, ${summary.missed} missed, ${summary.skipped} skipped)',
    );
    for (final p in active) {
      final v = summary.byPlan[p.id];
      if (v != null) b.writeln('- ${p.name}: ${(v * 100).round()}%');
    }
    final obs = summary.observation;
    if (obs != null) b.writeln(obs);
  }

  if (readings.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Latest readings');
    for (final r in readings) {
      b.writeln('- $r');
    }
  }

  b
    ..writeln()
    ..writeln('Based on doses marked in a reminder app; not a medical record.');
  return b.toString();
}
