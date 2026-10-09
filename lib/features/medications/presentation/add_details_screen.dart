import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/allergy/application/allergy_check.dart';
import 'package:reindeer/features/allergy/presentation/allergy_warning.dart';
import 'package:reindeer/features/conditions/presentation/condition_picker.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/application/insight_providers.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/symptoms/application/symptom_links.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';
import 'package:reindeer/core/i18n/strings.dart';

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

enum _Step { name, often, days, amount, food, duration, reason, stock, review }

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
  int _intervalDays = 1; // 1 = every day, 2 = every other day, ...
  int _weekdays = 0; // bit mask, bit 0 = Monday; 0 = not by weekday
  bool _byWeekdays = false;
  bool _useAlt = false;
  final Map<DaySlot, double> _altAmounts = {
    for (final s in DaySlot.values) s: 0,
  };
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
    _applyPrefill(widget.draft.prefill);
  }

  /// Fills the answers from a typed prescription line. For a medicine from the
  /// list the person lands straight on the review page.
  void _applyPrefill(ParsedShorthand? p) {
    if (p == null) return;
    final a = p.amounts;
    if (a != null) {
      for (final s in DaySlot.values) {
        _amounts[s] = a[s] ?? 0;
      }
      final taken = [
        for (final s in DaySlot.values)
          if (_amounts[s]! > 0) s,
      ];
      final allOne = taken.every((s) => _amounts[s] == 1);
      final idx = _presets.indexWhere(
        (pr) =>
            pr.slots.length == taken.length && pr.slots.every(taken.contains),
      );
      _presetIndex = allOne && idx >= 0 ? idx : null;
    }
    if (p.intervalDays != null) _intervalDays = p.intervalDays!;
    if (p.timing != null) _timing = p.timing!;
    if (p.days != null) _courseDays = p.days;
    if (_hit != null && _amounts.values.any((v) => v > 0)) {
      _index = _steps.indexOf(_Step.review);
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

  /// Name and composition, for matching against allergies.
  String get _allergyText =>
      '$_medicineName ${_hit?.composition ?? _composition.text}';

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _presetIndex = index;
      for (final s in DaySlot.values) {
        _amounts[s] = preset.slots.contains(s) ? 1 : 0;
      }
    });
  }

  void _bumpAlt(DaySlot slot, int direction) {
    final next = (_altAmounts[slot]! + direction * _unit.step)
        .clamp(0, 20)
        .toDouble();
    setState(() => _altAmounts[slot] = next);
  }

  void _setAlt(bool on) {
    setState(() {
      _useAlt = on;
      if (on && _altAmounts.values.every((v) => v == 0)) {
        for (final s in DaySlot.values) {
          _altAmounts[s] = _amounts[s]! * 2;
        }
      }
    });
  }

  /// "Every other day", "Mon, Wed, Fri" or "" for every day.
  String _freqText() {
    if (_byWeekdays) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return [
        for (var i = 0; i < 7; i++)
          if (_weekdays & (1 << i) != 0) tr(names[i]),
      ].join(', ');
    }
    if (_intervalDays == 2) return tr('Every other day');
    if (_intervalDays > 2) {
      return trf('Every {n} days', {'n': '$_intervalDays'});
    }
    return tr('Every day');
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
    _Step.days => !_byWeekdays || _weekdays != 0,
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
    if (_saving) return;
    setState(() => _saving = true);
    final matches = await ref.read(
      allergyCheckProvider((id: _hit?.id, text: _allergyText)).future,
    );
    if (matches.isNotEmpty) {
      if (!mounted) return;
      setState(() => _saving = false);
      final allergyNames = {for (final m in matches) m.allergy}.join(', ');
      final ingredientNames = {for (final m in matches) m.ingredient}
          .join(', ');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Possible allergy')),
          content: Text(
            'You noted an allergy to $allergyNames. '
            'This medicine contains $ingredientNames.\n\n'
            'Ask your doctor or pharmacist before taking it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Go back')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Add anyway')),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      setState(() => _saving = true);
    }
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
      intervalDays: _byWeekdays ? 1 : _intervalDays,
      weekdays: _byWeekdays ? _weekdays : 0,
      altAmounts: _useAlt && !_byWeekdays ? Map.of(_altAmounts) : null,
    );
    try {
      await ref.read(planActionsProvider).add(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar(trf('Could not save: {n}', {'n': '$e'}));
      return;
    }
    if (!mounted) return;
    context.go(AppRoutes.medicines);
    context.showSnackBar(trf('{n} added', {'n': name}));
  }

  String get _timingCaption => switch (_timing) {
    MealTiming.beforeFood => tr('30 min before the meal'),
    MealTiming.afterFood => tr('30 min after the meal'),
    MealTiming.withFood => tr('at the meal'),
    MealTiming.anytime => tr('at meal time'),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final n = _steps.length;
    final hit = _hit;
    final label = _medicineName.isEmpty ? tr('this medicine') : _medicineName;

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
        title: tr('Medicine name'),
        subtitle: tr(
          'It is not in our list, so it is saved exactly as you type it.',
        ),
        child: Column(
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: t.titleLarge,
              decoration: InputDecoration(hintText: tr('e.g. Crocin')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _composition,
              decoration: InputDecoration(
                labelText: tr('Strength or ingredients (optional)'),
                hintText: tr('e.g. Paracetamol 500 mg'),
              ),
            ),
          ],
        ),
      ),
      _Step.often => scaffold(
        title: trf('How often do you take {n}?', {'n': label}),
        subtitle: hit?.compositionMayBeIncomplete == true
            ? tr(
                'The ingredient list for this product may be incomplete. Check the strip.',
              )
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
                label: tr(_presets[i].label),
                caption: tr(_presets[i].pattern),
                selected: _presetIndex == i,
                onTap: () => _applyPreset(i),
              ),
          ],
        ),
      ),
      _Step.days => scaffold(
        title: tr('Which days?'),
        subtitle: tr(
          'Most medicines are every day. Choose another pattern if your doctor said so.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 1.9,
              children: [
                ChoiceTile(
                  label: tr('Every day'),
                  selected: !_byWeekdays && _intervalDays == 1,
                  onTap: () => setState(() {
                    _byWeekdays = false;
                    _intervalDays = 1;
                  }),
                ),
                ChoiceTile(
                  label: tr('Every other day'),
                  selected: !_byWeekdays && _intervalDays == 2,
                  onTap: () => setState(() {
                    _byWeekdays = false;
                    _intervalDays = 2;
                  }),
                ),
                ChoiceTile(
                  label: trf('Every {n} days', {'n': '3'}),
                  selected: !_byWeekdays && _intervalDays == 3,
                  onTap: () => setState(() {
                    _byWeekdays = false;
                    _intervalDays = 3;
                  }),
                ),
                ChoiceTile(
                  label: tr('Choose weekdays'),
                  selected: _byWeekdays,
                  onTap: () => setState(() {
                    _byWeekdays = true;
                    _useAlt = false;
                  }),
                ),
              ],
            ),
            if (_byWeekdays) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(
                        tr(
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                        ),
                      ),
                      selected: _weekdays & (1 << i) != 0,
                      onSelected: (on) => setState(() {
                        _weekdays = on
                            ? _weekdays | (1 << i)
                            : _weekdays & ~(1 << i);
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      _Step.amount => scaffold(
        title: tr('How much each time?'),
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
            if (!_byWeekdays) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('A different amount on the other days')),
                subtitle: Text(
                  tr('For example 1 tablet one day and 2 the next.'),
                ),
                value: _useAlt,
                onChanged: _setAlt,
              ),
              if (_useAlt)
                Card(
                  child: Column(
                    children: [
                      for (final slot in DaySlot.values) ...[
                        _AmountRow(
                          label: slot.label,
                          unit: _unit,
                          amount: _altAmounts[slot]!,
                          onMinus: () => _bumpAlt(slot, -1),
                          onPlus: () => _bumpAlt(slot, 1),
                        ),
                        if (slot != DaySlot.night) const Divider(),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      _Step.food => scaffold(
        title: tr('With food?'),
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
                  MealTiming.beforeFood => tr('30 min before the meal'),
                  MealTiming.afterFood => tr('30 min after the meal'),
                  MealTiming.withFood => tr('at the meal'),
                  MealTiming.anytime => tr('at meal time'),
                },
                selected: _timing == m,
                onTap: () => setState(() => _timing = m),
              ),
          ],
        ),
      ),
      _Step.duration => scaffold(
        title: tr('For how long?'),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: Text(tr('Ongoing')),
              selected: _courseDays == null,
              onSelected: (_) => setState(() => _courseDays = null),
            ),
            for (final d in ({
              3,
              5,
              7,
              10,
              14,
              30,
              ?_courseDays,
            }.toList()..sort()))
              ChoiceChip(
                label: Text(trf('{n} days', {'n': '$d'})),
                selected: _courseDays == d,
                onSelected: (_) => setState(() => _courseDays = d),
              ),
          ],
        ),
      ),
      _Step.reason => scaffold(
        title: tr('What is it for?'),
        subtitle: tr(
          'Optional. Helps you remember, and shows in the summary for your doctor.',
        ),
        skippable: true,
        child: ConditionPicker(
          selected: _reasons,
          onChanged: (v) => setState(() => _reasons = v),
          suggestionsTitle: tr('This medicine is often used for'),
          suggestions: [
            ...?hit?.uses.take(6),
            ...(ref.watch(profileConditionsProvider).value ?? const <String>[]),
          ],
        ),
      ),
      _Step.stock => scaffold(
        title: tr('How many do you have?'),
        subtitle: tr('Optional. We warn you before it runs out.'),
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
                      label: Text(
                        trf('One pack ({n})', {'n': formatAmount(pack)}),
                      ),
                      onPressed: () =>
                          setLocal(() => _stock.text = formatAmount(pack)),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  tr('Warn me when about this many days are left'),
                  style: t.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final d in const [3, 5, 7])
                      ChoiceChip(
                        label: Text(trf('{n} days', {'n': '$d'})),
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
        title: tr('All set?'),
        subtitle: tr('Tap any line to change it.'),
        nextLabel: tr('Save medicine'),
        onNext: _save,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AllergyBanner(id: hit?.id, text: _allergyText),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(_medicineName, style: t.titleLarge),
                    subtitle: hit == null
                        ? Text(tr('Added by you'))
                        : Text(hit.subtitle, maxLines: 2),
                    onTap: hit == null ? () => _jump(_Step.name) : null,
                  ),
                  const Divider(height: 1),
                  _ReviewRow(
                    tr('How often'),
                    _patternText(),
                    () => _jump(_Step.often),
                  ),
                  if (_byWeekdays || _intervalDays > 1)
                    _ReviewRow(
                      tr('Which days'),
                      _freqText(),
                      () => _jump(_Step.days),
                    ),
                  _ReviewRow(
                    tr('How much'),
                    _amountText(),
                    () => _jump(_Step.amount),
                  ),
                  _ReviewRow(
                    tr('Food'),
                    '${_timing.label} · $_timingCaption',
                    () => _jump(_Step.food),
                  ),
                  _ReviewRow(
                    tr('Duration'),
                    _courseDays == null
                        ? tr('Ongoing')
                        : trf('{n} days', {'n': '$_courseDays'}),
                    () => _jump(_Step.duration),
                  ),
                  _ReviewRow(
                    tr('For'),
                    _reasons.isEmpty ? tr('Not set') : _reasons.join(', '),
                    () => _jump(_Step.reason),
                  ),
                  _ReviewRow(
                    tr('In stock'),
                    _stock.text.trim().isEmpty
                        ? tr('Not tracked')
                        : '${_stock.text.trim()} ${_unit.label.toLowerCase()}',
                    () => _jump(_Step.stock),
                  ),
                ],
              ),
            ),
            if (hit != null) _OverlapWarning(hit: hit),
            if (hit != null) _SideEffectsCard(id: hit.id),
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
      child: Scaffold(
        body: StepSwitcher(index: _index, child: page),
      ),
    );
  }

  String _patternText() =>
      DaySlot.values.map((s) => formatAmount(_amounts[s]!)).join('-');

  String _amountText() {
    String line(Map<DaySlot, double> m) => [
      for (final s in DaySlot.values)
        if (m[s]! > 0) '${s.label} ${_unit.describe(m[s]!)}',
    ].join(', ');
    final base = line(_amounts);
    if (!_useAlt || _byWeekdays) return base;
    final other = line(_altAmounts);
    return '$base\n${tr('Other days')}: ${other.isEmpty ? tr('none') : other}';
  }
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
                  amount > 0 ? unit.describe(amount) : tr('None'),
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
            tooltip: tr('Less'),
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
            tooltip: tr('More'),
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Warns when the medicine matches a recorded allergy.
class _AllergyBanner extends ConsumerWidget {
  const _AllergyBanner({required this.id, required this.text});

  final int? id;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches =
        ref.watch(allergyCheckProvider((id: id, text: text))).value ?? const [];
    if (matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AllergyWarningCard(matches: matches),
    );
  }
}

/// Warns when an active medicine shares an ingredient with the new one.
class _OverlapWarning extends ConsumerWidget {
  const _OverlapWarning({required this.hit});

  final MedicineHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlaps =
        ref.watch(ingredientOverlapProvider(hit.id)).value ??
        const <IngredientOverlap>[];
    if (overlaps.isEmpty) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Same ingredient already in your list'),
                      style: context.textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    for (final o in overlaps)
                      Text(
                        '${o.plan.name} also contains ${o.ingredients.join(', ')}.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      tr(
                        'Taking two medicines with the same ingredient can add up to too much. Ask your doctor or pharmacist before taking both. Reindeer only compares ingredient names and does not check other interactions.',
                      ),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          title: Text(tr('Same ingredients, other brands')),
          subtitle: Text(trf('{n} found', {'n': '${alts.length}'})),
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
                tr(
                  'Same ingredients and strength according to the list. Ask your doctor or pharmacist before switching brands.',
                ),
                style: context.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Common side effects listed in the data for this medicine.
class _SideEffectsCard extends ConsumerWidget {
  const _SideEffectsCard({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(sideEffectsProvider(id)).value ?? '';
    if (effects.trim().isEmpty) return const SizedBox.shrink();
    final t = context.textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('Possible side effects')),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(effects, style: t.bodyLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr(
                  'Listed in our data. Most people get few or none. Ask your doctor or pharmacist if you are worried.',
                ),
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
