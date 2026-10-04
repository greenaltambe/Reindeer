import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// All medicines: active first, then paused and stopped ones.
class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.add),
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: 'Something went wrong',
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (all) {
          if (all.isEmpty) {
            return EmptyStateView(
              title: 'No medicines yet',
              message: 'Medicines you add will be listed here.',
              illustration: const ReindeerMark(size: 96, interactive: true),
              actionLabel: 'Add medicine',
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
              for (final p in active) _PlanCard(plan: p),
              if (paused.isNotEmpty) ...[
                const SectionTitle('Paused'),
                for (final p in paused) _PlanCard(plan: p),
              ],
              if (stopped.isNotEmpty) ...[
                const SectionTitle('Stopped'),
                for (final p in stopped) _PlanCard(plan: p),
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
      PlanStatus.paused => ('Paused', false),
      PlanStatus.discontinued => ('Stopped', false),
      _ when plan.isLowStock => (
        plan.daysOfStockLeft == null
            ? 'Running low'
            : 'Running low · about ${plan.daysOfStockLeft!.floor()} day${plan.daysOfStockLeft!.floor() == 1 ? '' : 's'} left',
        true,
      ),
      _ when daysLeft != null && daysLeft <= 3 => (
        daysLeft == 0
            ? 'Course finished'
            : '$daysLeft day${daysLeft == 1 ? '' : 's'} left in course',
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
                tooltip: 'More',
                onSelected: (v) => _onMenu(context, ref, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'refill',
                    child: Text('Refill / update stock'),
                  ),
                  if (plan.isActive)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  if (!plan.isActive)
                    const PopupMenuItem(value: 'resume', child: Text('Resume')),
                  if (plan.status != PlanStatus.discontinued)
                    const PopupMenuItem(
                      value: 'stop',
                      child: Text('Stop (keep history)'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete everything'),
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
    final dose = amounts.length == 1
        ? plan.doseUnit.describe(amounts.first)
        : plan.doseSummary;
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
      case 'refill':
        final qty = await _askRefill(context);
        if (qty != null) await actions.refill(plan, qty);
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
            title: Text('Delete ${plan.name}?'),
            content: const Text(
              'This removes the medicine and all its history. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
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
        title: Text('Refill ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many did you add?'),
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
                  label: Text('One pack (${formatAmount(pack)})'),
                  onPressed: () => Navigator.pop(ctx, pack),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
