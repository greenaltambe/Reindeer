import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/allergy/domain/allergy.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// "You told us you are allergic to ..." card.
class AllergyWarningCard extends StatelessWidget {
  const AllergyWarningCard({super.key, required this.matches});

  final List<AllergyMatch> matches;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final names = {for (final m in matches) m.allergy}.join(', ');
    final ingredients = {for (final m in matches) m.ingredient}.join(', ');
    return Card(
      color: scheme.errorContainer,
      margin: EdgeInsets.zero,
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
                    tr('Possible allergy'),
                    style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'You noted an allergy to $names. This medicine contains $ingredients. '
                    'Ask your doctor or pharmacist before taking it.',
                    style: TextStyle(color: scheme.onErrorContainer),
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
