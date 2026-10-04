import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';

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
        () => _error = 'Please check the bottom number. It is usually lower than the top one.',
      );
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(measurementRepositoryProvider)
          .add(
            Measurement(
              type: type,
              value: a,
              value2: b,
              context: _context,
              at: _at,
              note: _note.text.trim(),
            ),
          );
      ref.read(dataVersionProvider.notifier).bump();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
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
      appBar: AppBar(title: Text('Add ${type.label.toLowerCase()}')),
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
              trailing: const Text('Change'),
              onTap: _pickWhen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
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
            child: const Text('Save reading'),
          ),
        ],
      ),
    );
  }
}
