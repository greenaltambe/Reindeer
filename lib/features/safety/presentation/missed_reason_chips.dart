import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/safety/presentation/matched_response_sheet.dart';

/// One-tap reason chips shown for missed or skipped doses.
class MissedReasonChips extends ConsumerWidget {
  const MissedReasonChips({super.key, required this.entry});

  final DoseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final repo = ref.watch(missReasonRepositoryProvider);

    return FutureBuilder<MissReason?>(
      future: repo.forDose(entry.dose),
      builder: (context, snapshot) {
        final existing = snapshot.data;

        if (existing != null && existing.reason != MissReasonType.unknown) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  existing.reason.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${tr('Why was it missed?')}: ${existing.reason.label}',
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => showMatchedResponseSheet(
                    context: context,
                    ref: ref,
                    entry: entry,
                    reason: existing.reason,
                  ),
                  child: Text(tr('Details')),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Why was it missed?'),
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final r in [
                  MissReasonType.forgot,
                  MissReasonType.ranOut,
                  MissReasonType.sideEffect,
                  MissReasonType.feltFine,
                  MissReasonType.cost,
                  MissReasonType.fastingTravel,
                ])
                  ActionChip(
                    avatar: Text(r.emoji, style: const TextStyle(fontSize: 14)),
                    label: Text(r.label),
                    onPressed: () async {
                      await repo.recordForDose(dose: entry.dose, reason: r);
                      if (context.mounted) {
                        await showMatchedResponseSheet(
                          context: context,
                          ref: ref,
                          entry: entry,
                          reason: r,
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
