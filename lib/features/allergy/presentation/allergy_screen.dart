import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/allergy/application/allergy_suggestions.dart';
import 'package:reindeer/features/allergy/domain/allergy.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// Medicines the person is allergic to. Used to warn before adding a medicine
/// with a matching ingredient.
class AllergyScreen extends ConsumerStatefulWidget {
  const AllergyScreen({super.key});

  @override
  ConsumerState<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends ConsumerState<AllergyScreen> {
  final _search = TextEditingController();
  List<String>? _selected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _has(List<String> list, String label) =>
      list.any((a) => normalizeAllergy(a) == normalizeAllergy(label));

  Future<void> _save(List<String> next) async {
    setState(() => _selected = next);
    await ref.read(profileRepositoryProvider).setAllergies(next);
    ref.read(dataVersionProvider.notifier).bump();
  }

  void _toggle(List<String> current, String label) {
    final next = [...current];
    final i = next.indexWhere(
      (a) => normalizeAllergy(a) == normalizeAllergy(label),
    );
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.add(label);
    }
    _save(next);
  }

  void _addAll(List<String> current, List<String> labels) {
    final next = [...current];
    for (final l in labels) {
      if (!_has(next, l)) next.add(l);
    }
    _search.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
    _save(next);
    context.showSnackBar(trf('Added {n}', {'n': labels.join(', ')}));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final stored = ref.watch(allergiesProvider).value;
    final current = _selected ?? stored ?? const <String>[];
    final query = _search.text.trim();
    final suggestions = query.length >= 2
        ? ref.watch(allergySuggestionsProvider(query))
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Allergies'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            tr(
              'Add the medicines you are allergic to. When you add a medicine with a matching ingredient, you will see a warning first.',
            ),
            style: t.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('Search a medicine, brand or ingredient'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (query.length >= 2) ...[
            const SizedBox(height: AppSpacing.xs),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  if (suggestions == null || suggestions.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: LinearProgressIndicator(),
                    ),
                  for (final s
                      in suggestions?.value ?? const <AllergySuggestion>[])
                    ListTile(
                      dense: true,
                      leading: Icon(
                        s.subtitle == 'Ingredient' ||
                                s.subtitle == 'Medicine group'
                            ? Icons.science_outlined
                            : Icons.medication_outlined,
                      ),
                      title: Text(s.title),
                      subtitle: Text(
                        tr(s.subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _has(current, s.add.first) && s.add.length == 1
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : const Icon(Icons.add_circle_outline),
                      onTap: () => _addAll(current, s.add),
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(trf('Add "{n}" as typed', {'n': query})),
                    onTap: () {
                      final group = groupFor(query);
                      _addAll(current, [group?.label ?? query]);
                    },
                  ),
                ],
              ),
            ),
          ],
          SectionTitle(tr('Your allergies')),
          if (current.isEmpty)
            Text(
              tr('None added yet.'),
              style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in current)
                  InputChip(
                    avatar: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    label: Text(a),
                    backgroundColor: scheme.errorContainer,
                    labelStyle: TextStyle(color: scheme.onErrorContainer),
                    deleteIconColor: scheme.onErrorContainer,
                    onDeleted: () => _toggle(current, a),
                  ),
              ],
            ),
          SectionTitle(tr('Common ones')),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final g in allergyGroups)
                FilterChip(
                  label: Text(g.label),
                  selected: _has(current, g.label),
                  onSelected: (_) => _toggle(current, g.label),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Text(
                tr(
                  'The warning compares ingredient names only. It cannot know every product, so always tell your doctor and pharmacist about your allergies.',
                ),
                style: t.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
