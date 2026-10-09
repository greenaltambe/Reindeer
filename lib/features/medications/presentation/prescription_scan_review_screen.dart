import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/application/strip_scanner.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/prescription_scan_parser.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// Screen where users (especially elderly) review medicines read off a prescription photo.
class PrescriptionScanReviewScreen extends ConsumerStatefulWidget {
  const PrescriptionScanReviewScreen({super.key, this.initialItems});

  final List<ScannedPrescriptionItem>? initialItems;

  @override
  ConsumerState<PrescriptionScanReviewScreen> createState() =>
      _PrescriptionScanReviewScreenState();
}

class _PrescriptionScanReviewScreenState
    extends ConsumerState<PrescriptionScanReviewScreen> {
  late List<ScannedPrescriptionItem> _items = widget.initialItems ?? [];
  bool _scanning = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    final source = await showModalBottomSheet<ScanSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Scan Doctor\'s Prescription'),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('Take a clear photo of the prescription paper or slip.'),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: context.colorScheme.outlineVariant),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                leading: CircleAvatar(
                  backgroundColor: context.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.photo_camera_rounded,
                    color: context.colorScheme.primary,
                  ),
                ),
                title: Text(
                  tr('Take a photo now'),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(tr('Use phone camera to take photo')),
                onTap: () => Navigator.pop(ctx, ScanSource.camera),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: context.colorScheme.outlineVariant),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                leading: CircleAvatar(
                  backgroundColor: context.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  tr('Choose from gallery'),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(tr('Pick an existing photo or scan')),
                onTap: () => Navigator.pop(ctx, ScanSource.gallery),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );

    if (source == null) {
      if (_items.isEmpty && mounted) {
        context.pop();
      }
      return;
    }

    setState(() => _scanning = true);

    try {
      final rawText = await scanPrescriptionText(source);
      if (!mounted) return;
      if (rawText == null || rawText.trim().isEmpty) {
        setState(() {
          _scanning = false;
        });
        return;
      }

      final searchService = await ref.read(medicineSearchProvider.future);
      final parsed = await PrescriptionScanParser.parse(
        rawText,
        searchService: searchService,
      );

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      context.showSnackBar(trf('Could not read photo: {n}', {'n': '$e'}));
    }
  }

  Future<void> _saveSelected() async {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) {
      context.showSnackBar(tr('Please select at least one medicine.'));
      return;
    }

    setState(() => _saving = true);

    try {
      final profile = await ref.read(profileRepositoryProvider).get();
      final planRepo = ref.read(planRepositoryProvider);
      final now = DateTime.now();

      for (final item in selected) {
        final plan = MedicationPlan(
          profileId: profile.name.isEmpty ? 'me' : profile.name,
          medicineId: item.hit?.id,
          name: item.name,
          composition: item.composition,
          kind: item.hit != null ? item.hit!.kind : MedicineKind.custom,
          doseUnit: item.unit,
          slotAmounts: item.slotAmounts,
          mealTiming: item.mealTiming,
          startDate: now,
          endDate: item.durationDays != null
              ? now.add(Duration(days: item.durationDays!))
              : null,
          createdAt: now,
        );
        await planRepo.insert(plan);
      }

      // Refresh reminders & notify state
      ref.read(dataVersionProvider.notifier).bump();
      try {
        await ref.read(reminderServiceProvider).rescheduleAll();
      } catch (_) {}

      if (!mounted) return;
      context.showSnackBar(
        trn(
          selected.length,
          'Added {n} medicine from prescription',
          'Added {n} medicines from prescription',
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar(trf('Could not save medicines: {n}', {'n': '$e'}));
    }
  }

  void _editItem(ScannedPrescriptionItem item) async {
    final edited = await showModalBottomSheet<ScannedPrescriptionItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditItemSheet(item: item),
    );
    if (edited != null && mounted) {
      setState(() {
        final index = _items.indexOf(item);
        if (index >= 0) _items[index] = edited;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final selectedCount = _items.where((i) => i.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Scanned Prescription')),
        actions: [
          IconButton(
            tooltip: tr('Scan another photo'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scanning || _saving ? null : _startScan,
          ),
        ],
      ),
      body: _scanning
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('Reading your prescription...'),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('Checking medicine names securely on this phone.'),
                    style: t.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? EmptyStateView(
              title: tr('No medicines found'),
              message: tr(
                'Doctor handwriting can sometimes be unclear. Try a closer, well-lit photo, or add medicines directly.',
              ),
              illustration: const ReindeerMark(size: 80, interactive: true),
              actionLabel: tr('Try photo again'),
              onAction: _startScan,
            )
          : Column(
              children: [
                // Top banner for elderly clarity
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: scheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trn(
                            _items.length,
                            'Found {n} medicine. Select the ones you want to add:',
                            'Found {n} medicines. Select the ones you want to add:',
                          ),
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _ScannedItemCard(
                        item: item,
                        onToggle: (val) {
                          setState(() => item.isSelected = val ?? false);
                        },
                        onEdit: () => _editItem(item),
                      );
                    },
                  ),
                ),

                // Bottom Save Bar
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: _saving || selectedCount == 0
                          ? null
                          : _saveSelected,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              trn(
                                selectedCount,
                                'Add {n} medicine to Reindeer',
                                'Add {n} medicines to Reindeer',
                              ),
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScannedItemCard extends StatelessWidget {
  const _ScannedItemCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
  });

  final ScannedPrescriptionItem item;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: item.isSelected ? scheme.primary : scheme.outlineVariant,
          width: item.isSelected ? 1.5 : 1,
        ),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: () => onToggle(!item.isSelected),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: item.isSelected, onChanged: onToggle),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: item.isSelected
                            ? scheme.onSurface
                            : scheme.outline,
                      ),
                    ),
                    if (item.composition.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          item.composition,
                          style: t.bodySmall?.copyWith(
                            color: scheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (!item.isMatched)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 16,
                              color: scheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tr(
                                  'Not found in medicine list. Tap edit to check the name.',
                                ),
                                style: t.bodySmall?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Schedule Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.amountMorning > 0)
                          _Badge(
                            label:
                                '☀️ Morning: ${ScannedPrescriptionItem.fmt(item.amountMorning)}',
                            color: Colors.amber.shade800,
                          ),
                        if (item.amountAfternoon > 0)
                          _Badge(
                            label:
                                '🌤️ Afternoon: ${ScannedPrescriptionItem.fmt(item.amountAfternoon)}',
                            color: Colors.orange.shade800,
                          ),
                        if (item.amountNight > 0)
                          _Badge(
                            label:
                                '🌙 Night: ${ScannedPrescriptionItem.fmt(item.amountNight)}',
                            color: Colors.indigo.shade700,
                          ),
                        _Badge(
                          label: item.mealTiming.label,
                          color: scheme.primary,
                        ),
                        if (item.durationDays != null)
                          _Badge(
                            label: '${item.durationDays} days',
                            color: scheme.tertiary,
                          ),
                      ],
                    ),
                    if (item.sourceText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          trf('Read as: {n}', {'n': item.sourceText}),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: scheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: tr('Edit medicine'),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({required this.item});

  final ScannedPrescriptionItem item;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late double _m = widget.item.amountMorning;
  late double _a = widget.item.amountAfternoon;
  late double _n = widget.item.amountNight;
  late MealTiming _timing = widget.item.mealTiming;
  late final _nameController = TextEditingController(text: widget.item.name);
  late MedicineHit? _hit = widget.item.hit;
  List<MedicineHit> _results = const [];
  int _searchId = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final id = ++_searchId;
    setState(() => _hit = null);
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    final service = await ref.read(medicineSearchProvider.future);
    final hits = await service.search(query, asYouType: true, limit: 6);
    if (!mounted || id != _searchId) return;
    setState(() => _results = hits);
  }

  void _pick(MedicineHit hit) {
    _searchId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _hit = hit;
      _nameController.text = hit.name;
      _results = const [];
    });
  }

  void _save() {
    final item = widget.item;
    final typed = _nameController.text.trim();
    final hit = _hit;
    if (hit != null) {
      item.hit = hit;
      item.name = hit.name;
      item.composition = hit.composition;
      item.unit = DoseUnit.fromForm(hit.form);
    } else if (typed.isNotEmpty && typed != item.name) {
      item.hit = null;
      item.name = typed;
      item.composition = '';
    }
    item.slotAmounts = {
      DaySlot.morning: _m,
      DaySlot.afternoon: _a,
      DaySlot.night: _n,
    };
    item.mealTiming = _timing;
    item.isSelected = true;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.item.sourceText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    trf('Read as: {n}', {'n': widget.item.sourceText}),
                    style: t.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: tr('Medicine name'),
                  border: const OutlineInputBorder(),
                  suffixIcon: _hit != null
                      ? Icon(Icons.verified_rounded, color: scheme.primary)
                      : null,
                ),
                onChanged: _search,
              ),
              if (_hit != null && _hit!.composition.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _hit!.composition,
                    style: t.bodySmall?.copyWith(
                      color: scheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              for (final hit in _results)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(hit.name),
                  subtitle: hit.composition.isEmpty
                      ? null
                      : Text(
                          hit.composition,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _pick(hit),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(tr('Dose amount per time:'), style: t.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              _SlotStepper(
                label: tr('Morning'),
                icon: Icons.wb_sunny_outlined,
                value: _m,
                unit: widget.item.unit.label,
                onChanged: (v) => setState(() => _m = v),
              ),
              _SlotStepper(
                label: tr('Afternoon'),
                icon: Icons.wb_twilight_outlined,
                value: _a,
                unit: widget.item.unit.label,
                onChanged: (v) => setState(() => _a = v),
              ),
              _SlotStepper(
                label: tr('Night'),
                icon: Icons.nightlight_outlined,
                value: _n,
                unit: widget.item.unit.label,
                onChanged: (v) => setState(() => _n = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(tr('Food timing:'), style: t.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                children: [
                  for (final timing in [
                    MealTiming.beforeFood,
                    MealTiming.afterFood,
                    MealTiming.withFood,
                    MealTiming.anytime,
                  ])
                    ChoiceChip(
                      label: Text(timing.label),
                      selected: _timing == timing,
                      onSelected: (sel) {
                        if (sel) setState(() => _timing = timing);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _save, child: Text(tr('Save Changes'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotStepper extends StatelessWidget {
  const _SlotStepper({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
          IconButton.filledTonal(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > 0
                ? () => onChanged((value - 0.5).clamp(0, 10))
                : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              ScannedPrescriptionItem.fmt(value),
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged((value + 0.5).clamp(0, 10)),
          ),
        ],
      ),
    );
  }
}
