import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/care/application/care_sync.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/conditions/presentation/condition_picker.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/shared/widgets/language_picker.dart';
import 'package:reindeer/shared/widgets/year_wheel_picker.dart';

/// First-run flow, one question per page: welcome, who the phone is for,
/// name, birth year, conditions, meal times, reminders. Only what the app really uses.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 7;

  int _step = 0;
  final _name = TextEditingController();
  final _year = TextEditingController();
  List<String> _conditions = [];
  MealAnchors _anchors = const MealAnchors();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _year.text = '${DateTime.now().year - 45}';
  }

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
      helpText: trf('When do you usually have {n}?', {'n': tr(which)}),
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
      context.showSnackBar(trf('Could not finish setup: {n}', {'n': '$e'}));
    }
  }

  /// A caretaker-only phone needs none of the medicine questions: it goes
  /// straight to entering the code from the patient's phone.
  Future<void> _startAsCaretaker() async {
    setState(() => _busy = true);
    try {
      final settings = ref.read(settingsRepositoryProvider);
      await settings.set(keyCareMode, CareMode.caretaker.name);
      await settings.set(SettingsRepository.keyOnboarded, '1');
      ref.read(dataVersionProvider.notifier).bump();
      if (!mounted) return;
      context.go(AppRoutes.care);
      context.push(AppRoutes.familyJoin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showSnackBar(trf('Could not finish setup: {n}', {'n': '$e'}));
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
        title: tr('Welcome to Reindeer'),
        subtitle: tr(
          'Your medicine reminder. It keeps watch so you never miss a dose.',
        ),
        nextLabel: tr('Get started'),
        onNext: _next,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LanguagePicker(),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Text(
                  tr(
                    'Reindeer is a reminder tool. It does not give medical advice or check doses. Always follow your doctor\'s prescription.\n\nEverything stays on this phone.',
                  ),
                  style: t.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
      1 => StepScaffold(
        stepIndex: 1,
        stepCount: _steps,
        title: tr('How will you use Reindeer?'),
        subtitle: tr('You can change this later.'),
        onBack: _back,
        onNext: _next,
        nextEnabled: false,
        nextLabel: tr('Choose one'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoiceTile(
              icon: Icons.medication_outlined,
              label: tr('For my own medicines'),
              caption: tr('Reminders on this phone'),
              selected: false,
              minHeight: 96,
              onTap: _next,
            ),
            const SizedBox(height: AppSpacing.sm),
            ChoiceTile(
              icon: Icons.volunteer_activism_outlined,
              label: tr('To look after someone'),
              caption: tr('Get alerts about a parent or relative'),
              selected: false,
              minHeight: 96,
              onTap: _busy ? () {} : _startAsCaretaker,
            ),
          ],
        ),
      ),
      2 => StepScaffold(
        stepIndex: 2,
        stepCount: _steps,
        title: tr('What should we call you?'),
        subtitle: tr('Just a first name, so your reindeer can say hello.'),
        onBack: _back,
        onNext: _next,
        onSkip: _next,
        child: TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: t.titleLarge,
          decoration: InputDecoration(hintText: tr('Your name')),
        ),
      ),
      3 => StepScaffold(
        stepIndex: 3,
        stepCount: _steps,
        title: tr('When were you born?'),
        subtitle: tr(
          'Only the year. It is shown in the summary you can share with your doctor.',
        ),
        onBack: _back,
        onNext: _next,
        onSkip: _next,
        child: StatefulBuilder(
          builder: (context, setLocal) {
            final y = _birthYear;
            final age = y == null ? null : DateTime.now().year - y;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YearWheelPicker(
                  selectedYear: _birthYear ?? (DateTime.now().year - 45),
                  onYearChanged: (pickedYear) {
                    setLocal(() {
                      _year.text = '$pickedYear';
                    });
                  },
                ),
                if (age != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      age < 18
                          ? tr(
                              'Under 18? Please set this up together with a parent or guardian.',
                            )
                          : trf('Age about {n}', {'n': '$age'}),
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      4 => StepScaffold(
        stepIndex: 4,
        stepCount: _steps,
        title: tr('Any health conditions?'),
        subtitle: tr('Optional. It helps suggest what each medicine is for.'),
        onBack: _back,
        onNext: _next,
        nextLabel: _conditions.isEmpty ? tr('None right now') : tr('Next'),
        child: ConditionPicker(
          selected: _conditions,
          onChanged: (v) => setState(() => _conditions = v),
        ),
      ),
      5 => StepScaffold(
        stepIndex: 5,
        stepCount: _steps,
        title: tr('When do you eat?'),
        subtitle: tr(
          'Many medicines go before or after food. Tap a time to change it.',
        ),
        onBack: _back,
        onNext: _next,
        child: Column(
          children: [
            for (final (label, which, minutes) in [
              (tr('Breakfast'), 'breakfast', _anchors.breakfast),
              (tr('Lunch'), 'lunch', _anchors.lunch),
              (tr('Dinner'), 'dinner', _anchors.dinner),
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
        stepIndex: 6,
        stepCount: _steps,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(
            Icons.notifications_active_outlined,
            size: 56,
            color: scheme.primary,
          ),
        ),
        title: tr('Allow reminders'),
        subtitle: tr(
          'Reindeer needs permission to show notifications and ring on time.',
        ),
        onBack: _busy ? null : _back,
        nextLabel: tr('Allow reminders'),
        busy: _busy,
        onNext: () => _finish(askPermission: true),
        onSkip: () => _finish(askPermission: false),
        child: Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Text(
              tr(
                'Tip: if reminders ever come late, set Reindeer to "Unrestricted" under phone Settings > Apps > Battery.',
              ),
              style: t.bodyLarge,
            ),
          ),
        ),
      ),
    };
    return Scaffold(
      body: StepSwitcher(index: _step, child: page),
    );
  }
}
