import 'package:reindeer/features/medications/domain/models/medication_plan.dart';

/// Plain text for the Medical ID card, to read out or share in an emergency.
String buildMedicalIdText({
  required String name,
  int? age,
  required List<String> allergies,
  required List<String> conditions,
  required List<MedicationPlan> plans,
}) {
  final b = StringBuffer()..writeln('MEDICAL ID');
  final who = [
    if (name.trim().isNotEmpty) name.trim(),
    if (age != null) 'age $age',
  ].join(', ');
  if (who.isNotEmpty) b.writeln(who);
  b
    ..writeln()
    ..writeln(
      'Allergies: ${allergies.isEmpty ? 'none noted' : allergies.join(', ')}',
    )
    ..writeln(
      'Conditions: ${conditions.isEmpty ? 'none noted' : conditions.join(', ')}',
    )
    ..writeln()
    ..writeln('Medicines I take:');
  final active = plans.where((p) => p.isActive).toList();
  if (active.isEmpty) b.writeln('- none');
  for (final p in active) {
    final comp = p.composition.trim().isEmpty
        ? ''
        : ' (${p.composition.trim()})';
    b.writeln('- ${p.name}$comp: ${p.patternLabel}');
  }
  b
    ..writeln()
    ..writeln('From the Reindeer app. Entered by me; not a medical record.');
  return b.toString();
}
