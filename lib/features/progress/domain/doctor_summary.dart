import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
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
  List<String> allergies = const [],
  List<String> symptoms = const [],
  Map<MissReasonType, int> missReasons = const {},
  List<String> missNotes = const [],
  List<String> prescriptionChanges = const [],
}) {
  final b = StringBuffer()
    ..writeln('Reindeer medicine summary')
    ..writeln('Date: ${formatLongDate(now)}')
    ..writeln('Period: last $days days')
    ..writeln('Self-recorded, not verified intake')
    ..writeln();

  if (conditions.isNotEmpty) {
    b.writeln('Conditions: ${conditions.join(', ')}');
  }
  if (allergies.isNotEmpty) {
    b.writeln('Allergies: ${allergies.join(', ')}');
  }
  if (conditions.isNotEmpty || allergies.isNotEmpty) b.writeln();
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

  if (symptoms.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Symptoms I noted');
    for (final line in symptoms) {
      b.writeln('- $line');
    }
  }

  if (missReasons.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Missed dose reasons breakdown');
    for (final entry in missReasons.entries) {
      b.writeln('- ${entry.key.label}: ${entry.value}');
    }
  }

  if (missNotes.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Patient notes & side effects');
    for (final note in missNotes) {
      b.writeln('- $note');
    }
  }

  if (prescriptionChanges.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Prescription changes since last visit');
    for (final change in prescriptionChanges) {
      b.writeln('- $change');
    }
  }

  b
    ..writeln()
    ..writeln(
      'Self-recorded by patient/caregiver; not a verified clinical record.',
    );
  return b.toString();
}
