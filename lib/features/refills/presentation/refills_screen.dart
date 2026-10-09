import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/refills/data/refill_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// Screen for tracking medicine stock, run-out forecasts, and recording refills.
class RefillsScreen extends ConsumerWidget {
  const RefillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final recentRefills = ref.watch(recentRefillsProvider);
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(tr('Refills'))),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Something went wrong'),
          message: '$e',
          icon: Icons.error_outline,
        ),
        data: (all) {
          final active = all.where((p) => p.isActive).toList();
          if (active.isEmpty) {
            return EmptyStateView(
              title: tr('No active medicines'),
              message: tr(
                'Medicines you add will have run-out forecasts here.',
              ),
              illustration: const ReindeerMark(size: 96, interactive: true),
              actionLabel: tr('Add medicine'),
              onAction: () => context.push(AppRoutes.add),
            );
          }

          final lowStockList = active.where((p) => p.isLowStock).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              96,
            ),
            children: [
              // Clean top summary alert
              if (lowStockList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    elevation: 0,
                    color: scheme.errorContainer.withValues(alpha: 0.7),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: scheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trn(
                                lowStockList.length,
                                '{n} medicine needs refill soon',
                                '{n} medicines need refill soon',
                              ),
                              style: t.titleSmall?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SectionTitle(tr('Medicines & Stock Forecast')),
              for (final (i, plan) in active.indexed)
                FadeSlideIn(
                  key: ValueKey('refill_plan_${plan.id}'),
                  index: i,
                  child: _StockForecastCard(plan: plan, now: now),
                ),

              const SizedBox(height: AppSpacing.md),
              SectionTitle(tr('Recent Refills')),
              recentRefills.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (history) {
                  if (history.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        tr(
                          'No refills recorded yet. Tap "I bought more" when you buy medicines.',
                        ),
                        style: t.bodyMedium?.copyWith(color: scheme.outline),
                      ),
                    );
                  }
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: Column(
                      children: [
                        for (final r in history.take(5))
                          ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              r.planName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(formatDayLabel(r.at, now)),
                            trailing: Text(
                              '+${r.doseUnit.describe(r.quantity)}',
                              style: t.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StockForecastCard extends ConsumerWidget {
  const _StockForecastCard({required this.plan, required this.now});

  final MedicationPlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final days = plan.daysOfStockLeft;
    final stock = plan.stock;

    late final Color statusColor;
    late final String statusLabel;

    if (stock == null) {
      statusColor = scheme.outline;
      statusLabel = tr('Untracked');
    } else if (days != null && days <= 3) {
      statusColor = scheme.error;
      statusLabel = trn(
        days.floor(),
        'About {n} day left',
        'About {n} days left',
      );
    } else if (days != null && days <= 7) {
      statusColor = Colors.orange;
      statusLabel = trn(
        days.floor(),
        'About {n} day left',
        'About {n} days left',
      );
    } else {
      statusColor = Colors.green;
      statusLabel = days != null
          ? trn(days.floor(), '{n} day of stock', '{n} days of stock')
          : tr('In stock');
    }

    final projectedDate = (days != null && days > 0)
        ? now.add(Duration(days: days.floor()))
        : null;

    final isCritical = days != null && days <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isCritical
              ? scheme.error.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: t.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            stock != null ? formatAmount(stock) : '--',
                            style: t.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plan.doseUnit.label,
                            style: t.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${tr('Daily usage')}: ${plan.doseUnit.describe(plan.averageDailyAmount)}${projectedDate != null ? ' · ${tr('Ends')} ${formatDayLabel(projectedDate, now)}' : ''}',
                        style: t.bodySmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showRefillModal(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('I bought more')),
                ),
              ],
            ),
            if (days != null && days > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (days / 30.0).clamp(0.04, 1.0),
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: statusColor,
                  minHeight: 5,
                ),
              ),
            ],
            if (plan.composition.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  context.showSnackBar(
                    trf(
                      'Jan Aushadhi generic: {n} is available at PMBJP stores for savings.',
                      {'n': plan.composition},
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Jan Aushadhi: ${plan.composition}',
                        style: t.labelSmall?.copyWith(color: scheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRefillModal(BuildContext context, WidgetRef ref) async {
    final pack = plan.packQty;
    final controller = TextEditingController(
      text: pack != null ? formatAmount(pack) : '10',
    );

    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Refill {n}', {'n': plan.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('How many did you buy?')),
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
              decoration: InputDecoration(
                labelText: tr('Quantity added'),
                suffixText: plan.doseUnit.label,
              ),
            ),
            if (pack != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: ActionChip(
                  label: Text(
                    trf('Standard pack ({n})', {'n': formatAmount(pack)}),
                  ),
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
            child: Text(tr('Add stock')),
          ),
        ],
      ),
    );

    if (qty != null && context.mounted) {
      await ref.read(planActionsProvider).refill(plan, qty);
      if (context.mounted) {
        context.showSnackBar(
          trf('Added {n} to stock', {'n': formatAmount(qty)}),
        );
      }
    }
  }
}
