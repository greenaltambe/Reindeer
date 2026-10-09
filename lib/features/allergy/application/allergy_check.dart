import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/features/allergy/domain/allergy.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';

/// Allergies triggered by a medicine: [id] is its id in the medicine database
/// (null for a medicine the person typed in), [text] its name and composition.
final allergyCheckProvider =
    FutureProvider.family<List<AllergyMatch>, ({int? id, String text})>((
      ref,
      q,
    ) async {
      final allergies = await ref.watch(allergiesProvider.future);
      if (allergies.isEmpty) return const [];
      var key = '';
      final id = q.id;
      if (id != null) {
        final service = await ref.watch(medicineSearchProvider.future);
        key = await service.ingredientsOf(id);
      }
      return findAllergyMatches(
        allergies: allergies,
        ingredientKey: key,
        text: q.text,
      );
    });
