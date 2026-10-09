import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/conditions/data/condition_search_service.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// Pick health conditions: shows chosen ones, quick suggestions, and a search
/// box over the bundled condition list. Anything typed can also be added as-is.
class ConditionPicker extends ConsumerStatefulWidget {
  const ConditionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.suggestions = const [],
    this.suggestionsTitle = 'Suggestions',
    this.single = false,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Quick chips shown above the search (for example the medicine's own uses).
  final List<String> suggestions;
  final String suggestionsTitle;

  /// When true, choosing a condition replaces the previous choice.
  final bool single;

  @override
  ConsumerState<ConditionPicker> createState() => _ConditionPickerState();
}

class _ConditionPickerState extends ConsumerState<ConditionPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _has(String name) =>
      widget.selected.any((s) => s.toLowerCase() == name.toLowerCase());

  void _add(String name) {
    final t = name.trim();
    if (t.isEmpty || _has(t)) return;
    widget.onChanged(widget.single ? [t] : [...widget.selected, t]);
    setState(_controller.clear);
  }

  void _remove(String name) {
    widget.onChanged([
      for (final s in widget.selected)
        if (s.toLowerCase() != name.toLowerCase()) s,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(conditionSearchProvider).value;
    final query = _controller.text.trim();
    final results = service == null || query.isEmpty
        ? const <String>[]
        : service.search(query);
    final popular = service?.popular(limit: 8) ?? const <String>[];
    final suggestions = widget.suggestions.where((s) => !_has(s)).toList();
    final t = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in widget.selected)
                InputChip(label: Text(s), onDeleted: () => _remove(s)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: tr('Search, e.g. bp, sugar, asthma'),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (query.isNotEmpty) ...[
          for (final r in results)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(r),
              trailing: _has(r)
                  ? const Icon(Icons.check)
                  : const Icon(Icons.add),
              onTap: () => _add(r),
            ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(trf('Add "{n}"', {'n': query})),
            onTap: () => _add(query),
          ),
        ] else ...[
          if (suggestions.isNotEmpty) ...[
            Text(tr(widget.suggestionsTitle), style: t.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in suggestions)
                  ActionChip(label: Text(s), onPressed: () => _add(s)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (popular.isNotEmpty) ...[
            Text(tr('Common'), style: t.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in popular.where(
                  (p) => !_has(p) && !suggestions.contains(p),
                ))
                  ActionChip(label: Text(s), onPressed: () => _add(s)),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
