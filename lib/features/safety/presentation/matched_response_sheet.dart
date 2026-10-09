import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// Shows the matched barrier-aware response for the selected missed dose reason.
Future<void> showMatchedResponseSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DoseEntry entry,
  required MissReasonType reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MatchedResponseView(entry: entry, reason: reason),
  );
}

class _MatchedResponseView extends ConsumerStatefulWidget {
  const _MatchedResponseView({required this.entry, required this.reason});

  final DoseEntry entry;
  final MissReasonType reason;

  @override
  ConsumerState<_MatchedResponseView> createState() =>
      _MatchedResponseViewState();
}

class _MatchedResponseViewState extends ConsumerState<_MatchedResponseView> {
  final TextEditingController _noteController = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final plan = widget.entry.plan;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.reason.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.reason.label, style: t.titleLarge),
                        Text(
                          plan.name,
                          style: t.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ..._buildReasonContent(context, scheme, t),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('Done')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReasonContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme t,
  ) {
    final plan = widget.entry.plan;

    switch (widget.reason) {
      case MissReasonType.ranOut:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Need to refill?'),
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr(
                    'Running out of medicine is one of the most common reasons for missing doses. Keeping a buffer prevents interruption.',
                  ),
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(tr('I bought more')),
            onPressed: () async {
              final qty = await _askRefillQuantity(context, plan.packQty);
              if (qty != null && context.mounted) {
                await ref.read(planActionsProvider).refill(plan, qty);
                if (context.mounted) {
                  context.showSnackBar(
                    trf('Added {n} to stock', {'n': formatAmount(qty)}),
                  );
                }
              }
            },
          ),
          if (plan.composition.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.savings_outlined, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        trf(
                          'Generic option: Ask your chemist for Jan Aushadhi generic {n} which can cost 50-80% less.',
                          {'n': plan.composition},
                        ),
                        style: t.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ];

      case MissReasonType.sideEffect:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    tr(
                      'Tell your doctor: do not stop long-term medicines suddenly.',
                    ),
                    style: t.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(tr('Note for doctor (optional)'), style: t.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Felt dizzy, nausea, swelling...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(_saved ? Icons.check : Icons.save_outlined),
              label: Text(_saved ? tr('Saved') : tr('Save note for doctor')),
              onPressed: () async {
                final note = _noteController.text.trim();
                if (note.isNotEmpty) {
                  await ref
                      .read(missReasonRepositoryProvider)
                      .recordForDose(
                        dose: widget.entry.dose,
                        reason: widget.reason,
                        note: note,
                      );
                  setState(() => _saved = true);
                }
              },
            ),
          ),
        ];

      case MissReasonType.feltFine:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr(
                'Blood pressure and diabetes medicines protect your heart and kidneys quietly in the background, even when you feel healthy.',
              ),
              style: t.bodyMedium,
            ),
          ),
        ];

      case MissReasonType.forgot:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr(
                'Habit tip: tie your reminder to a daily meal or morning tea.',
              ),
              style: t.bodyMedium,
            ),
          ),
        ];

      case MissReasonType.cost:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Pradhan Mantri Jan Aushadhi Kendras offer quality generic medicines at 50% to 80% lower cost.',
                  ),
                  style: t.bodyMedium,
                ),
                if (plan.composition.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Salt: ${plan.composition}',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ];

      case MissReasonType.fastingTravel:
        return [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr(
                'During fasting or travel, talk to your doctor about adjusting dose timings rather than skipping.',
              ),
              style: t.bodyMedium,
            ),
          ),
        ];

      case MissReasonType.unknown:
        return [
          Text(
            tr(
              'Recording reason helps you and your doctor review what happened at your next visit.',
            ),
            style: t.bodyMedium,
          ),
        ];
    }
  }

  Future<double?> _askRefillQuantity(BuildContext context, double? packQty) {
    final controller = TextEditingController(
      text: packQty != null ? formatAmount(packQty) : '10',
    );
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('I bought more')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(labelText: tr('Tablets / units added')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: Text(tr('Add to stock')),
          ),
        ],
      ),
    );
  }
}
