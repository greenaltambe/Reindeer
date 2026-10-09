import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/safety/domain/medical_id.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// One large, readable page with allergies, conditions and current medicines,
/// for an emergency or a visit to a new doctor.
class MedicalIdScreen extends ConsumerWidget {
  const MedicalIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final profile = ref.watch(profileProvider).value;
    final allergies = ref.watch(allergiesProvider).value ?? const <String>[];
    final conditions =
        ref.watch(profileConditionsProvider).value ?? const <String>[];
    final plans = ref.watch(plansProvider).value ?? const [];
    final active = plans.where((p) => p.isActive).toList();
    final name = profile?.name ?? '';
    final age = profile?.ageAt(DateTime.now());

    String text() => inEnglish(
      () => buildMedicalIdText(
        name: name,
        age: age,
        allergies: allergies,
        conditions: conditions,
        plans: plans,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Medical ID')),
        actions: [
          IconButton(
            tooltip: tr('Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                SystemChannel.shareText(text(), title: tr('Share Medical ID')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.badge_outlined,
                  size: 30,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? tr('My Medical ID') : name,
                      style: t.headlineMedium,
                    ),
                    if (age != null)
                      Text(trf('Age {n}', {'n': '$age'}), style: t.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            color: allergies.isEmpty ? null : scheme.errorContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    allergies.isEmpty
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: allergies.isEmpty ? null : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allergies.isEmpty
                              ? tr('No allergies noted')
                              : tr('ALLERGIC TO'),
                          style: t.labelLarge?.copyWith(
                            color: allergies.isEmpty
                                ? null
                                : scheme.onErrorContainer,
                            letterSpacing: 1,
                          ),
                        ),
                        for (final a in allergies)
                          Text(
                            a,
                            style: t.headlineSmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(tr('Health conditions')),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: conditions.isEmpty
                  ? Text(tr('None noted'), style: t.titleMedium)
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final c in conditions) Chip(label: Text(c)),
                      ],
                    ),
            ),
          ),
          SectionTitle(tr('Medicines I take')),
          Card(
            margin: EdgeInsets.zero,
            child: active.isEmpty
                ? Padding(
                    padding: AppSpacing.cardPadding,
                    child: Text(tr('None'), style: t.titleMedium),
                  )
                : Column(
                    children: [
                      for (final (i, p) in active.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.medication_outlined),
                          title: Text(p.name, style: t.titleMedium),
                          subtitle: Text(
                            [
                              if (p.composition.trim().isNotEmpty)
                                p.composition.trim(),
                              p.patternLabel,
                            ].join(' · '),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () =>
                SystemChannel.shareText(text(), title: tr('Share Medical ID')),
            icon: const Icon(Icons.share_outlined),
            label: Text(tr('Share this page')),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'Entered by you in Reindeer. Keep it up to date; it is not a medical record.',
            ),
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}
