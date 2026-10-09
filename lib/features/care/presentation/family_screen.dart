import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';

/// Who looks after me, and who I look after. Reached from You.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  Future<void> _remove(BuildContext context, CareLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Remove {n}?', {'n': link.caretakerLabel})),
        content: Text(
          trf('{n} will stop getting alerts about your medicines.', {
            'n': link.caretakerLabel,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Remove')),
          ),
        ],
      ),
    );
    if (ok == true) await CareBackend.unlink(link.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final caretakers =
        ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    final patients = ref.watch(myPatientsProvider).value ?? const <CareLink>[];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Family'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          SectionTitle(tr('Who looks after you')),
          if (caretakers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                tr(
                  'Add a son, daughter or friend. They get an alert if you miss a medicine, and you get a Help button to reach them.',
                ),
                style: t.bodyLarge,
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                children: [
                  for (final c in caretakers)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          c.caretakerLabel.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(c.caretakerLabel, style: t.titleMedium),
                      subtitle: Text(
                        tr('Gets an alert if you miss a medicine'),
                      ),
                      trailing: IconButton(
                        tooltip: tr('Remove'),
                        onPressed: () => _remove(context, c),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
              ),
            ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => context.push(AppRoutes.familyAdd),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              caretakers.isEmpty
                  ? tr('Add a caretaker')
                  : tr('Add another caretaker'),
            ),
          ),
          SectionTitle(tr('People you look after')),
          if (patients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                tr(
                  'Looking after a parent? Get an alert on this phone when they miss a medicine.',
                ),
                style: t.bodyLarge,
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                children: [
                  for (final p in patients)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.tertiaryContainer,
                        child: Text(
                          p.patientLabel.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(p.patientLabel, style: t.titleMedium),
                      subtitle: Text(tr('See their day')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.care),
                    ),
                ],
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => context.push(AppRoutes.familyJoin),
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: Text(tr('Look after someone')),
          ),
        ],
      ),
    );
  }
}
