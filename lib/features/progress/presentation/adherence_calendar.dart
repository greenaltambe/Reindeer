import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';

enum DayDoseStatus { allTaken, missed, partialOrSkipped, none }

/// Accessible 30-day visual adherence calendar with pattern + color dual encoding
/// and interactive day inspection for doses and health symptoms.
class AdherenceCalendar30Days extends StatelessWidget {
  const AdherenceCalendar30Days({
    super.key,
    required this.entries,
    required this.now,
    this.symptoms = const [],
    this.onSelectDay,
  });

  final List<DoseEntry> entries;
  final DateTime now;
  final List<SymptomEntry> symptoms;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;

    // Group entries by date string 'yyyy-MM-dd'
    final byDate = <String, List<DoseEntry>>{};
    for (final e in entries) {
      final key = isoDate(e.dose.at);
      (byDate[key] ??= []).add(e);
    }

    // Group symptoms by date string
    final symptomsByDate = <String, List<SymptomEntry>>{};
    for (final s in symptoms) {
      final key = isoDate(s.at);
      (symptomsByDate[key] ??= []).add(s);
    }

    // Build the 30 days list ending today
    final days = <DateTime>[];
    for (var i = 29; i >= 0; i--) {
      days.add(now.subtract(Duration(days: i)));
    }

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    tr('Adherence calendar (last 30 days)'),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('Tap any day to see details'),
              style: t.bodySmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Grid of 30 days
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.95,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final d = days[index];
                final key = isoDate(d);
                final dayEntries = byDate[key] ?? const [];
                final daySymptoms = symptomsByDate[key] ?? const [];
                final status = _evaluateDay(dayEntries);
                final dayNum = '${d.day}';
                final isToday = isoDate(d) == isoDate(now);
                final hasSymptoms = daySymptoms.isNotEmpty;

                final (
                  Color bgColor,
                  Color fgColor,
                  String symbol,
                  String desc,
                ) = switch (status) {
                  DayDoseStatus.allTaken => (
                    Colors.green.shade100,
                    Colors.green.shade800,
                    '✓',
                    'All taken',
                  ),
                  DayDoseStatus.missed => (
                    Colors.red.shade100,
                    Colors.red.shade900,
                    '✕',
                    'Missed',
                  ),
                  DayDoseStatus.partialOrSkipped => (
                    Colors.amber.shade100,
                    Colors.amber.shade900,
                    '–',
                    'Skipped or partial',
                  ),
                  DayDoseStatus.none => (
                    scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    scheme.outline,
                    '·',
                    'No doses scheduled',
                  ),
                };

                return Semantics(
                  button: true,
                  label:
                      '${formatLongDate(d)}: $desc${hasSymptoms ? ", Symptoms recorded" : ""}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showDayDetailSheet(
                      context,
                      d,
                      dayEntries,
                      daySymptoms,
                      scheme,
                      t,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: scheme.primary, width: 2)
                            : Border.all(color: fgColor.withValues(alpha: 0.2)),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNum,
                            style: t.labelSmall?.copyWith(
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: fgColor,
                              fontSize: 10,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                symbol,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: fgColor,
                                ),
                              ),
                              if (hasSymptoms) ...[
                                const SizedBox(width: 2),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            // Accessible legend
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendItem(
                  color: Colors.green.shade800,
                  symbol: '✓',
                  label: tr('Taken'),
                ),
                _LegendItem(
                  color: Colors.red.shade900,
                  symbol: '✕',
                  label: tr('Missed'),
                ),
                _LegendItem(
                  color: Colors.amber.shade900,
                  symbol: '–',
                  label: tr('Skipped'),
                ),
                _LegendItem(
                  color: Colors.purple.shade700,
                  symbol: '•',
                  label: tr('Symptom'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDayDetailSheet(
    BuildContext context,
    DateTime day,
    List<DoseEntry> dayEntries,
    List<SymptomEntry> daySymptoms,
    ColorScheme scheme,
    TextTheme t,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatLongDate(day), style: t.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              if (dayEntries.isEmpty && daySymptoms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    tr('Nothing was scheduled or recorded on this day.'),
                    style: t.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                )
              else ...[
                if (dayEntries.isNotEmpty) ...[
                  Text(
                    tr('Medicines'),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final e in dayEntries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            e.status == DoseStatus.taken
                                ? Icons.check_circle
                                : (e.status == DoseStatus.missed
                                      ? Icons.cancel
                                      : Icons.remove_circle_outline),
                            color: e.status == DoseStatus.taken
                                ? Colors.green
                                : (e.status == DoseStatus.missed
                                      ? scheme.error
                                      : Colors.orange),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${e.plan.name} (${e.plan.doseUnit.describe(e.dose.amount)})',
                              style: t.bodyMedium,
                            ),
                          ),
                          Text(
                            formatTime(e.dose.at),
                            style: t.bodySmall?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (daySymptoms.isNotEmpty) ...[
                  Text(
                    tr('Symptoms & Feelings'),
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final s in daySymptoms)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.sentiment_dissatisfied_outlined,
                            size: 18,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.symptom} (${s.severity.label})',
                                  style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (s.note != null && s.note!.trim().isNotEmpty)
                                  Text(
                                    s.note!.trim(),
                                    style: t.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatTime(s.at),
                            style: t.bodySmall?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
              if (onSelectDay != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.today),
                    label: Text(tr('View on Today timeline')),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelectDay!(day);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  DayDoseStatus _evaluateDay(List<DoseEntry> dayEntries) {
    if (dayEntries.isEmpty) return DayDoseStatus.none;

    final resolved = dayEntries
        .where((e) => e.status != DoseStatus.scheduled)
        .toList();
    if (resolved.isEmpty) return DayDoseStatus.none;

    final hasMissed = resolved.any((e) => e.status == DoseStatus.missed);
    if (hasMissed) return DayDoseStatus.missed;

    final allTaken = resolved.every((e) => e.status == DoseStatus.taken);
    if (allTaken) return DayDoseStatus.allTaken;

    return DayDoseStatus.partialOrSkipped;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.symbol,
    required this.label,
  });

  final Color color;
  final String symbol;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: t.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
