import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/care/presentation/patient_card.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// Home for people who look after someone: each person's day at a glance.
///
/// It is the whole app for a caretaker-only phone, and one tap from Today for
/// someone who also takes medicines.
class CareHomeScreen extends ConsumerWidget {
  const CareHomeScreen({super.key});

  Future<void> _useForMyMedicines(BuildContext context, WidgetRef ref) async {
    await saveCareMode(ref, CareMode.patient);
    if (context.mounted) context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(myPatientsProvider);
    final mode =
        ref.watch(careModeProvider).value ?? ref.read(initialCareModeProvider);
    final caretakerOnly = mode == CareMode.caretaker;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Family')),
        actions: [
          if (caretakerOnly)
            IconButton(
              tooltip: tr('App settings'),
              onPressed: () => context.push(AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: patients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Could not load'),
          message: tr('Check the internet and try again.'),
          icon: Icons.cloud_off_outlined,
        ),
        data: (list) {
          if (list.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: EmptyStateView(
                    title: tr('Look after someone'),
                    message: tr(
                      'Get an alert when a parent or relative misses a medicine. You will need a code from their phone.',
                    ),
                    illustration: const ReindeerMark(
                      size: 96,
                      interactive: true,
                    ),
                    actionLabel: tr('Enter a code'),
                    onAction: () => context.push(AppRoutes.familyJoin),
                  ),
                ),
                if (caretakerOnly)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextButton(
                      onPressed: () => _useForMyMedicines(context, ref),
                      child: Text(tr('I take medicines too')),
                    ),
                  ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              for (final (i, link) in list.indexed)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: PatientCard(link: link),
                  ),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => context.push(AppRoutes.familyJoin),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(tr('Look after someone else')),
              ),
              if (caretakerOnly) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => _useForMyMedicines(context, ref),
                  child: Text(tr('I take medicines too')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Compact line on Today for people who also look after someone.
class FamilyTodayStrip extends ConsumerWidget {
  const FamilyTodayStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(myPatientsProvider).value ?? const <CareLink>[];
    if (patients.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (final link in patients)
              Consumer(
                builder: (context, ref, _) {
                  final doses =
                      ref
                          .watch(patientDosesTodayProvider(link.patientUid))
                          .value ??
                      const <CareDose>[];
                  final s = daySummary(context, doses, now);
                  return ListTile(
                    leading: Icon(s.icon, color: s.color),
                    title: Text(
                      link.patientLabel,
                      style: context.textTheme.titleMedium,
                    ),
                    subtitle: Text(s.text, style: TextStyle(color: s.color)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.care),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
