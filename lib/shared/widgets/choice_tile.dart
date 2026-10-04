import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/utils/context_extensions.dart';

/// A large, tappable, selectable tile. Used for the "easy" dose pickers so
/// that nothing needs typing.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
    this.icon,
    this.minHeight = 64,
  });

  final String label;
  final String? caption;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bg = selected ? scheme.primaryContainer : scheme.surface;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: caption == null ? label : '$label, $caption',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: AppSpacing.borderRadiusMd,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, color: fg),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title used in forms and lists.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(text, style: context.textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}
