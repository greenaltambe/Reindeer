import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/health/domain/reading_insight.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// A calm card explaining an unusual reading.
class ReadingFlagCard extends StatelessWidget {
  const ReadingFlagCard({super.key, required this.flag});

  final ReadingFlag flag;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (flag.level) {
      FlagLevel.urgent => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.warning_amber_rounded,
      ),
      FlagLevel.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.info_outline,
      ),
      FlagLevel.note => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.insights_outlined,
      ),
    };
    return Card(
      color: bg,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.title,
                    style: context.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(flag.message, style: TextStyle(color: fg)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    tr(
                      'Reindeer is not a doctor. This is a general guide, not a diagnosis.',
                    ),
                    style: context.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the flag after a reading was saved. Returns when the person closes it.
Future<void> showReadingFlag(BuildContext context, ReadingFlag flag) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Reading saved'), style: ctx.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ReadingFlagCard(flag: flag),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('OK')),
            ),
          ],
        ),
      ),
    ),
  );
}
