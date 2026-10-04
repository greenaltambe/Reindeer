import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';
import 'package:reindeer/features/health/presentation/trend_chart.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';

/// History, trend and reminder for one kind of reading.
class MeasurementDetailScreen extends ConsumerStatefulWidget {
  const MeasurementDetailScreen({super.key, required this.type});

  final MeasureType type;

  @override
  ConsumerState<MeasurementDetailScreen> createState() =>
      _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState
    extends ConsumerState<MeasurementDetailScreen> {
  int _days = 30; // 0 = all

  MeasureType get type => widget.type;

  Future<void> _delete(Measurement m) async {
    await ref.read(measurementRepositoryProvider).delete(m.id!);
    ref.read(dataVersionProvider.notifier).bump();
  }

  Future<void> _setReminder() async {
    final current = ref.read(measureReminderProvider(type)).value;
    final result = await showModalBottomSheet<_ReminderResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderSheet(type: type, current: current),
    );
    if (result == null) return;
    await ref
        .read(settingsRepositoryProvider)
        .set(
          MeasureReminder.settingsKey(type),
          result.reminder?.encode() ?? '',
        );
    ref.read(dataVersionProvider.notifier).bump();
    try {
      if (result.reminder != null) {
        await ref.read(reminderServiceProvider).requestPermissions();
      }
      await ref.read(reminderServiceProvider).rescheduleAll();
    } catch (_) {
      // Saved; reminders can be re-synced on next start.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final all =
        ref.watch(measurementsProvider(type)).value ?? const <Measurement>[];
    final reminder = ref.watch(measureReminderProvider(type)).value;
    final profile = ref.watch(profileProvider).value;
    final now = DateTime.now();
    final since = _days == 0 ? null : now.subtract(Duration(days: _days));
    final inRange = [
      for (final m in all)
        if (since == null || !m.at.isBefore(since)) m,
    ].reversed.toList(); // oldest first
    final s = stats(inRange.map((m) => m.value));
    final s2 = type.hasSecond
        ? stats(inRange.map((m) => m.value2 ?? m.value))
        : null;
    final latestBmi = type == MeasureType.weight && all.isNotEmpty
        ? bmi(all.first.value, profile?.heightCm)
        : null;

    String range(({double min, double avg, double max}) v) =>
        '${type.formatValue(v.min)} to ${type.formatValue(v.max)}';

    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/health/${type.name}/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add reading'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
              ButtonSegment(value: 0, label: Text('All')),
            ],
            selected: {_days},
            onSelectionChanged: (v) => setState(() => _days = v.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: inRange.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(
                        child: Text(
                          'No readings in this period.',
                          style: t.bodyLarge,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrendChart(
                          times: [for (final m in inRange) m.at],
                          values: [for (final m in inRange) m.value],
                          second: type.hasSecond
                              ? [for (final m in inRange) m.value2 ?? m.value]
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (s != null)
                          Text(
                            type.hasSecond && s2 != null
                                ? 'Top ${range(s)} · Bottom ${range(s2)} ${type.unit}'
                                : 'Range ${range(s)} ${type.unit} · average ${type.formatValue(s.avg)}',
                            style: t.bodyMedium,
                          ),
                        if (latestBmi != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              'BMI ${latestBmi.toStringAsFixed(1)}',
                              style: t.bodyMedium,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: ListTile(
              leading: Icon(
                reminder == null
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
              ),
              title: Text(
                reminder == null
                    ? 'Remind me to measure'
                    : _reminderText(reminder),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setReminder,
            ),
          ),
          const SectionTitle('History'),
          if (all.isEmpty)
            Text(type.hint, style: t.bodyLarge)
          else
            for (final m in all.take(60))
              Dismissible(
                key: ValueKey('m${m.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  color: context.colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) => _delete(m),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(type.icon),
                  title: Text(m.display, style: t.titleMedium),
                  subtitle: Text(
                    '${formatDayLabel(m.at, now)}, ${formatTime(m.at)}'
                    '${m.context == null ? '' : ' · ${m.context}'}'
                    '${m.note == null || m.note!.isEmpty ? '' : ' · ${m.note}'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(m),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _reminderText(MeasureReminder r) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final when = r.weekday == null ? 'Every day' : 'Every ${days[r.weekday!]}';
    return '$when at ${formatMinutes(r.minutes)}';
  }
}

class _ReminderResult {
  const _ReminderResult(this.reminder);
  final MeasureReminder? reminder;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.type, required this.current});

  final MeasureType type;
  final MeasureReminder? current;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late int _minutes = widget.current?.minutes ?? 8 * 60;
  late int? _weekday = widget.current?.weekday;

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remind me to measure ${widget.type.label.toLowerCase()}',
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              formatMinutes(_minutes),
              style: context.textTheme.headlineMedium,
            ),
            onTap: () async {
              final p = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _minutes ~/ 60,
                  minute: _minutes % 60,
                ),
              );
              if (p != null) setState(() => _minutes = p.hour * 60 + p.minute);
            },
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('Every day'),
                selected: _weekday == null,
                onSelected: (_) => setState(() => _weekday = null),
              ),
              for (var i = 0; i < 7; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: _weekday == i + 1,
                  onSelected: (_) => setState(() => _weekday = i + 1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (widget.current != null)
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const _ReminderResult(null)),
                  child: const Text('Turn off'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _ReminderResult(
                    MeasureReminder(minutes: _minutes, weekday: _weekday),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
