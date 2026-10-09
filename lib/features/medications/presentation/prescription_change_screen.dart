import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/medications/domain/models/prescription_diff.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';

IconData _slotIcon(DaySlot slot) => switch (slot) {
  DaySlot.morning => Icons.wb_sunny_outlined,
  DaySlot.afternoon => Icons.light_mode_outlined,
  DaySlot.night => Icons.bedtime_outlined,
};

/// Screen allowing patient or family to record changes made by doctor at a visit,
/// review the "What Changed" diff, and save versioned updates with history preserved.
class PrescriptionChangeScreen extends ConsumerStatefulWidget {
  const PrescriptionChangeScreen({super.key});

  @override
  ConsumerState<PrescriptionChangeScreen> createState() =>
      _PrescriptionChangeScreenState();
}

class _PrescriptionChangeScreenState
    extends ConsumerState<PrescriptionChangeScreen> {
  final Map<int, Map<DaySlot, double>> _editedAmounts = {};
  final Map<int, MealTiming> _editedTiming = {};
  final Set<int> _stoppedPlanIds = {};
  final TextEditingController _reasonController = TextEditingController(
    text: 'Doctor visit adjustment',
  );

  bool _reviewMode = false;
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final t = context.textTheme;
    final scheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _reviewMode ? tr('What changed') : tr('Doctor changed my medicines'),
        ),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (plans) {
          final active = plans.where((p) => p.isActive).toList();
          if (active.isEmpty) {
            return Center(child: Text(tr('No active medicines to change.')));
          }

          if (_reviewMode) {
            return _buildReviewView(context, active, t, scheme);
          }

          return _buildEditView(context, active, t, scheme);
        },
      ),
    );
  }

  Widget _buildEditView(
    BuildContext context,
    List<MedicationPlan> active,
    TextTheme t,
    ColorScheme scheme,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        96,
      ),
      children: [
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
                Icon(Icons.edit_note, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    tr(
                      'Update doses or mark stopped medicines. Historical doses and adherence will stay preserved.',
                    ),
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionTitle(tr('Current Medicines')),
        for (final plan in active) ...[
          _buildPlanEditCard(plan, scheme, t),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.add),
          icon: const Icon(Icons.add),
          label: Text(tr('Add new medicine prescribed by doctor')),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => setState(() => _reviewMode = true),
          icon: const Icon(Icons.compare_arrows),
          label: Text(tr('Review What Changed')),
        ),
      ],
    );
  }

  Widget _buildPlanEditCard(
    MedicationPlan plan,
    ColorScheme scheme,
    TextTheme t,
  ) {
    final planId = plan.id!;
    final isStopped = _stoppedPlanIds.contains(planId);
    final amounts = _editedAmounts[planId] ?? plan.slotAmounts;
    final timing = _editedTiming[planId] ?? plan.mealTiming;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isStopped
              ? scheme.error.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      color: isStopped ? scheme.surfaceContainerLow : scheme.surface,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isStopped
                              ? TextDecoration.lineThrough
                              : null,
                          color: isStopped ? scheme.outline : scheme.onSurface,
                        ),
                      ),
                      if (plan.composition.isNotEmpty)
                        Text(
                          plan.composition,
                          style: t.bodySmall?.copyWith(color: scheme.outline),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChip(
                  avatar: Icon(
                    isStopped
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                    color: isStopped ? scheme.error : scheme.primary,
                  ),
                  label: Text(
                    isStopped ? tr('Stopped') : tr('Active'),
                    style: TextStyle(
                      color: isStopped ? scheme.error : scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: isStopped,
                  selectedColor: scheme.errorContainer.withValues(alpha: 0.6),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _stoppedPlanIds.add(planId);
                      } else {
                        _stoppedPlanIds.remove(planId);
                      }
                    });
                  },
                ),
              ],
            ),
            if (isStopped) ...[
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                          'Discontinued at this visit. Past records remain safe.',
                        ),
                        style: t.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Divider(height: 24),
              Text(
                tr('Dose amount per time of day:'),
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final slot in DaySlot.values)
                _buildSlotRow(
                  planId,
                  slot,
                  amounts[slot] ?? 0,
                  plan.doseUnit,
                  scheme,
                  t,
                ),
              const SizedBox(height: 8),
              Text(
                tr('Food timing:'),
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final m in MealTiming.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: timing == m,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _editedTiming[planId] = m);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(
    int planId,
    DaySlot slot,
    double current,
    DoseUnit unit,
    ColorScheme scheme,
    TextTheme t,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_slotIcon(slot), size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slot.label,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            iconSize: 18,
            icon: const Icon(Icons.remove),
            onPressed: current > 0
                ? () {
                    final next = (current - unit.step).clamp(0.0, 20.0);
                    setState(() {
                      _editedAmounts.putIfAbsent(planId, () => {})[slot] = next;
                    });
                  }
                : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            alignment: Alignment.center,
            child: Text(
              '${formatAmount(current)} ${unit.label}',
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            iconSize: 18,
            icon: const Icon(Icons.add),
            onPressed: () {
              final next = (current + unit.step).clamp(0.0, 20.0);
              setState(() {
                _editedAmounts.putIfAbsent(planId, () => {})[slot] = next;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView(
    BuildContext context,
    List<MedicationPlan> active,
    TextTheme t,
    ColorScheme scheme,
  ) {
    final modifiedPlans = <MedicationPlan>[];
    for (final p in active) {
      final pid = p.id!;
      if (_stoppedPlanIds.contains(pid)) {
        modifiedPlans.add(p.copyWith(status: PlanStatus.discontinued));
      } else {
        final amounts = _editedAmounts[pid] ?? p.slotAmounts;
        final timing = _editedTiming[pid] ?? p.mealTiming;
        modifiedPlans.add(p.copyWith(slotAmounts: amounts, mealTiming: timing));
      }
    }

    final diff = computePrescriptionDiff(
      previousPlans: active,
      currentPlans: modifiedPlans,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        96,
      ),
      children: [
        Card(
          elevation: 0,
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Prescription Diff Summary'),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr(
                    'Review the differences before saving. This will update today\'s routine while keeping historical adherence intact.',
                  ),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionTitle(tr('What changed')),
        for (final item in diff)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: scheme.outlineVariant),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              leading: Icon(
                item.type == PlanDiffType.adjusted
                    ? Icons.published_with_changes
                    : (item.type == PlanDiffType.stopped
                          ? Icons.cancel_outlined
                          : (item.type == PlanDiffType.started
                                ? Icons.add_circle_outline
                                : Icons.check)),
                color: item.type == PlanDiffType.adjusted
                    ? Colors.orange
                    : (item.type == PlanDiffType.stopped
                          ? scheme.error
                          : (item.type == PlanDiffType.started
                                ? Colors.green
                                : scheme.outline)),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                item.type == PlanDiffType.adjusted
                    ? '${tr('Changed')}: ${item.oldSummary} -> ${item.newSummary}'
                    : (item.type == PlanDiffType.stopped
                          ? tr('Discontinued / stopped')
                          : (item.newSummary ?? tr('Unchanged'))),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reasonController,
          decoration: InputDecoration(
            labelText: tr('Doctor / reason note (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _saving ? null : () => _applyChanges(context, active),
          child: _saving
              ? const CircularProgressIndicator()
              : Text(tr('Save changes (keep history)')),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => setState(() => _reviewMode = false),
          child: Text(tr('Back to edit')),
        ),
      ],
    );
  }

  Future<void> _applyChanges(
    BuildContext context,
    List<MedicationPlan> active,
  ) async {
    setState(() => _saving = true);
    final repo = ref.read(planRepositoryProvider);
    final now = DateTime.now();
    final reason = _reasonController.text.trim();

    try {
      // 1. Process stopped plans
      for (final id in _stoppedPlanIds) {
        await repo.setStatus(id, PlanStatus.discontinued, now);
      }

      // 2. Process adjusted plans
      for (final plan in active) {
        final pid = plan.id!;
        if (_stoppedPlanIds.contains(pid)) continue;

        final newAmounts = _editedAmounts[pid];
        final newTiming = _editedTiming[pid];

        if (newAmounts != null || newTiming != null) {
          await repo.updatePlanSchedule(
            planId: pid,
            slotAmounts: newAmounts ?? plan.slotAmounts,
            mealTiming: newTiming ?? plan.mealTiming,
            intervalDays: plan.intervalDays,
            weekdays: plan.weekdays,
            altAmounts: plan.altAmounts,
            effectiveFrom: now,
            changeReason: reason.isNotEmpty
                ? reason
                : 'Doctor visit adjustment',
          );
        }
      }

      ref.read(dataVersionProvider.notifier).bump();
      await ref.read(reminderServiceProvider).rescheduleAll();

      if (context.mounted) {
        context.showSnackBar(
          tr('Prescription changes saved. History is preserved.'),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
