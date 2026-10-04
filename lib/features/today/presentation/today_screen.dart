import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/core/utils/reindeer_voice.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/features/adherence/application/dose_actions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';

/// The main screen: what to take now, today's doses, and quick status.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final plans = ref.watch(plansProvider);
    final today = ref.watch(todayEntriesProvider);
    final upcoming = ref.watch(upcomingEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today'),
            Text(formatLongDate(now), style: context.textTheme.bodyMedium),
          ],
        ),
        toolbarHeight: 68,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.add),
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: 'Something went wrong',
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (all) {
          if (all.isEmpty) {
            return EmptyStateView(
              title: 'No medicines yet',
              message:
                  '${ReindeerVoice.nothingYet} Add your first medicine and we will remind you when it is time.',
              illustration: const ReindeerMark(size: 96, interactive: true),
              actionLabel: 'Add medicine',
              onAction: () => context.push(AppRoutes.add),
            );
          }
          final entries = today.value ?? const <DoseEntry>[];
          final next = _nextDose(upcoming.value ?? const <DoseEntry>[]);
          final low = all.where((p) => p.isLowStock).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              96,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  ReindeerVoice.greeting(now),
                  style: context.textTheme.bodyLarge,
                ),
              ),
              if (next != null) _NextDoseCard(entry: next, now: now),
              if (next == null && entries.isNotEmpty) const _AllDoneCard(),
              for (final p in low.take(1))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _LowStockBanner(
                    name: p.name,
                    daysLeft: p.daysOfStockLeft,
                    onTap: () => context.go(AppRoutes.medicines),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text("Today's doses", style: context.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Nothing due today.',
                    style: context.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _DoseTile(entry: e, now: now),
                  ),
            ],
          );
        },
      ),
    );
  }

  /// The earliest dose that is overdue or still ahead.
  DoseEntry? _nextDose(List<DoseEntry> entries) {
    for (final e in entries) {
      if (e.isOpen) return e;
    }
    return null;
  }
}

class _NextDoseCard extends ConsumerWidget {
  const _NextDoseCard({required this.entry, required this.now});

  final DoseEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final plan = entry.plan;
    final overdue = entry.status == DoseStatus.missed;
    final minutes = entry.dose.at.difference(now).inMinutes;
    final when = overdue
        ? 'Was due at ${formatTime(entry.dose.at)}'
        : '${formatDayLabel(entry.dose.at, now)} at ${formatTime(entry.dose.at)}'
              '${minutes >= 0 && minutes < 90 ? ' · in ${_duration(minutes)}' : ''}';
    final timing = plan.mealTiming == MealTiming.anytime
        ? ''
        : ' · ${plan.mealTiming.label.toLowerCase()}';
    final actions = ref.read(doseActionsProvider);

    return Card(
      color: overdue ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              overdue ? 'OVERDUE' : 'NEXT DOSE',
              style: context.textTheme.labelLarge?.copyWith(
                color: overdue
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              plan.name,
              style: context.textTheme.headlineMedium?.copyWith(
                color: overdue
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${plan.doseUnit.describe(entry.dose.amount)}$timing',
              style: context.textTheme.titleMedium?.copyWith(
                color: overdue
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
            Text(
              when,
              style: context.textTheme.bodyLarge?.copyWith(
                color: overdue
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => actions.take(entry.dose),
                    icon: const Icon(Icons.check),
                    label: const Text('Taken'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => actions.skip(entry.dose),
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}

class _DoseTile extends ConsumerWidget {
  const _DoseTile({required this.entry, required this.now});

  final DoseEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final plan = entry.plan;
    final actions = ref.read(doseActionsProvider);
    final timing = plan.mealTiming == MealTiming.anytime
        ? ''
        : ' · ${plan.mealTiming.label.toLowerCase()}';

    final (IconData icon, Color color, String label) = switch (entry.status) {
      DoseStatus.taken => (Icons.check_circle, scheme.primary, 'Taken'),
      DoseStatus.skipped => (
        Icons.remove_circle_outline,
        scheme.outline,
        'Skipped',
      ),
      DoseStatus.missed => (Icons.error_outline, scheme.error, 'Missed'),
      _ => (Icons.schedule, scheme.onSurfaceVariant, 'Upcoming'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: context.textTheme.titleMedium),
                  Text(
                    '${formatTime(entry.dose.at)} · ${plan.doseUnit.describe(entry.dose.amount)}$timing',
                    style: context.textTheme.bodyMedium,
                  ),
                  if (entry.status == DoseStatus.missed ||
                      entry.status == DoseStatus.skipped)
                    Text(
                      label,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
            if (entry.isOpen)
              FilledButton.tonal(
                onPressed: () => actions.take(entry.dose),
                child: const Text('Taken'),
              )
            else
              TextButton(
                onPressed: () => actions.undo(entry.dose),
                child: const Text('Undo'),
              ),
            if (entry.isOpen)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (_) => actions.skip(entry.dose),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'skip', child: Text('Skip this dose')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({
    required this.name,
    required this.daysLeft,
    required this.onTap,
  });

  final String name;
  final double? daysLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final left = daysLeft;
    final text = left == null
        ? '$name is running low.'
        : left < 1
        ? '$name will run out today.'
        : '$name: about ${left.floor()} day${left.floor() == 1 ? '' : 's'} left.';
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.inventory_2_outlined,
          color: scheme.onTertiaryContainer,
        ),
        title: Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
        onTap: onTap,
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.primaryContainer,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            const ReindeerMark(size: 56, interactive: true),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                ReindeerVoice.allDone,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
