import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/barcode/data/barcode_link_repository.dart';
import 'package:reindeer/features/conditions/presentation/condition_picker.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';

/// Adding a medicine, one question per page:
/// (name) > how often > how much > food > how long > what for > stock > review.
class AddDetailsScreen extends ConsumerStatefulWidget {
  const AddDetailsScreen({super.key, required this.draft});

  final AddDraft draft;

  @override
  ConsumerState<AddDetailsScreen> createState() => _AddDetailsScreenState();
}

class _Preset {
  const _Preset(this.label, this.pattern, this.slots);

  final String label;
  final String pattern;
  final List<DaySlot> slots;
}

const _presets = <_Preset>[
  _Preset('Once a day', 'Morning', [DaySlot.morning]),
  _Preset('Twice a day', 'Morning + Night', [DaySlot.morning, DaySlot.night]),
  _Preset('Three times', 'Morning, Afternoon, Night', [
    DaySlot.morning,
    DaySlot.afternoon,
    DaySlot.night,
  ]),
  _Preset('Night only', 'Bedtime', [DaySlot.night]),
];

enum _Step { name, often, amount, food, duration, reason, stock, review }

class _AddDetailsScreenState extends ConsumerState<AddDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _composition;
  late final TextEditingController _stock;
  late final List<_Step> _steps;

  late DoseUnit _unit;
  final Map<DaySlot, double> _amounts = {for (final s in DaySlot.values) s: 0};
  int? _presetIndex = 0;
  MealTiming _timing = MealTiming.afterFood;
  int? _courseDays; // null = ongoing
  List<String> _reasons = [];
  int _warnDays = 5;
  int _index = 0;
  bool _saving = false;

  MedicineHit? get _hit => widget.draft.hit;
  _Step get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    final hit = _hit;
    _steps = [if (hit == null) _Step.name, ..._Step.values.skip(1)];
    _name = TextEditingController(text: widget.draft.customName);
    _composition = TextEditingController();
    _stock = TextEditingController(
      text: hit?.packQty == null ? '' : formatAmount(hit!.packQty!),
    );
    _unit = DoseUnit.fromForm(hit?.form);
    for (final s in DaySlot.values) {
      _amounts[s] = _presets[0].slots.contains(s) ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _composition.dispose();
    _stock.dispose();
    super.dispose();
  }

  String get _medicineName => _hit?.name ?? _name.text.trim();

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _presetIndex = index;
      for (final s in DaySlot.values) {
        _amounts[s] = preset.slots.contains(s) ? 1 : 0;
      }
    });
  }

  void _bump(DaySlot slot, int direction) {
    final next = (_amounts[slot]! + direction * _unit.step)
        .clamp(0, 20)
        .toDouble();
    setState(() {
      _amounts[slot] = next;
      _presetIndex = null;
    });
  }

  bool get _canContinue => switch (_step) {
    _Step.name => _name.text.trim().isNotEmpty,
    _Step.amount => _amounts.values.any((a) => a > 0),
    _ => true,
  };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_index < _steps.length - 1) setState(() => _index++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_index > 0) {
      setState(() => _index--);
    } else {
      context.pop();
    }
  }

  void _jump(_Step step) => setState(() => _index = _steps.indexOf(step));

  Future<void> _save() async {
    final name = _medicineName;
    if (name.isEmpty || _amounts.values.every((a) => a <= 0)) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final today = dateOnly(now);
    final hit = _hit;
    final stock = double.tryParse(_stock.text.trim());
    final daily = _amounts.values.fold<double>(0, (a, b) => a + b);
    final plan = MedicationPlan(
      profileId: AppDatabase.defaultProfileId,
      medicineId: hit?.id,
      name: name,
      composition: hit != null ? hit.composition : _composition.text.trim(),
      kind: hit?.kind ?? MedicineKind.custom,
      condition: _reasons.isEmpty ? null : _reasons.join(', '),
      doseUnit: _unit,
      slotAmounts: Map.of(_amounts),
      mealTiming: _timing,
      startDate: today,
      endDate: _courseDays == null
          ? null
          : DateTime(today.year, today.month, today.day + _courseDays! - 1),
      stock: stock,
      lowStockThreshold: stock == null ? null : _warnDays * daily,
      packQty: hit?.packQty,
      createdAt: now,
    );
    try {
      await ref.read(planActionsProvider).add(plan);
      final barcode = widget.draft.barcode;
      if (barcode != null && hit != null) {
        await ref.read(barcodeLinkRepositoryProvider).link(barcode, hit.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar('Could not save: $e');
      return;
    }
    if (!mounted) return;
    context.go(AppRoutes.medicines);
    context.showSnackBar('$name added');
  }

  String get _timingCaption => switch (_timing) {
    MealTiming.beforeFood => '30 min before the meal',
    MealTiming.afterFood => '30 min after the meal',
    MealTiming.withFood => 'at the meal',
    MealTiming.anytime => 'at meal time',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final n = _steps.length;
    final hit = _hit;
    final label = _medicineName.isEmpty ? 'this medicine' : _medicineName;

    Widget scaffold({
      required String title,
      String? subtitle,
      required Widget child,
      bool skippable = false,
      String nextLabel = 'Next',
      VoidCallback? onNext,
    }) {
      return StepScaffold(
        stepIndex: _index,
        stepCount: n,
        title: title,
        subtitle: subtitle,
        onBack: _back,
        onNext: onNext ?? _next,
        nextEnabled: _canContinue,
        nextLabel: nextLabel,
        onSkip: skippable ? _next : null,
        busy: _saving,
        child: child,
      );
    }

    final page = switch (_step) {
      _Step.name => scaffold(
        title: 'Medicine name',
        subtitle:
            'It is not in our list, so it is saved exactly as you type it.',
        child: Column(
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: t.titleLarge,
              decoration: const InputDecoration(hintText: 'e.g. Crocin'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _composition,
              decoration: const InputDecoration(
                labelText: 'Strength or ingredients (optional)',
                hintText: 'e.g. Paracetamol 500 mg',
              ),
            ),
          ],
        ),
      ),
      _Step.often => scaffold(
        title: 'How often do you take $label?',
        subtitle: hit?.compositionMayBeIncomplete == true
            ? 'The ingredient list for this product may be incomplete. Check the strip.'
            : null,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 1.7,
          children: [
            for (var i = 0; i < _presets.length; i++)
              ChoiceTile(
                label: _presets[i].label,
                caption: _presets[i].pattern,
                selected: _presetIndex == i,
                onTap: () => _applyPreset(i),
              ),
          ],
        ),
      ),
      _Step.amount => scaffold(
        title: 'How much each time?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final u in DoseUnit.values)
                  ChoiceChip(
                    label: Text(u.label),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  for (final slot in DaySlot.values) ...[
                    _AmountRow(
                      label: slot.label,
                      unit: _unit,
                      amount: _amounts[slot]!,
                      onMinus: () => _bump(slot, -1),
                      onPlus: () => _bump(slot, 1),
                    ),
                    if (slot != DaySlot.night) const Divider(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      _Step.food => scaffold(
        title: 'With food?',
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 1.9,
          children: [
            for (final m in [
              MealTiming.afterFood,
              MealTiming.beforeFood,
              MealTiming.withFood,
              MealTiming.anytime,
            ])
              ChoiceTile(
                label: m.label,
                caption: switch (m) {
                  MealTiming.beforeFood => '30 min before the meal',
                  MealTiming.afterFood => '30 min after the meal',
                  MealTiming.withFood => 'at the meal',
                  MealTiming.anytime => 'at meal time',
                },
                selected: _timing == m,
                onTap: () => setState(() => _timing = m),
              ),
          ],
        ),
      ),
      _Step.duration => scaffold(
        title: 'For how long?',
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('Ongoing'),
              selected: _courseDays == null,
              onSelected: (_) => setState(() => _courseDays = null),
            ),
            for (final d in const [3, 5, 7, 10, 14, 30])
              ChoiceChip(
                label: Text('$d days'),
                selected: _courseDays == d,
                onSelected: (_) => setState(() => _courseDays = d),
              ),
          ],
        ),
      ),
      _Step.reason => scaffold(
        title: 'What is it for?',
        subtitle: 'Optional. Helps you remember, and shows in the summary for your doctor.',
        skippable: true,
        child: ConditionPicker(
          selected: _reasons,
          onChanged: (v) => setState(() => _reasons = v),
          suggestionsTitle: 'This medicine is often used for',
          suggestions: [
            ...?hit?.uses.take(6),
            ...(ref.watch(profileConditionsProvider).value ?? const <String>[]),
          ],
        ),
      ),
      _Step.stock => scaffold(
        title: 'How many do you have?',
        subtitle: 'Optional. We warn you before it runs out.',
        skippable: true,
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final pack = hit?.packQty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _stock,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: t.titleLarge,
                  decoration: InputDecoration(
                    hintText: 'e.g. 10',
                    suffixText: _unit.label.toLowerCase(),
                  ),
                ),
                if (pack != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: ActionChip(
                      label: Text('One pack (${formatAmount(pack)})'),
                      onPressed: () =>
                          setLocal(() => _stock.text = formatAmount(pack)),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Warn me when about this many days are left',
                  style: t.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final d in const [3, 5, 7])
                      ChoiceChip(
                        label: Text('$d days'),
                        selected: _warnDays == d,
                        onSelected: (_) => setLocal(() => _warnDays = d),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      _Step.review => scaffold(
        title: 'All set?',
        subtitle: 'Tap any line to change it.',
        nextLabel: 'Save medicine',
        onNext: _save,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(_medicineName, style: t.titleLarge),
                    subtitle: hit == null
                        ? const Text('Added by you')
                        : Text(hit.subtitle, maxLines: 2),
                    onTap: hit == null ? () => _jump(_Step.name) : null,
                  ),
                  const Divider(height: 1),
                  _ReviewRow(
                    'How often',
                    _patternText(),
                    () => _jump(_Step.often),
                  ),
                  _ReviewRow(
                    'How much',
                    _amountText(),
                    () => _jump(_Step.amount),
                  ),
                  _ReviewRow(
                    'Food',
                    '${_timing.label} · $_timingCaption',
                    () => _jump(_Step.food),
                  ),
                  _ReviewRow(
                    'Duration',
                    _courseDays == null ? 'Ongoing' : '$_courseDays days',
                    () => _jump(_Step.duration),
                  ),
                  _ReviewRow(
                    'For',
                    _reasons.isEmpty ? 'Not set' : _reasons.join(', '),
                    () => _jump(_Step.reason),
                  ),
                  _ReviewRow(
                    'In stock',
                    _stock.text.trim().isEmpty
                        ? 'Not tracked'
                        : '${_stock.text.trim()} ${_unit.label.toLowerCase()}',
                    () => _jump(_Step.stock),
                  ),
                ],
              ),
            ),
            if (hit != null) _Alternatives(hit: hit),
          ],
        ),
      ),
    };
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(body: page),
    );
  }

  String _patternText() =>
      DaySlot.values.map((s) => formatAmount(_amounts[s]!)).join('-');

  String _amountText() => [
    for (final s in DaySlot.values)
      if (_amounts[s]! > 0) '${s.label} ${_unit.describe(_amounts[s]!)}',
  ].join(', ');
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, this.onTap);

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: context.textTheme.bodyMedium),
      subtitle: Text(value, style: context.textTheme.titleMedium),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: onTap,
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.unit,
    required this.amount,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final DoseUnit unit;
  final double amount;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.titleMedium),
                Text(
                  amount > 0 ? unit.describe(amount) : 'None',
                  style: t.bodyMedium?.copyWith(
                    color: amount > 0
                        ? context.colorScheme.primary
                        : context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            iconSize: 28,
            tooltip: 'Less',
            onPressed: amount > 0 ? onMinus : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              formatAmount(amount),
              textAlign: TextAlign.center,
              style: t.headlineMedium,
            ),
          ),
          IconButton.filledTonal(
            iconSize: 28,
            tooltip: 'More',
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Optional: other products with the same ingredients and strength.
class _Alternatives extends ConsumerWidget {
  const _Alternatives({required this.hit});

  final MedicineHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alts =
        ref.watch(alternativesProvider(hit)).value ?? const <MedicineHit>[];
    if (alts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.compare_arrows),
          title: const Text('Same ingredients, other brands'),
          subtitle: Text('${alts.length} found'),
          children: [
            for (final a in alts)
              ListTile(
                dense: true,
                title: Text(a.name),
                subtitle: Text(
                  a.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushReplacement(
                  AppRoutes.addDetails,
                  extra: AddDraft(hit: a),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Same ingredients and strength according to the list. '
                'Ask your doctor or pharmacist before switching brands.',
                style: context.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
