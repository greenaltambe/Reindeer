import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/trend_chart.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// Icons for each reading.
extension MeasureTypeIcon on MeasureType {
  IconData get icon => switch (this) {
    MeasureType.weight => Icons.monitor_weight_outlined,
    MeasureType.bloodPressure => Icons.favorite_border,
    MeasureType.glucose => Icons.water_drop_outlined,
    MeasureType.bodyFat => Icons.percent,
    MeasureType.pulse => Icons.monitor_heart_outlined,
  };
}

/// The Health tab: one card per reading with the latest value and a trend.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Health'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.sentiment_satisfied_outlined),
                  title: Text(tr('How I feel')),
                  subtitle: Text(
                    tr('Symptoms and side effects, for your doctor'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.symptoms),
                ),
              ),
            ),
          ),
          for (final (i, type) in MeasureType.values.indexed)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _MetricCard(type: type),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'Readings stay on this phone. Reindeer points out unusual readings as a general guide, not a diagnosis. Ask your doctor what is right for you.',
            ),
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends ConsumerWidget {
  const _MetricCard({required this.type});

  final MeasureType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final list =
        ref.watch(measurementsProvider(type)).value ?? const <Measurement>[];
    final latest = list.isEmpty ? null : list.first;
    final recent = list.take(14).toList().reversed.toList();
    final now = DateTime.now();

    return Card(
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: () => context.push('/health/${type.name}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(type.icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: t.titleMedium),
                    if (latest == null)
                      Text(tr('No readings yet'), style: t.bodyMedium)
                    else ...[
                      Text(latest.display, style: t.titleLarge),
                      Text(agoText(latest.at, now), style: t.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (recent.length > 1)
                SizedBox(
                  width: 80,
                  child: TrendChart(
                    compact: true,
                    times: [for (final m in recent) m.at],
                    values: [for (final m in recent) m.value],
                    second: type.hasSecond
                        ? [for (final m in recent) m.value2 ?? m.value]
                        : null,
                  ),
                ),
              IconButton.filledTonal(
                tooltip: trf('Add {n} reading', {
                  'n': type.label.toLowerCase(),
                }),
                onPressed: () => context.push('/health/${type.name}/add'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
