import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart' show formatLongDate;
import 'package:reindeer/core/utils/reindeer_voice.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/progress/domain/doctor_summary.dart';
import 'package:reindeer/features/progress/presentation/adherence_calendar.dart';
import 'package:reindeer/features/symptoms/data/symptom_repository.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';
import 'package:reindeer/features/today/application/day_providers.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// One-page doctor-visit report and adherence progress.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _days = 7;

  Future<String> _summaryText(
    List<DoseEntry> list,
    List<MedicationPlan> plans,
    DateTime now,
  ) async {
    final readings = <String>[];
    for (final type in MeasureType.values) {
      final m = await ref.read(measurementsProvider(type).future);
      if (m.isNotEmpty) {
        readings.add(
          '${type.label}: ${m.first.display} (${formatLongDate(m.first.at)})',
        );
      }
    }
    final conditions = await ref.read(profileConditionsProvider.future);
    final allergies = await ref.read(allergiesProvider.future);
    final symptoms = await ref.read(symptomsProvider.future);
    final since = now.subtract(Duration(days: _days < 30 ? 30 : _days));

    final missRepo = ref.read(missReasonRepositoryProvider);
    final missReasons = await missRepo.summaryBetween(since, now);
    final missNotesRows = await missRepo.notesBetween(since, now);
    final missNotes = [
      for (final n in missNotesRows)
        '${n.doseDate} (${n.slot.name}): ${n.reason.label}${n.note != null ? " - ${n.note}" : ""}',
    ];

    final planRepo = ref.read(planRepositoryProvider);
    final changes = <String>[];
    for (final p in plans) {
      if (p.id != null) {
        final versions = await planRepo.versionsFor(p.id!);
        for (final v in versions) {
          if (v.effectiveFrom.isAfter(since)) {
            changes.add(
              '${p.name}: adjusted on ${formatLongDate(v.effectiveFrom)}${v.changeReason != null ? " (${v.changeReason})" : ""}',
            );
          }
        }
      }
    }

    return inEnglish(
      () => buildDoctorSummary(
        plans: plans,
        summary: AdherenceSummary.from(list, now),
        days: _days,
        now: now,
        readings: readings,
        conditions: conditions,
        allergies: allergies,
        symptoms: symptomSummaryLines([
          for (final e in symptoms)
            if (e.at.isAfter(since)) e,
        ]),
        missReasons: missReasons,
        missNotes: missNotes,
        prescriptionChanges: changes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(recentEntriesProvider(_days));
    final entries30 = ref.watch(recentEntriesProvider(30)).value ?? const [];
    final plans = ref.watch(plansProvider).value ?? const [];
    final symptoms = ref.watch(symptomsProvider).value ?? const [];
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final since = now.subtract(Duration(days: _days));
    final missSummary = ref.watch(
      missReasonsSummaryProvider((from: since, to: now)),
    );
    final missNotes = ref.watch(
      missNotesBetweenProvider((from: since, to: now)),
    );
    final t = context.textTheme;
    final scheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Reports')),
        actions: [
          PopupMenuButton<String>(
            tooltip: tr('Summary for my doctor'),
            icon: const Icon(Icons.share_outlined),
            onSelected: (choice) async {
              final list = entries.value;
              if (list == null) return;
              final text = await _summaryText(list, plans, now);
              if (choice == 'share') {
                final ok = await SystemChannel.shareText(
                  text,
                  title: tr('Summary for my doctor'),
                );
                if (!ok && context.mounted) {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    context.showSnackBar(
                      tr('Sharing is not available. Summary copied instead.'),
                    );
                  }
                }
              } else {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  context.showSnackBar(
                    tr('Summary copied. Paste it into a message or note.'),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'share',
                child: Text(tr('Share (WhatsApp, email...)')),
              ),
              PopupMenuItem(value: 'copy', child: Text(tr('Copy text'))),
            ],
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Something went wrong'),
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
              // Clinical disclaimer
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('Self-recorded, not verified intake'),
                          style: t.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 7, label: Text(tr('7 days'))),
                  ButtonSegment(value: 30, label: Text(tr('30 days'))),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              if (resolved == 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateView(
                    title: tr('Nothing to show yet'),
                    message: tr(
                      'Once doses are due, your progress appears here.',
                    ),
                    icon: Icons.insights_outlined,
                  ),
                )
              else ...[
                // Adherence card
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: summary.overall ?? 0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            '${(v * 100).round()}%',
                            style: t.displayLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('of doses taken'), style: t.titleMedium),
                              Text(
                                trf('{a} taken · {b} missed · {c} skipped', {
                                  'a': '${summary.taken}',
                                  'b': '${summary.missed}',
                                  'c': '${summary.skipped}',
                                }),
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
                      color: scheme.primaryContainer,
                      child: ListTile(
                        leading: const ReindeerMark(
                          size: 40,
                          interactive: true,
                        ),
                        title: Text(
                          ReindeerVoice.perfectRun,
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
                  ),
                if (summary.observation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Card(
                      color: scheme.tertiaryContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.lightbulb_outline,
                          color: scheme.onTertiaryContainer,
                        ),
                        title: Text(
                          summary.observation!,
                          style: TextStyle(color: scheme.onTertiaryContainer),
                        ),
                      ),
                    ),
                  ),

                // 30-Day Adherence Calendar
                if (_days == 30 && entries30.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdherenceCalendar30Days(
                    entries: entries30,
                    now: now,
                    symptoms: symptoms,
                    onSelectDay: (day) {
                      ref.read(selectedDayProvider.notifier).select(day);
                      context.go(AppRoutes.today);
                    },
                  ),
                ],

                // Missed reasons breakdown
                missSummary.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (reasons) {
                    if (reasons.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        SectionTitle(tr('Missed dose reasons breakdown')),
                        Card(
                          child: Padding(
                            padding: AppSpacing.cardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final r in reasons.entries) ...[
                                  Row(
                                    children: [
                                      Text(
                                        r.key.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          r.key.label,
                                          style: t.bodyMedium,
                                        ),
                                      ),
                                      Text(
                                        trn(r.value, '{n} time', '{n} times'),
                                        style: t.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (r.key != reasons.keys.last)
                                    const Divider(height: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Patient notes for missed doses
                missNotes.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (notes) {
                    if (notes.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        SectionTitle(tr('Notes for doctor on missed doses')),
                        Card(
                          child: Column(
                            children: [
                              for (final n in notes)
                                ListTile(
                                  dense: true,
                                  leading: Text(
                                    n.reason.emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  title: Text(n.note ?? n.reason.label),
                                  subtitle: Text(
                                    '${n.doseDate} (${n.slot.label})',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Per-medicine adherence
                if (plans.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SectionTitle(tr('By medicine')),
                  for (final p in plans.where((p) => p.isActive))
                    Builder(
                      builder: (context) {
                        final pEntries = [
                          for (final e in list)
                            if (e.plan.id == p.id) e,
                        ];
                        final pSummary = AdherenceSummary.from(pEntries, now);
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              trf('{a} of {b} taken', {
                                'a': '${pSummary.taken}',
                                'b':
                                    '${pSummary.taken + pSummary.missed + pSummary.skipped}',
                              }),
                            ),
                            trailing: Text(
                              pSummary.overall == null
                                  ? '--'
                                  : '${(pSummary.overall! * 100).round()}%',
                              style: t.titleMedium?.copyWith(
                                color: (pSummary.overall ?? 0) >= 0.8
                                    ? scheme.primary
                                    : scheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],

                const SizedBox(height: AppSpacing.md),
                SectionTitle(tr('Health')),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.monitor_heart, color: scheme.primary),
                    title: Text(tr('Vitals & Readings')),
                    subtitle: Text(
                      tr('Blood Pressure, Blood Sugar, Weight trends'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.health),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () async {
                    final list = entries.value;
                    if (list == null) return;
                    final text = await _summaryText(list, plans, now);
                    final ok = await SystemChannel.shareText(
                      text,
                      title: tr('Summary for my doctor'),
                    );
                    if (!ok && context.mounted) {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        context.showSnackBar(
                          tr(
                            'Sharing is not available. Summary copied instead.',
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: Text(tr('Share report with doctor')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
