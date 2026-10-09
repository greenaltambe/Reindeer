import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';

/// How bad a symptom felt.
enum Severity {
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe');

  const Severity(this.label);

  final String label;

  static Severity fromLevel(int level) =>
      Severity.values[(level - 1).clamp(0, Severity.values.length - 1)];

  int get level => index + 1;
}

/// Symptoms offered as one-tap choices. Kept short on purpose.
const commonSymptoms = <String>[
  'Headache',
  'Dizziness',
  'Nausea',
  'Vomiting',
  'Stomach pain',
  'Loose motions',
  'Rash or itching',
  'Sleepiness',
  'Cough',
  'Fever',
  'Weakness',
  'Racing heart',
  'Swelling',
];

/// One entry in the symptom diary.
class SymptomEntry {
  const SymptomEntry({
    this.id,
    required this.symptom,
    required this.severity,
    this.note,
    required this.at,
  });

  final int? id;
  final String symptom;
  final Severity severity;
  final String? note;
  final DateTime at;
}

/// Medicines that were started within [windowDays] days before [at]. Used to show "what changed recently".
///
/// Only a pointer for the doctor: it says nothing about cause.
List<MedicationPlan> recentlyStarted(
  List<MedicationPlan> plans,
  DateTime at, {
  int windowDays = 14,
}) {
  final day = dateOnly(at);
  return [
    for (final p in plans)
      if (!dateOnly(p.startDate).isAfter(day) &&
          day.difference(dateOnly(p.startDate)).inDays <= windowDays)
        p,
  ];
}

/// Lines for the doctor summary, newest first.
List<String> symptomSummaryLines(List<SymptomEntry> entries, {int max = 12}) {
  final sorted = [...entries]..sort((a, b) => b.at.compareTo(a.at));
  return [
    for (final e in sorted.take(max))
      '${formatLongDate(e.at)}: ${e.symptom} (${e.severity.label.toLowerCase()})'
          '${(e.note ?? '').trim().isEmpty ? '' : ' - ${e.note!.trim()}'}',
  ];
}
