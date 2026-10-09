import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/health/application/measure_reminder_actions.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/domain/reading_insight.dart';
import 'package:reindeer/features/health/presentation/reading_flag_card.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// Add one reading: the number(s), when, and an optional note.
class AddMeasurementScreen extends ConsumerStatefulWidget {
  const AddMeasurementScreen({super.key, required this.type});

  final MeasureType type;

  @override
  ConsumerState<AddMeasurementScreen> createState() =>
      _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();
  final _note = TextEditingController();
  DateTime _at = DateTime.now();
  String? _context;
  String? _error;
  bool _saving = false;
  bool _remind = false;
  int _remindMinutes = 8 * 60;

  MeasureType get type => widget.type;

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t == null) return;
    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() => _at = picked.isAfter(now) ? now : picked);
  }

  Future<void> _save() async {
    final a = double.tryParse(_v1.text.trim());
    final b = type.hasSecond ? double.tryParse(_v2.text.trim()) : null;
    if (a == null || !type.plausible(a)) {
      setState(
        () => _error =
            'Please check the number (${type.formatValue(type.min)} to ${type.formatValue(type.max)}).',
      );
      return;
    }
    if (type.hasSecond && (b == null || !type.plausible(b) || b > a)) {
      setState(
        () => _error = tr(
          'Please check the bottom number. It is usually lower than the top one.',
        ),
      );
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final reading = Measurement(
        type: type,
        value: a,
        value2: b,
        context: _context,
        at: _at,
        note: _note.text.trim(),
      );
      final repo = ref.read(measurementRepositoryProvider);
      // Oldest first, for comparing with the person's own recent readings.
      final earlier = (await repo.forType(type, limit: 12)).reversed.toList();
      await repo.add(reading);
      ref.read(dataVersionProvider.notifier).bump();
      final flag = assessReading(reading, earlier);
      if (_remind) {
        await ref
            .read(measureReminderActionsProvider)
            .set(type, MeasureReminder(minutes: _remindMinutes));
      }
      if (flag != null && mounted) await showReadingFlag(context, flag);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = trf('Could not save: {n}', {'n': '$e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final decimal = type.decimals > 0;
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, suffixText: type.unit);
    final formatters = [
      FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(trf('Add {n}', {'n': type.label.toLowerCase()})),
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
              Icon(type.icon, size: 32, color: context.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(type.hint, style: t.bodyLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _v1,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: formatters,
            style: t.headlineMedium,
            decoration: deco(type.firstLabel),
          ),
          if (type.hasSecond) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _v2,
              keyboardType: TextInputType.number,
              inputFormatters: formatters,
              style: t.headlineMedium,
              decoration: deco(type.secondLabel),
            ),
          ],
          if (type.contexts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final c in type.contexts)
                  ChoiceChip(
                    label: Text(c),
                    selected: _context == c,
                    onSelected: (v) => setState(() => _context = v ? c : null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(
                '${formatDayLabel(_at, DateTime.now())}, ${formatTime(_at)}',
              ),
              trailing: Text(tr('Change')),
              onTap: _pickWhen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: tr('Note (optional)')),
          ),
          Builder(
            builder: (context) {
              final existing = ref.watch(measureReminderProvider(type));
              // Only offer a reminder when none is set yet.
              if (!existing.hasValue || existing.value != null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: Text(tr('Remind me every day')),
                        subtitle: Text(
                          trf('To check your {n}', {
                            'n': type.label.toLowerCase(),
                          }),
                        ),
                        value: _remind,
                        onChanged: (v) => setState(() => _remind = v),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: _remind
                            ? ListTile(
                                leading: const Icon(Icons.schedule),
                                title: Text(formatMinutes(_remindMinutes)),
                                trailing: Text(tr('Change')),
                                onTap: () async {
                                  final p = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: _remindMinutes ~/ 60,
                                      minute: _remindMinutes % 60,
                                    ),
                                  );
                                  if (p != null) {
                                    setState(
                                      () => _remindMinutes =
                                          p.hour * 60 + p.minute,
                                    );
                                  }
                                },
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                _error!,
                style: t.bodyLarge?.copyWith(color: context.colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: _saving ? null : _save,
            child: Text(tr('Save reading')),
          ),
        ],
      ),
    );
  }
}
