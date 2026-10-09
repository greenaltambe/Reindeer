import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/symptoms/domain/symptom_catalog.dart';

/// Side effects listed in the data for a medicine id ('' when unknown).
final sideEffectsProvider = FutureProvider.family<String, int>((
  ref,
  medicineId,
) async {
  final service = await ref.watch(medicineSearchProvider.future);
  final key = await service.ingredientsOf(medicineId);
  return service.sideEffectsFor(key);
});

/// Names of the person's active medicines that list [symptom] as a possible
/// side effect. A pointer for the doctor, not proof of cause.
final symptomLinksProvider = FutureProvider.family<List<String>, String>((
  ref,
  symptom,
) async {
  if (symptom.trim().isEmpty) return const [];
  final plans = await ref.watch(plansProvider.future);
  final out = <String>[];
  for (final p in plans) {
    final id = p.medicineId;
    if (!p.isActive || id == null) continue;
    final effects = await ref.watch(sideEffectsProvider(id).future);
    if (listedAsSideEffect(symptom, effects)) out.add(p.name);
  }
  return out;
});
