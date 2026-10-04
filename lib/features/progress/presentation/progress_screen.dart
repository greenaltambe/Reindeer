import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/progress/domain/doctor_summary.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/core/utils/date_time_utils.dart' show formatLongDate;
import 'package:reindeer/core/utils/reindeer_voice.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// How well doses were taken over the last 7 or 30 days.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(recentEntriesProvider(_days));
    final plans = ref.watch(plansProvider).value ?? const [];
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final t = context.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Copy a summary for my doctor',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final list = entries.value;
              if (list == null) return;
              final readings = <String>[];
              for (final type in MeasureType.values) {
                final m = await ref.read(measurementsProvider(type).future);
                if (m.isNotEmpty) {
                  readings.add(
                    '${type.label}: ${m.first.display} (${formatLongDate(m.first.at)})',
                  );
                }
              }
              final conditions = await ref.read(
                profileConditionsProvider.future,
              );
              final text = buildDoctorSummary(
                plans: plans,
                summary: AdherenceSummary.from(list, now),
                days: _days,
                now: now,
                readings: readings,
                conditions: conditions,
              );
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                context.showSnackBar(
                  'Summary copied. Paste it into a message or note.',
                );
              }
            },
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: 'Something went wrong',
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (list) {
          final summary = AdherenceSummary.from(list, now);
          final resolved = summary.taken + summary.skipped + summary.missed;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              if (resolved == 0)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateView(
                    title: 'Nothing to show yet',
                    message: 'Once doses are due, your progress appears here.',
                    icon: Icons.insights_outlined,
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        Text(
                          '${((summary.overall ?? 0) * 100).round()}%',
                          style: t.displayLarge,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('of doses taken', style: t.titleMedium),
                              Text(
                                '${summary.taken} taken · ${summary.missed} missed · ${summary.skipped} skipped',
                                style: t.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (summary.missed == 0 &&
                    summary.skipped == 0 &&
                    summary.taken >= 7)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Card(
                      color: context.colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const ReindeerMark(
                          size: 40,
                          interactive: true,
                        ),
                        title: Text(
                          ReindeerVoice.perfectRun,
                          style: TextStyle(
                            color: context.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (summary.observation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Card(
                      color: context.colorScheme.tertiaryContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.lightbulb_outline,
                          color: context.colorScheme.onTertiaryContainer,
                        ),
                        title: Text(
                          summary.observation!,
                          style: TextStyle(
                            color: context.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SectionTitle('By medicine'),
                for (final p in plans)
                  if (summary.byPlan.containsKey(p.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Card(
                        child: Padding(
                          padding: AppSpacing.cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(p.name, style: t.titleMedium),
                                  ),
                                  Text(
                                    summary.byPlan[p.id] == null
                                        ? '-'
                                        : '${(summary.byPlan[p.id]! * 100).round()}%',
                                    style: t.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: summary.byPlan[p.id] ?? 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Missed = not marked within 2 hours.',
                  style: t.bodyMedium,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
