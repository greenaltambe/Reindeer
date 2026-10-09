import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/features/allergy/domain/allergy.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/ingredients.dart';

/// One thing the person can pick while typing an allergy.
class AllergySuggestion {
  const AllergySuggestion({
    required this.title,
    required this.subtitle,
    required this.add,
  });

  final String title;
  final String subtitle;

  /// What to record as allergies when picked.
  final List<String> add;
}

String _cap(String w) =>
    w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';

/// Suggestions for what the person typed: allergy groups, ingredient names from
/// the medicine database, and brands (which add their ingredients).
final allergySuggestionsProvider = FutureProvider.autoDispose
    .family<List<AllergySuggestion>, String>((ref, query) async {
      final q = normalizeAllergy(query);
      if (q.length < 2) return const [];
      final out = <AllergySuggestion>[];

      for (final g in allergyGroups) {
        final label = g.label.toLowerCase();
        if (label.contains(q) || g.aliases.any((a) => a.startsWith(q))) {
          out.add(
            AllergySuggestion(
              title: g.label,
              subtitle: 'Medicine group',
              add: [g.label],
            ),
          );
        }
      }

      final service = await ref.watch(medicineSearchProvider.future);
      for (final w in service.suggestIngredients(q)) {
        out.add(
          AllergySuggestion(
            title: _cap(w),
            subtitle: 'Ingredient',
            add: [_cap(w)],
          ),
        );
      }

      final hits = await service.search(q, asYouType: true);
      final seen = <String>{};
      for (final h in hits.take(12)) {
        if (out.length >= 14) break;
        final key = await service.ingredientsOf(h.id);
        final words = [
          for (final w in key.split(' '))
            if (w.length >= 4 && !weakIngredientWords.contains(w)) _cap(w),
        ];
        if (words.isEmpty || !seen.add(words.join())) continue;
        out.add(
          AllergySuggestion(
            title: h.name,
            subtitle: 'Contains ${words.join(', ')}',
            add: words,
          ),
        );
      }
      return out;
    });
