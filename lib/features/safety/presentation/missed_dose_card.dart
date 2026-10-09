import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/safety/domain/missed_dose.dart';
import 'package:reindeer/features/safety/presentation/missed_reason_chips.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// Shown on a dose that is overdue: what to do, and a one-tap message to family.
class MissedDoseCard extends ConsumerWidget {
  const MissedDoseCard({super.key, required this.entry});

  final DoseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = entry.plan;
    final anchors = ref.watch(mealAnchorsProvider).value ?? const MealAnchors();
    final profile = ref.watch(profileProvider).value;
    final due = entry.dose.at;
    final now = DateTime.now();

    // The next planned dose of the same medicine after this one.
    DateTime? next;
    for (var i = 0; i < 3 && next == null; i++) {
      final day = DateTime(due.year, due.month, due.day + i);
      for (final d in plan.dosesOn(day, anchors)) {
        if (d.at.isAfter(due) && (next == null || d.at.isBefore(next))) {
          next = d.at;
        }
      }
    }

    final g = missedDoseGuidance(
      text: '${plan.name} ${plan.composition}',
      dueAt: due,
      now: now,
      nextDoseAt: next,
    );
    final scheme = context.colorScheme;
    final t = context.textTheme;
    final who = (profile?.name ?? '').trim();

    return Card(
      color: scheme.tertiaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: scheme.onTertiaryContainer),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  g.headline,
                  style: t.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final p in g.points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  p,
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            MissedReasonChips(entry: entry),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => SystemChannel.shareText(
                '${who.isEmpty ? 'Hi' : 'Hi, this is $who'}. I missed my ${plan.name} dose '
                'that was due at ${formatTime(due)}. Please check on me. (Sent from Reindeer)',
                title: tr('Tell my family'),
              ),
              icon: const Icon(Icons.family_restroom),
              label: Text(tr('Tell my family')),
            ),
          ],
        ),
      ),
    );
  }
}
