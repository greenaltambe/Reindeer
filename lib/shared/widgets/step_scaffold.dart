import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';

/// One page of a step-by-step flow: progress bar, a single question, content,
/// and Back / Next (and optionally Skip) buttons.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.stepIndex,
    required this.stepCount,
    required this.title,
    required this.child,
    required this.onNext,
    this.subtitle,
    this.onBack,
    this.onSkip,
    this.nextLabel = 'Next',
    this.nextEnabled = true,
    this.leading,
    this.busy = false,
  });

  final int stepIndex;
  final int stepCount;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final String nextLabel;
  final bool nextEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  const SizedBox(width: 48, height: 48),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: (stepIndex + 1) / stepCount,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?leading,
                    Text(title, style: context.textTheme.headlineLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: context.textTheme.bodyLarge),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    child,
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: nextEnabled && !busy ? onNext : null,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(nextLabel),
              ),
            ),
            if (onSkip != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: busy ? null : onSkip,
                  child: const Text('Skip'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
