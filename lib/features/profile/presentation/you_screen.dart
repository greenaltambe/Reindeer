import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/routine/application/routine_providers.dart';
import 'package:reindeer/features/routine/domain/routine_learning.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/core/i18n/strings.dart';

String _mealName(DaySlot slot) => switch (slot) {
  DaySlot.morning => tr('breakfast time'),
  DaySlot.afternoon => tr('lunch time'),
  DaySlot.night => tr('dinner time'),
};

/// "You": personal details, health conditions and meal times. App settings are
/// one tap away on the gear.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

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
      helpText: trf('When do you usually have {n}?', {'n': tr(which)}),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    final next = switch (which) {
      'breakfast' => anchors.copyWith(breakfast: minutes),
      'lunch' => anchors.copyWith(lunch: minutes),
      _ => anchors.copyWith(dinner: minutes),
    };
    await ref.read(settingsRepositoryProvider).saveMealAnchors(next);
    await ref
        .read(settingsRepositoryProvider)
        .set(keyRoutineFrom, DateTime.now().toIso8601String());
    ref.read(dataVersionProvider.notifier).bump();
    // Doses are tied to meals, so every reminder moves.
    await ref.read(reminderServiceProvider).rescheduleAll();
  }

  Future<void> _applyRoutine(
    WidgetRef ref,
    MealAnchors anchors,
    RoutineSuggestion r,
  ) async {
    final next = switch (r.slot) {
      DaySlot.morning => anchors.copyWith(breakfast: r.suggestedMinutes),
      DaySlot.afternoon => anchors.copyWith(lunch: r.suggestedMinutes),
      DaySlot.night => anchors.copyWith(dinner: r.suggestedMinutes),
    };
    final settings = ref.read(settingsRepositoryProvider);
    await settings.saveMealAnchors(next);
    await settings.set(keyRoutineFrom, DateTime.now().toIso8601String());
    ref.read(dataVersionProvider.notifier).bump();
    await ref.read(reminderServiceProvider).rescheduleAll();
  }

  Future<void> _dismissRoutine(WidgetRef ref) async {
    await ref
        .read(settingsRepositoryProvider)
        .set(keyRoutineFrom, DateTime.now().toIso8601String());
    ref.read(dataVersionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final profile = ref.watch(profileProvider).value;
    final conditions =
        ref.watch(profileConditionsProvider).value ?? const <String>[];
    final anchors = ref.watch(mealAnchorsProvider).value ?? const MealAnchors();
    final allergies = ref.watch(allergiesProvider).value ?? const <String>[];
    final routine =
        ref.watch(routineSuggestionsProvider).value ??
        const <RoutineSuggestion>[];

    final name = profile?.name ?? '';
    final age = profile?.ageAt(DateTime.now());
    final details = [
      if (age != null) trf('Age {n}', {'n': '$age'}),
      if (profile?.heightCm != null) '${profile!.heightCm!.round()} cm',
    ].join(' · ');

    Widget mealTile(String label, String which, int minutes) => ListTile(
      title: Text(label),
      trailing: Text(formatMinutes(minutes), style: t.titleMedium),
      onTap: () => _pickMeal(context, ref, anchors, which),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('You')),
        actions: [
          IconButton(
            tooltip: tr('App settings'),
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          FadeSlideIn(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    const ReindeerMark(size: 64, interactive: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? tr('Your details') : name,
                            style: t.headlineSmall,
                          ),
                          Text(
                            details.isEmpty
                                ? tr('Add your birth year and height')
                                : details,
                            style: t.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => context.push(AppRoutes.profile),
                      child: Text(tr('Edit')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SectionTitle(tr('Health conditions')),
          FadeSlideIn(
            index: 1,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: AppSpacing.borderRadiusLg,
                onTap: () => context.push(AppRoutes.profile),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: conditions.isEmpty
                      ? Text(
                          tr('None added. Tap to add.'),
                          style: t.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final c in conditions) Chip(label: Text(c)),
                          ],
                        ),
                ),
              ),
            ),
          ),
          SectionTitle(tr('Allergies')),
          FadeSlideIn(
            index: 2,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: AppSpacing.borderRadiusLg,
                onTap: () => context.push(AppRoutes.allergies),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: allergies.isEmpty
                      ? Text(
                          tr(
                            'None added. Tap to add medicines you are allergic to.',
                          ),
                          style: t.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final a in allergies)
                              Chip(
                                label: Text(a),
                                backgroundColor: scheme.errorContainer,
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            index: 3,
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.vaccines_outlined),
                    title: Text(tr('TB care (DOTS)')),
                    subtitle: Text(
                      tr(
                        'Six-month course with a supporter who watches each dose',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.tb),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(tr('Medical ID')),
                    subtitle: Text(
                      tr('Allergies, conditions and medicines on one page'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.medicalId),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sentiment_satisfied_outlined),
                    title: Text(tr('How I feel')),
                    subtitle: Text(tr('Symptom diary')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.symptoms),
                  ),
                ],
              ),
            ),
          ),
          for (final r in routine)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Card(
                margin: EdgeInsets.zero,
                color: scheme.tertiaryContainer,
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              tr('Your routine'),
                              style: t.titleMedium?.copyWith(
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        trf(
                          'You usually take your {slot} medicines around {to}, but your {meal} is set to {from}. Move reminders to match?',
                          {
                            'slot': r.slot.label.toLowerCase(),
                            'to': formatMinutes(r.suggestedMinutes),
                            'meal': tr(_mealName(r.slot)),
                            'from': formatMinutes(r.currentMinutes),
                          },
                        ),
                        style: t.bodyLarge?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _dismissRoutine(ref),
                            child: Text(tr('Not now')),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => _applyRoutine(ref, anchors, r),
                            child: Text(
                              trf('Use {n}', {
                                'n': formatMinutes(r.suggestedMinutes),
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SectionTitle(tr('Meal times')),
          FadeSlideIn(
            index: 4,
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  mealTile(tr('Breakfast'), 'breakfast', anchors.breakfast),
                  const Divider(height: 1),
                  mealTile(tr('Lunch'), 'lunch', anchors.lunch),
                  const Divider(height: 1),
                  mealTile(tr('Dinner'), 'dinner', anchors.dinner),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      tr(
                        'Morning, afternoon and night doses follow these. "After food" reminds you 30 minutes after the meal, "before food" 30 minutes before.',
                      ),
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            index: 5,
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(tr('App settings')),
                subtitle: Text(tr('Reminders, appearance, about')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.settings),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
