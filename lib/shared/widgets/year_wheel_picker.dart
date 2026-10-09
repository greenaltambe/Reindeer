import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';

/// Interactive scrolling wheel menu for selecting birth year.
class YearWheelPicker extends StatefulWidget {
  const YearWheelPicker({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
    this.minYear = 1920,
    this.maxYear,
  });

  final int? selectedYear;
  final ValueChanged<int> onYearChanged;
  final int minYear;
  final int? maxYear;

  @override
  State<YearWheelPicker> createState() => _YearWheelPickerState();
}

class _YearWheelPickerState extends State<YearWheelPicker> {
  late final int _maxYear = widget.maxYear ?? DateTime.now().year;
  late final List<int> _years = [
    for (int y = _maxYear; y >= widget.minYear; y--) y,
  ];

  late final FixedExtentScrollController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final initial = widget.selectedYear ?? (DateTime.now().year - 45); // default ~45 yo
    _currentIndex = _years.indexOf(initial);
    if (_currentIndex < 0) _currentIndex = _years.indexOf(1975);
    if (_currentIndex < 0) _currentIndex = 0;
    _controller = FixedExtentScrollController(initialItem: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final t = context.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center selection highlight band
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
              // Scroll wheel
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 44,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentIndex = index);
                  widget.onYearChanged(_years[index]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _years.length,
                  builder: (context, index) {
                    final year = _years[index];
                    final isSelected = index == _currentIndex;
                    final age = DateTime.now().year - year;

                    return Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$year',
                            style: (isSelected ? t.headlineSmall : t.titleMedium)?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? scheme.primary : scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trn(age, '({n} yr)', '({n} yrs)'),
                            style: t.bodySmall?.copyWith(
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.outlineVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows a modal bottom sheet with a scrolling wheel picker to choose birth year.
Future<int?> showYearWheelPickerSheet({
  required BuildContext context,
  required int? initialYear,
}) async {
  int tempYear = initialYear ?? (DateTime.now().year - 45);
  final scheme = context.colorScheme;
  final t = context.textTheme;

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Select Birth Year'),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('Scroll to select your year of birth.'),
              style: t.bodySmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: AppSpacing.md),
            YearWheelPicker(
              selectedYear: initialYear,
              onYearChanged: (y) => tempYear = y,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, tempYear),
                child: Text(tr('Done')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
