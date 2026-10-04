import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/conditions/presentation/condition_picker.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';

/// First-run flow, one question per page: welcome, name, birth year,
/// conditions, meal times, reminders. Only what the app really uses.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 6;

  int _step = 0;
  final _name = TextEditingController();
  final _year = TextEditingController();
  List<String> _conditions = [];
  MealAnchors _anchors = const MealAnchors();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  int? get _birthYear {
    final y = int.tryParse(_year.text.trim());
    if (y == null) return null;
    final now = DateTime.now().year;
    return (y >= 1900 && y <= now) ? y : null;
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  Future<void> _pick(String which) async {
    final current = switch (which) {
      'breakfast' => _anchors.breakfast,
      'lunch' => _anchors.lunch,
      _ => _anchors.dinner,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: 'When do you usually have $which?',
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      _anchors = switch (which) {
        'breakfast' => _anchors.copyWith(breakfast: minutes),
        'lunch' => _anchors.copyWith(lunch: minutes),
        _ => _anchors.copyWith(dinner: minutes),
      };
    });
  }

  Future<void> _finish({required bool askPermission}) async {
    setState(() => _busy = true);
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final profiles = ref.read(profileRepositoryProvider);
      await profiles.save(name: _name.text, birthYear: _birthYear);
      await profiles.setConditions(_conditions);
      await settings.saveMealAnchors(_anchors);
      await settings.set(SettingsRepository.keyOnboarded, '1');
      try {
        if (askPermission) {
          await ref.read(reminderServiceProvider).requestPermissions();
        }
        ref.read(dataVersionProvider.notifier).bump();
        await ref.read(reminderServiceProvider).rescheduleAll();
      } catch (_) {
        // Everything is saved; reminders can be fixed later from Settings.
      }
      if (mounted) context.go(AppRoutes.today);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showSnackBar('Could not finish setup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final page = switch (_step) {
      0 => StepScaffold(
        stepIndex: 0,
        stepCount: _steps,
        leading: const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ReindeerMark(size: 96, interactive: true),
        ),
        title: 'Welcome to Reindeer',
        subtitle:
            'Your medicine reminder. It keeps watch so you never miss a dose.',
        nextLabel: 'Get started',
        onNext: _next,
        child: Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Text(
              'Reindeer is a reminder tool. It does not give medical advice or check '
              'doses. Always follow your doctor\'s prescription.\n\n'
              'Everything stays on this phone.',
              style: t.bodyLarge,
            ),
          ),
        ),
      ),
      1 => StepScaffold(
        stepIndex: 1,
        stepCount: _steps,
        title: 'What should we call you?',
        subtitle: 'Just a first name, so your reindeer can say hello.',
        onBack: _back,
        onNext: _next,
        onSkip: _next,
        child: TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: t.titleLarge,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
      ),
      2 => StepScaffold(
        stepIndex: 2,
        stepCount: _steps,
        title: 'When were you born?',
        subtitle: 'Only the year. It is shown in the summary you can share with your doctor.',
        onBack: _back,
        onNext: _next,
        onSkip: _next,
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final y = _birthYear;
            final age = y == null ? null : DateTime.now().year - y;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _year,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: t.titleLarge,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'e.g. 1962',
                    counterText: '',
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
                if (age != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      age < 18
                          ? 'Under 18? Please set this up together with a parent or guardian.'
                          : 'Age about $age',
                      style: t.bodyLarge?.copyWith(color: scheme.primary),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      3 => StepScaffold(
        stepIndex: 3,
        stepCount: _steps,
        title: 'Any health conditions?',
        subtitle: 'Optional. It helps suggest what each medicine is for.',
        onBack: _back,
        onNext: _next,
        nextLabel: _conditions.isEmpty ? 'None right now' : 'Next',
        child: ConditionPicker(
          selected: _conditions,
          onChanged: (v) => setState(() => _conditions = v),
        ),
      ),
      4 => StepScaffold(
        stepIndex: 4,
        stepCount: _steps,
        title: 'When do you eat?',
        subtitle:
            'Many medicines go before or after food. Tap a time to change it.',
        onBack: _back,
        onNext: _next,
        child: Column(
          children: [
            for (final (label, which, minutes) in [
              ('Breakfast', 'breakfast', _anchors.breakfast),
              ('Lunch', 'lunch', _anchors.lunch),
              ('Dinner', 'dinner', _anchors.dinner),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Card(
                  child: ListTile(
                    title: Text(label, style: t.titleMedium),
                    trailing: Text(formatMinutes(minutes), style: t.titleLarge),
                    onTap: () => _pick(which),
                  ),
                ),
              ),
          ],
        ),
      ),
      _ => StepScaffold(
        stepIndex: 5,
        stepCount: _steps,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(
            Icons.notifications_active_outlined,
            size: 56,
            color: scheme.primary,
          ),
        ),
        title: 'Allow reminders',
        subtitle:
            'Reindeer needs permission to show notifications and ring on time.',
        onBack: _busy ? null : _back,
        nextLabel: 'Allow reminders',
        busy: _busy,
        onNext: () => _finish(askPermission: true),
        onSkip: () => _finish(askPermission: false),
        child: Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Text(
              'Tip: if reminders ever come late, set Reindeer to "Unrestricted" under '
              'phone Settings > Apps > Battery.',
              style: t.bodyLarge,
            ),
          ),
        ),
      ),
    };
    return Scaffold(body: page);
  }
}
