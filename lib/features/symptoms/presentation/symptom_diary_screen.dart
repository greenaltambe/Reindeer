import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/symptoms/application/symptom_links.dart';
import 'package:reindeer/features/symptoms/data/symptom_repository.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';
import 'package:reindeer/features/symptoms/domain/symptom_catalog.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/core/i18n/strings.dart';

IconData _iconFor(String symptom) {
  final cat = symptomInfoFor(symptom)?.category;
  return switch (cat) {
    SymptomCategory.head => Icons.psychology_outlined,
    SymptomCategory.stomach => Icons.lunch_dining_outlined,
    SymptomCategory.chest => Icons.air,
    SymptomCategory.skin => Icons.healing_outlined,
    SymptomCategory.body => Icons.accessibility_new,
    SymptomCategory.mouth => Icons.visibility_outlined,
    SymptomCategory.urine => Icons.water_drop_outlined,
    null => Icons.sentiment_dissatisfied_outlined,
  };
}

Color _severityColor(ColorScheme s, Severity v) => switch (v) {
  Severity.mild => s.primary,
  Severity.moderate => s.tertiary,
  Severity.severe => s.error,
};

/// A short diary of how the person felt, shown to the doctor later.
class SymptomDiaryScreen extends ConsumerWidget {
  const SymptomDiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(symptomsProvider);
    final t = context.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('How I feel'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLogSymptomSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Log a symptom')),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Something went wrong'),
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              title: tr('Nothing logged yet'),
              message: tr(
                'Note a headache, dizziness or a rash when it happens. Your doctor will see it next to your medicines.',
              ),
              icon: Icons.sentiment_satisfied_outlined,
              actionLabel: tr('Log a symptom'),
              onAction: () => showLogSymptomSheet(context),
            );
          }
          final now = DateTime.now();
          final week = [
            for (final e in list)
              if (now.difference(e.at).inDays < 7) e,
          ];
          final counts = <String, int>{};
          for (final e in week) {
            counts[e.symptom] = (counts[e.symptom] ?? 0) + 1;
          }
          final top = counts.entries.isEmpty
              ? null
              : (counts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .first;

          // Group by day, newest first (the list already is).
          final days = <DateTime, List<SymptomEntry>>{};
          for (final e in list) {
            days.putIfAbsent(dateOnly(e.at), () => []).add(e);
          }

          var index = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              96,
            ),
            children: [
              FadeSlideIn(
                child: Card(
                  color: context.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.insights_outlined,
                      color: context.colorScheme.onSecondaryContainer,
                    ),
                    title: Text(
                      week.isEmpty
                          ? tr('Nothing logged this week')
                          : trn(
                              week.length,
                              '{n} entry this week',
                              '{n} entries this week',
                            ),
                      style: t.titleMedium?.copyWith(
                        color: context.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    subtitle: top == null
                        ? null
                        : Text(
                            trf('Most often: {n}', {'n': tr(top.key)}) +
                                (top.value > 1
                                    ? trf(' ({n} times)', {'n': '${top.value}'})
                                    : ''),
                            style: TextStyle(
                              color: context.colorScheme.onSecondaryContainer,
                            ),
                          ),
                  ),
                ),
              ),
              for (final day in days.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    formatDayLabel(day.key, now),
                    style: t.titleSmall,
                  ),
                ),
                for (final e in day.value)
                  FadeSlideIn(
                    key: ValueKey('sym${e.id}'),
                    index: index++ < 8 ? index : 0,
                    child: _EntryCard(entry: e),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr(
                  'A symptom that shows up soon after starting a medicine is worth telling your doctor. It does not mean the medicine caused it.',
                ),
                style: t.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});

  final SymptomEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final active = (ref.watch(plansProvider).value ?? const [])
        .where((p) => p.isActive)
        .toList();
    final recent = recentlyStarted(active, entry.at);
    final links =
        ref.watch(symptomLinksProvider(entry.symptom)).value ??
        const <String>[];
    final color = _severityColor(scheme, entry.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.xxs,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(_iconFor(entry.symptom), color: color),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(entry.symptom), style: t.titleMedium),
                            Text(
                              '${tr(entry.severity.label)} · ${formatTime(entry.at)}',
                              style: t.bodyMedium?.copyWith(color: color),
                            ),
                            if ((entry.note ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xxs,
                                ),
                                child: Text(entry.note!, style: t.bodyMedium),
                              ),
                            if (links.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.link,
                                      size: 18,
                                      color: scheme.tertiary,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        trf('Listed side effect of {n}', {
                                          'n': links.join(', '),
                                        }),
                                        style: t.bodySmall?.copyWith(
                                          color: scheme.tertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (recent.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xxs,
                                ),
                                child: Text(
                                  trf('Recently started: {n}', {
                                    'n': recent.map((p) => p.name).join(', '),
                                  }),
                                  style: t.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Delete'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref
                              .read(symptomRepositoryProvider)
                              .delete(entry.id!);
                          ref.read(dataVersionProvider.notifier).bump();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to log one symptom.
Future<void> showLogSymptomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LogSymptomSheet(),
  );
}

class _LogSymptomSheet extends ConsumerStatefulWidget {
  const _LogSymptomSheet();

  @override
  ConsumerState<_LogSymptomSheet> createState() => _LogSymptomSheetState();
}

class _LogSymptomSheetState extends ConsumerState<_LogSymptomSheet> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  String? _symptom;
  Severity _severity = Severity.mild;
  bool _showAll = false;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pick(String name) {
    FocusScope.of(context).unfocus();
    setState(() {
      _symptom = name;
      _search.clear();
    });
  }

  Future<void> _save() async {
    final chosen = _symptom;
    if (chosen == null || chosen.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(symptomRepositoryProvider)
          .add(
            SymptomEntry(
              symptom: chosen,
              severity: _severity,
              note: _note.text,
              at: DateTime.now(),
            ),
          );
      ref.read(dataVersionProvider.notifier).bump();
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnackBar(tr('Saved. You can show this to your doctor.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar(
        trf('Could not save: {n}', {'n': '$e'}),
        isError: true,
      );
    }
  }

  Widget _chips(List<SymptomInfo> items) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final s in items)
        ActionChip(
          avatar: Icon(_iconFor(s.name), size: 18),
          label: Text(tr(s.name)),
          onPressed: () => _pick(s.name),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final query = _search.text.trim();
    final matches = searchSymptoms(query);
    final chosen = _symptom;
    final links = chosen == null
        ? const <String>[]
        : ref.watch(symptomLinksProvider(chosen)).value ?? const <String>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('How are you feeling?'), style: t.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                if (chosen == null) ...[
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: tr('Search: headache, bukhar, ulti...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        _pick(
                          matches.isNotEmpty ? matches.first.name : v.trim(),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (query.isNotEmpty) ...[
                    _chips(matches),
                    const SizedBox(height: AppSpacing.xs),
                    ActionChip(
                      avatar: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(trf('Use "{n}"', {'n': query})),
                      onPressed: () => _pick(query),
                    ),
                  ] else ...[
                    _chips([
                      for (final s in symptomCatalog)
                        if (s.common) s,
                    ]),
                    TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(
                        _showAll ? tr('Show fewer') : tr('Show all symptoms'),
                      ),
                    ),
                    if (_showAll)
                      for (final c in SymptomCategory.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xxs,
                          ),
                          child: Text(tr(c.label), style: t.titleSmall),
                        ),
                        _chips([
                          for (final s in symptomCatalog)
                            if (s.category == c) s,
                        ]),
                      ],
                  ],
                ] else ...[
                  Row(
                    children: [
                      Chip(
                        avatar: Icon(_iconFor(chosen), size: 18),
                        label: Text(tr(chosen), style: t.titleMedium),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      TextButton(
                        onPressed: () => setState(() => _symptom = null),
                        child: Text(tr('Change')),
                      ),
                    ],
                  ),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Card(
                      color: scheme.tertiaryContainer,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: AppSpacing.cardPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: scheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                trf(
                                  '{s} is a listed side effect of {m}. If it continues or gets worse, tell your doctor. Do not stop a medicine on your own.',
                                  {'s': tr(chosen), 'm': links.join(', ')},
                                ),
                                style: TextStyle(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(tr('How bad is it?'), style: t.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      for (final s in Severity.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: s == Severity.severe ? 0 : AppSpacing.xs,
                            ),
                            child: _SeverityTile(
                              severity: s,
                              selected: _severity == s,
                              onTap: () => setState(() => _severity = s),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(
                      hintText: tr(
                        'Note (optional), for example "after lunch"',
                      ),
                    ),
                  ),
                  if (_severity == Severity.severe) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      tr(
                        'If this is severe, or you have trouble breathing, swelling of the face or a spreading rash, get medical help now.',
                      ),
                      style: t.bodyMedium?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(tr('Save')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeverityTile extends StatelessWidget {
  const _SeverityTile({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final Severity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = _severityColor(scheme, severity);
    final icon = switch (severity) {
      Severity.mild => Icons.sentiment_satisfied_alt_outlined,
      Severity.moderate => Icons.sentiment_neutral_outlined,
      Severity.severe => Icons.sentiment_very_dissatisfied_outlined,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: tr(severity.label),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            color: selected
                ? color.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                tr(severity.label),
                style: context.textTheme.labelLarge?.copyWith(
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
