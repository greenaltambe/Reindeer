import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/ingredients.dart';

/// An active medicine that shares an ingredient with one being added.
class IngredientOverlap {
  const IngredientOverlap(this.plan, this.ingredients);

  final MedicationPlan plan;
  final List<String> ingredients;
}

/// Active medicines that contain an ingredient also found in [hit].
/// This only compares ingredient names; it does not check interactions.
final ingredientOverlapProvider =
    FutureProvider.family<List<IngredientOverlap>, int>((ref, hitId) async {
      final plans = await ref.watch(plansProvider.future);
      final service = await ref.watch(medicineSearchProvider.future);
      final mine = await service.ingredientsOf(hitId);
      if (mine.isEmpty) return const [];
      final out = <IngredientOverlap>[];
      for (final p in plans) {
        final id = p.medicineId;
        if (!p.isActive || id == null) continue;
        final shared = sharedIngredients(mine, await service.ingredientsOf(id));
        if (shared.isNotEmpty) out.add(IngredientOverlap(p, shared));
      }
      return out;
    });
