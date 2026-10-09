import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/language_provider.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';

/// Big, easy-to-tap language choices. Each is written in its own language so
/// it can be found even when the app is in a language the person cannot read.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final l in AppLanguage.values)
          ChoiceChip(
            label: Text(l.nativeName, style: context.textTheme.titleMedium),
            selected: l == current,
            showCheckmark: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            onSelected: (_) => ref.read(languageProvider.notifier).set(l),
          ),
      ],
    );
  }
}
