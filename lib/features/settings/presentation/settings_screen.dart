import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_constants.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/theme/theme_provider.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

/// Meal times, reminder health check, appearance and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pickMeal(
    BuildContext context,
    WidgetRef ref,
    MealAnchors anchors,
    String which,
  ) async {
    final current = switch (which) {
      'breakfast' => anchors.breakfast,
      'lunch' => anchors.lunch,
      _ => anchors.dinner,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: 'When do you usually have $which?',
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    final next = switch (which) {
      'breakfast' => anchors.copyWith(breakfast: minutes),
      'lunch' => anchors.copyWith(lunch: minutes),
      _ => anchors.copyWith(dinner: minutes),
    };
    await ref.read(settingsRepositoryProvider).saveMealAnchors(next);
    ref.read(dataVersionProvider.notifier).bump();
    // Doses are tied to meals, so every reminder moves.
    await ref.read(reminderServiceProvider).rescheduleAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final anchors = ref.watch(mealAnchorsProvider).value ?? const MealAnchors();
    final health = ref.watch(reminderHealthProvider).value;
    final t = context.textTheme;

    Widget mealTile(String label, String which, int minutes) => ListTile(
      title: Text(label),
      trailing: Text(formatMinutes(minutes), style: t.titleMedium),
      onTap: () => _pickMeal(context, ref, anchors, which),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                ref.watch(profileProvider).value?.name.isNotEmpty == true
                    ? ref.watch(profileProvider).value!.name
                    : 'Your profile',
              ),
              subtitle: const Text('Name, birth year, height, conditions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.profile),
            ),
          ),
          const SectionTitle('Meal times'),
          Card(
            child: Column(
              children: [
                mealTile('Breakfast', 'breakfast', anchors.breakfast),
                const Divider(),
                mealTile('Lunch', 'lunch', anchors.lunch),
                const Divider(),
                mealTile('Dinner', 'dinner', anchors.dinner),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Morning, afternoon and night doses follow these. "After food" reminds you '
                    '30 minutes after the meal, "before food" 30 minutes before.',
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Reminders'),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HealthRow(
                    ok: health?.notificationsEnabled,
                    label: 'Notifications allowed',
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _HealthRow(
                    ok: health?.exactAlarms,
                    label: 'Exact-time reminders allowed',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (health != null && !health.allGood)
                        FilledButton(
                          onPressed: () async {
                            await ref
                                .read(reminderServiceProvider)
                                .requestPermissions();
                            ref.invalidate(reminderHealthProvider);
                          },
                          child: const Text('Fix permissions'),
                        ),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(reminderServiceProvider).showTest(),
                        child: const Text('Send a test reminder'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'If reminders arrive late, open your phone\'s Settings > Apps > Reindeer > '
                    'Battery and choose "Unrestricted".',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(s.first),
                ),
              ),
            ),
          ),
          const SectionTitle('About'),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ReindeerMark(size: 48, interactive: true),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${AppConstants.appName} ${AppConstants.appVersion}',
                          style: t.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reindeer is a reminder tool. It does not give medical advice and does not '
                    'check doses or interactions. Always follow your doctor\'s prescription.\n\n'
                    'Medicine details come from public lists (a community medicine dataset and the '
                    'Jan Aushadhi product list) and may be incomplete or out of date.\n\n'
                    'All your data stays on this phone. There is no account and nothing is uploaded.',
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.ok, required this.label});

  final bool? ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (IconData icon, Color color) = switch (ok) {
      true => (Icons.check_circle, scheme.primary),
      false => (Icons.error_outline, scheme.error),
      null => (Icons.hourglass_empty, scheme.outline),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: context.textTheme.bodyLarge),
      ],
    );
  }
}
