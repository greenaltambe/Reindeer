import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/refills/presentation/buy_medicine_sheet.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// All medicines: active first, then paused and stopped ones.
class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Medicines'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.add),
        icon: const Icon(Icons.add),
        label: Text(tr('Add medicine')),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Something went wrong'),
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (all) {
          if (all.isEmpty) {
            return EmptyStateView(
              title: tr('No medicines yet'),
              message: tr('Medicines you add will be listed here.'),
              illustration: const ReindeerMark(size: 96, interactive: true),
              actionLabel: tr('Add medicine'),
              onAction: () => context.push(AppRoutes.add),
            );
          }
          final active = all
              .where((p) => p.status == PlanStatus.active)
              .toList();
          final paused = all
              .where((p) => p.status == PlanStatus.paused)
              .toList();
          final stopped = all
              .where((p) => p.status == PlanStatus.discontinued)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              96,
            ),
            children: [
              // Unified Doctor & Prescription Tools (Clean Material 3 Card)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: context.colorScheme.outlineVariant),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            context.colorScheme.tertiaryContainer,
                        child: Icon(
                          Icons.document_scanner_outlined,
                          color: context.colorScheme.onTertiaryContainer,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        tr("Scan Doctor's Prescription"),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        tr('Take a photo to add all medicines at once.'),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(AppRoutes.scanPrescription),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            context.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.history_edu,
                          color: context.colorScheme.onPrimaryContainer,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        tr('Doctor changed my medicines'),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        tr(
                          'Review changes, keep past history safe, and update your schedule.',
                        ),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(AppRoutes.prescriptionChange),
                    ),
                  ],
                ),
              ),

              for (final (i, p) in active.indexed)
                FadeSlideIn(
                  key: ValueKey('plan${p.id}'),
                  index: i,
                  child: _PlanCard(plan: p),
                ),
              if (paused.isNotEmpty) ...[
                SectionTitle(tr('Paused')),
                for (final (i, p) in paused.indexed)
                  FadeSlideIn(
                    key: ValueKey('plan${p.id}'),
                    index: i,
                    child: _PlanCard(plan: p),
                  ),
              ],
              if (stopped.isNotEmpty) ...[
                SectionTitle(tr('Stopped')),
                for (final (i, p) in stopped.indexed)
                  FadeSlideIn(
                    key: ValueKey('plan${p.id}'),
                    index: i,
                    child: _PlanCard(plan: p),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final MedicationPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final dim = !plan.isActive;
    final daysLeft = plan.daysLeftInCourse(DateTime.now());
    // One line, only when something needs attention.
    final (String, bool)? status = switch (plan.status) {
      PlanStatus.paused => (tr('Paused'), false),
      PlanStatus.discontinued => (tr('Stopped'), false),
      _ when plan.isLowStock => (
        plan.daysOfStockLeft == null
            ? tr('Running low')
            : trn(
                plan.daysOfStockLeft!.floor(),
                'Running low · about {n} day left',
                'Running low · about {n} days left',
              ),
        true,
      ),
      _ when daysLeft != null && daysLeft <= 3 => (
        daysLeft == 0
            ? tr('Course finished')
            : trn(
                daysLeft,
                '{n} day left in course',
                '{n} days left in course',
              ),
        false,
      ),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xxs,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Opacity(
                  opacity: dim ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(plan.name, style: t.titleLarge)),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(plan.patternLabel, style: t.labelLarge),
                          ),
                        ],
                      ),
                      if (plan.composition.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(
                            plan.composition,
                            style: t.bodySmall?.copyWith(
                              color: scheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(_subtitle(), style: t.bodyLarge),
                      if (status != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: Text(
                            status.$1,
                            style: t.bodyMedium?.copyWith(
                              color: status.$2 ? scheme.error : scheme.outline,
                              fontWeight: status.$2 ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: tr('More'),
                onSelected: (v) => _onMenu(context, ref, v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'buy_online',
                    child: Text(tr('Buy / Order online')),
                  ),
                  PopupMenuItem(
                    value: 'refill',
                    child: Text(tr('Refill / update stock')),
                  ),
                  if (plan.isActive)
                    PopupMenuItem(
                      value: 'edit_schedule',
                      child: Text(tr('Adjust dose / timings')),
                    ),
                  if (plan.isActive)
                    PopupMenuItem(value: 'pause', child: Text(tr('Pause'))),
                  if (!plan.isActive)
                    PopupMenuItem(value: 'resume', child: Text(tr('Resume'))),
                  if (plan.status != PlanStatus.discontinued)
                    PopupMenuItem(
                      value: 'stop',
                      child: Text(tr('Stop (keep history)')),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(tr('Delete everything')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "1 tablet · after food", or the per-slot summary when amounts differ.
  String _subtitle() {
    final amounts = plan.activeSlots.map(plan.amountFor).toSet();
    var dose = amounts.length == 1
        ? plan.doseUnit.describe(amounts.first)
        : plan.doseSummary;
    if (plan.altAmounts != null) {
      dose = '${plan.patternLabel} / ${plan.altPatternLabel}';
    }
    final freq = plan.frequencyLabel;
    if (freq.isNotEmpty) dose = '$dose · $freq';
    final timing = plan.mealTiming == MealTiming.anytime
        ? ''
        : ' · ${plan.mealTiming.label.toLowerCase()}';
    return '$dose$timing';
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final actions = ref.read(planActionsProvider);
    switch (value) {
      case 'buy_online':
        showBuyMedicineOptionsSheet(context, plan: plan);
      case 'refill':
        final qty = await _askRefill(context);
        if (qty != null) await actions.refill(plan, qty);
      case 'edit_schedule':
        await _showAdjustScheduleSheet(context, ref, plan);
      case 'pause':
        await actions.pause(plan);
      case 'resume':
        await actions.resume(plan);
      case 'stop':
        await actions.stop(plan);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(trf('Delete {n}?', {'n': plan.name})),
            content: Text(
              tr(
                'This removes the medicine and all its history. This cannot be undone.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('Delete')),
              ),
            ],
          ),
        );
        if (ok == true) await actions.delete(plan);
    }
  }

  Future<double?> _askRefill(BuildContext context) {
    final controller = TextEditingController();
    final pack = plan.packQty;
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Refill {n}', {'n': plan.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('How many did you add?')),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(hintText: 'e.g. 10'),
            ),
            if (pack != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: ActionChip(
                  label: Text(trf('One pack ({n})', {'n': formatAmount(pack)})),
                  onPressed: () => Navigator.pop(ctx, pack),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: Text(tr('Add')),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjustScheduleSheet(
    BuildContext context,
    WidgetRef ref,
    MedicationPlan plan,
  ) async {
    final morningCtrl = TextEditingController(
      text: plan.slotAmounts[DaySlot.morning] != null
          ? formatAmount(plan.slotAmounts[DaySlot.morning]!)
          : '0',
    );
    final afternoonCtrl = TextEditingController(
      text: plan.slotAmounts[DaySlot.afternoon] != null
          ? formatAmount(plan.slotAmounts[DaySlot.afternoon]!)
          : '0',
    );
    final nightCtrl = TextEditingController(
      text: plan.slotAmounts[DaySlot.night] != null
          ? formatAmount(plan.slotAmounts[DaySlot.night]!)
          : '0',
    );
    var timing = plan.mealTiming;
    final reasonCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final t = ctx.textTheme;
          final scheme = ctx.colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('Adjust Schedule'),
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    plan.name,
                    style: t.bodyMedium?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr(
                      'Changes take effect from today. Past doses remain untouched.',
                    ),
                    style: t.bodySmall?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(tr('Dose amount:'), style: t.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: morningCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('Morning'),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TextField(
                          controller: afternoonCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('Afternoon'),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TextField(
                          controller: nightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: tr('Night'),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(tr('Food timing:'), style: t.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    children: MealTiming.values.map((mt) {
                      final selected = mt == timing;
                      return ChoiceChip(
                        label: Text(mt.label),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setModalState(() => timing = mt);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: tr('Reason for change (optional)'),
                      hintText: tr('e.g. Doctor adjusted evening dose'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(tr('Cancel')),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final m =
                                double.tryParse(morningCtrl.text.trim()) ?? 0;
                            final a =
                                double.tryParse(afternoonCtrl.text.trim()) ?? 0;
                            final n =
                                double.tryParse(nightCtrl.text.trim()) ?? 0;

                            final activeSlots = <DaySlot>{};
                            final amounts = <DaySlot, double>{};
                            if (m > 0) {
                              activeSlots.add(DaySlot.morning);
                              amounts[DaySlot.morning] = m;
                            }
                            if (a > 0) {
                              activeSlots.add(DaySlot.afternoon);
                              amounts[DaySlot.afternoon] = a;
                            }
                            if (n > 0) {
                              activeSlots.add(DaySlot.night);
                              amounts[DaySlot.night] = n;
                            }

                            if (activeSlots.isEmpty) return;

                            final reason = reasonCtrl.text.trim();
                            await ref
                                .read(planRepositoryProvider)
                                .updatePlanSchedule(
                                  planId: plan.id!,
                                  slotAmounts: amounts,
                                  mealTiming: timing,
                                  effectiveFrom: DateTime.now(),
                                  changeReason: reason.isNotEmpty
                                      ? reason
                                      : 'Patient / doctor adjustment',
                                );
                            ref.read(dataVersionProvider.notifier).bump();
                            await ref
                                .read(reminderServiceProvider)
                                .rescheduleAll();

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              context.showSnackBar(
                                tr(
                                  'Schedule updated. Past history is preserved.',
                                ),
                              );
                            }
                          },
                          child: Text(tr('Save')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
