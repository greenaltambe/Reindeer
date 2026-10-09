import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/core/utils/reindeer_voice.dart';
import 'package:reindeer/features/adherence/application/dose_actions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/care/presentation/care_home_screen.dart';
import 'package:reindeer/features/care/presentation/help_sheet.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/safety/presentation/missed_dose_card.dart';
import 'package:reindeer/features/symptoms/presentation/symptom_diary_screen.dart';
import 'package:reindeer/features/tb/data/tb_repository.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';
import 'package:reindeer/features/today/application/day_providers.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/safety/presentation/matched_response_sheet.dart';
import 'package:reindeer/features/refills/data/refill_repository.dart';
import 'package:reindeer/features/symptoms/data/symptom_repository.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';

/// The main screen: a week calendar on top and the chosen day's doses below,
/// grouped by time. Health-reading reminders appear here too.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  static const _anchorPage = 520;
  late final DateTime _anchorWeek = startOfWeek(DateTime.now());
  late final PageController _pages = PageController(initialPage: _anchorPage);

  int _pageOf(DateTime day) {
    final days = startOfWeek(day).difference(_anchorWeek).inHours / 24;
    return _anchorPage + (days / 7).round();
  }

  DateTime _weekStartOf(int page) {
    final w = _anchorWeek;
    return DateTime(w.year, w.month, w.day + (page - _anchorPage) * 7);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onSwipe(int page) {
    final selected = ref.read(selectedDayProvider);
    if (_pageOf(selected) == page) return;
    final start = _weekStartOf(page);
    ref
        .read(selectedDayProvider.notifier)
        .select(
          DateTime(start.year, start.month, start.day + selected.weekday % 7),
        );
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: Text(tr('Medicine')),
                subtitle: Text(
                  tr('Search by name or type a prescription line'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.add);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_satisfied_outlined),
                title: Text(tr('How I feel')),
                subtitle: Text(tr('Log a symptom or side effect')),
                onTap: () {
                  Navigator.pop(ctx);
                  showLogSymptomSheet(context);
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  tr('Health reading'),
                  style: context.textTheme.titleSmall,
                ),
              ),
              for (final type in MeasureType.values)
                ListTile(
                  leading: Icon(type.icon),
                  title: Text(type.label),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/health/${type.name}/add');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final selected = ref.watch(selectedDayProvider);
    final today = dateOnly(now);
    final isToday = selected == today;

    ref.listen<DateTime>(selectedDayProvider, (prev, next) {
      final page = _pageOf(next);
      if (_pages.hasClients && (_pages.page ?? page).round() != page) {
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });

    final dayNumber = selected.difference(DateTime(2020)).inHours ~/ 24;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDayLabel(selected, now)),
            Text(formatLongDate(selected), style: context.textTheme.bodyMedium),
          ],
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: child),
            ),
            child: isToday
                ? const SizedBox.shrink(key: ValueKey('none'))
                : TextButton.icon(
                    key: const ValueKey('jump'),
                    onPressed: () =>
                        ref.read(selectedDayProvider.notifier).reset(),
                    icon: const Icon(Icons.today),
                    label: Text(tr('Today')),
                  ),
          ),
          const HelpButton(),
          IconButton(
            tooltip: tr('App settings'),
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(tr('Add')),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 84,
            child: PageView.builder(
              controller: _pages,
              onPageChanged: _onSwipe,
              itemBuilder: (context, page) =>
                  _WeekPage(weekStart: _weekStartOf(page), today: today),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StepSwitcher(
              index: dayNumber,
              child: _DayView(day: selected, now: now),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week strip

class _WeekPage extends ConsumerWidget {
  const _WeekPage({required this.weekStart, required this.today});

  final DateTime weekStart;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final entries =
        ref.watch(weekEntriesProvider(weekStart)).value ?? const <DoseEntry>[];
    final symptoms =
        ref.watch(symptomsProvider).value ?? const <SymptomEntry>[];
    final scheme = context.colorScheme;

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final day = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + i,
              );
              final dayEntries = [
                for (final e in entries)
                  if (isSameDay(e.dose.at, day)) e,
              ];
              final hasMissed = dayEntries.any(
                (e) => e.status == DoseStatus.missed,
              );
              final allDone =
                  dayEntries.isNotEmpty && dayEntries.every((e) => !e.isOpen);
              final hasSymptom = symptoms.any((s) => isSameDay(s.at, day));
              final isSelected = day == selected;
              final isToday = day == today;
              final ringColor = hasMissed
                  ? scheme.error
                  : allDone
                  ? scheme.primary
                  : isToday
                  ? scheme.primary
                  : scheme.outlineVariant;
              return Expanded(
                child: InkWell(
                  borderRadius: AppSpacing.borderRadiusMd,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedDayProvider.notifier).select(day);
                  },
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: formatLongDate(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formatWeekdayShort(day),
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? scheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? scheme.primary : ringColor,
                              width:
                                  isSelected || hasMissed || allDone || isToday
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: Text(
                            '${day.day}',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (hasSymptom) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? scheme.primary
                                  : Colors.purple.shade700,
                            ),
                          ),
                        ] else
                          const SizedBox(height: 7),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One day

/// A dose or a reading reminder, as one row on the day list.
class _Row {
  const _Row.dose(this.dose) : task = null, symptom = null, refill = null;
  const _Row.task(this.task) : dose = null, symptom = null, refill = null;
  const _Row.symptom(this.symptom) : dose = null, task = null, refill = null;
  const _Row.refill(this.refill) : dose = null, task = null, symptom = null;

  final DoseEntry? dose;
  final MeasureTask? task;
  final SymptomEntry? symptom;
  final RefillRecord? refill;

  DateTime get at => dose?.dose.at ?? task?.at ?? symptom?.at ?? refill!.at;
  bool get resolved => dose != null
      ? !dose!.isOpen
      : task != null
      ? task!.done
      : true;
  String get key => dose != null
      ? 'd${dose!.plan.id}-${dose!.dose.key}'
      : task != null
      ? 't${task!.type.name}'
      : symptom != null
      ? 's${symptom!.id ?? symptom!.at.millisecondsSinceEpoch}'
      : 'r${refill!.id}';
}

class _DayView extends ConsumerStatefulWidget {
  const _DayView({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  bool _showResolved = true;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final now = widget.now;
    final plans = ref.watch(plansProvider);
    final doses = ref.watch(dayEntriesProvider(day));
    final tasks = ref.watch(dayMeasureTasksProvider(day));
    final symptoms = ref.watch(daySymptomsProvider(day));
    final refills = ref.watch(dayRefillsProvider(day));
    final isToday = day == dateOnly(now);
    final isFuture = day.isAfter(dateOnly(now));

    return plans.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyStateView(
        title: tr('Something went wrong'),
        message: '$e',
        icon: Icons.error_outline,
      ),
      data: (all) {
        final taskList = tasks.value ?? const <MeasureTask>[];
        final symptomList = symptoms.value ?? const <SymptomEntry>[];
        final refillList = refills.value ?? const <RefillRecord>[];
        if (all.isEmpty &&
            taskList.isEmpty &&
            symptomList.isEmpty &&
            refillList.isEmpty) {
          return EmptyStateView(
            title: tr('No medicines yet'),
            message:
                '${ReindeerVoice.nothingYet} Add your first medicine and we will remind you when it is time.',
            illustration: const ReindeerMark(size: 96, interactive: true),
            actionLabel: tr('Add medicine'),
            onAction: () => context.push(AppRoutes.add),
          );
        }
        final rows = [
          for (final e in doses.value ?? const <DoseEntry>[]) _Row.dose(e),
          for (final t in taskList) _Row.task(t),
          for (final s in symptomList) _Row.symptom(s),
          for (final r in refillList) _Row.refill(r),
        ]..sort((a, b) => a.at.compareTo(b.at));
        final open = [
          for (final r in rows)
            if (!r.resolved) r,
        ];
        final resolved = [
          for (final r in rows)
            if (r.resolved) r,
        ];
        final low = all.where((p) => isToday && p.isLowStock).toList();
        final hadDoses = (doses.value ?? const <DoseEntry>[]).isNotEmpty;

        // Group the open rows by minute.
        final groups = <DateTime, List<_Row>>{};
        for (final r in open) {
          final k = DateTime(
            r.at.year,
            r.at.month,
            r.at.day,
            r.at.hour,
            r.at.minute,
          );
          groups.putIfAbsent(k, () => []).add(r);
        }

        var index = 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            96,
          ),
          children: [
            if (isToday) const _PermissionBanner(),
            if (isToday) const FamilyTodayStrip(),
            if (isToday) const _TbBanner(),
            if (low.isNotEmpty)
              FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LowStockBanner(
                    name: low.first.name,
                    daysLeft: low.first.daysOfStockLeft,
                    onTap: () => context.go(AppRoutes.medicines),
                  ),
                ),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  isFuture
                      ? tr('Nothing planned for this day.')
                      : tr('Nothing was due on this day.'),
                  style: context.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            if (open.isEmpty && hadDoses && isToday)
              const FadeSlideIn(child: _AllDoneCard()),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  formatTime(entry.key),
                  style: context.textTheme.titleMedium?.copyWith(
                    color:
                        entry.value.any(
                          (r) =>
                              r.dose?.status == DoseStatus.missed ||
                              (r.task != null && r.at.isBefore(now)),
                        )
                        ? context.colorScheme.error
                        : context.colorScheme.onSurface,
                  ),
                ),
              ),
              for (final r in entry.value)
                FadeSlideIn(
                  key: ValueKey(r.key),
                  index: index++,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _RowCard(row: r, now: now, canAct: !isFuture),
                  ),
                ),
            ],
            if (resolved.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: AppSpacing.borderRadiusMd,
                onTap: () => setState(() => _showResolved = !_showResolved),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          trf('Done ({n})', {'n': '${resolved.length}'}),
                          style: context.textTheme.titleMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _showResolved ? 0 : 0.5,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Icons.keyboard_arrow_up),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _showResolved
                    ? Column(
                        children: [
                          for (final r in resolved)
                            FadeSlideIn(
                              key: ValueKey(r.key),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _RowCard(
                                  row: r,
                                  now: now,
                                  canAct: !isFuture,
                                  showTime: true,
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        );
      },
    );
  }
}

IconData _doseIcon(DoseUnit u) => switch (u) {
  DoseUnit.tablet => Icons.medication_outlined,
  DoseUnit.capsule => Icons.medication_liquid_outlined,
  DoseUnit.ml => Icons.science_outlined,
  DoseUnit.drops => Icons.water_drop_outlined,
  DoseUnit.puffs => Icons.air,
  DoseUnit.units || DoseUnit.injection => Icons.vaccines_outlined,
  DoseUnit.application => Icons.healing_outlined,
  DoseUnit.sachet => Icons.inventory_2_outlined,
};

class _RowCard extends ConsumerWidget {
  const _RowCard({
    required this.row,
    required this.now,
    required this.canAct,
    this.showTime = false,
  });

  final _Row row;
  final DateTime now;
  final bool canAct;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final t = context.textTheme;
    final dose = row.dose;
    final task = row.task;
    final symptom = row.symptom;
    final refill = row.refill;

    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final _CircleState state;
    late final VoidCallback onCircle;
    late final VoidCallback onCard;
    var overdue = false;

    if (dose != null) {
      final plan = dose.plan;
      final timing = plan.mealTiming == MealTiming.anytime
          ? ''
          : ' · ${plan.mealTiming.label.toLowerCase()}';
      icon = _doseIcon(plan.doseUnit);
      title = plan.name;
      String? watcher;
      if (plan.condition == tbCondition) {
        final seen = ref.watch(tbObservationsProvider).value;
        watcher = seen == null ? null : seen[dose.dose.key];
      }
      subtitle =
          '${showTime ? '${formatTime(dose.dose.at)} · ' : ''}${plan.doseUnit.describe(dose.dose.amount)}$timing${watcher == null ? '' : ' · ${trf('Watched by {n}', {'n': watcher})}'}';
      overdue = dose.status == DoseStatus.missed;
      state = switch (dose.status) {
        DoseStatus.taken => _CircleState.done,
        DoseStatus.skipped => _CircleState.skipped,
        _ => overdue ? _CircleState.overdue : _CircleState.open,
      };
      final actions = ref.read(doseActionsProvider);
      onCircle = () {
        if (!canAct) return;
        HapticFeedback.mediumImpact();
        if (dose.isOpen) {
          actions.take(dose.dose);
        } else {
          actions.undo(dose.dose);
        }
      };
      onCard = () => _showDoseSheet(context, ref, dose, canAct);
    } else if (task != null) {
      final type = task.type;
      icon = type.icon;
      title = trf('Check your {n}', {'n': type.label.toLowerCase()});
      subtitle = task.done
          ? '${showTime ? '${formatTime(task.at)} · ' : ''}${task.reading!.display}'
          : tr('Health reminder');
      overdue = !task.done && task.at.isBefore(now);
      state = task.done
          ? _CircleState.done
          : (overdue ? _CircleState.overdue : _CircleState.open);
      onCircle = () => context.push('/health/${type.name}/add');
      onCard = () => context.push(
        task.done ? '/health/${type.name}' : '/health/${type.name}/add',
      );
    } else if (symptom != null) {
      icon = Icons.sentiment_dissatisfied_outlined;
      title = symptom.symptom;
      final noteStr = (symptom.note != null && symptom.note!.trim().isNotEmpty)
          ? ' · "${symptom.note!.trim()}"'
          : '';
      subtitle =
          '${showTime ? '${formatTime(symptom.at)} · ' : ''}${symptom.severity.label}$noteStr';
      overdue = false;
      state = _CircleState.done;
      onCircle = () => context.push(AppRoutes.symptoms);
      onCard = () => context.push(AppRoutes.symptoms);
    } else {
      final r = refill!;
      icon = Icons.inventory_2_outlined;
      title = trf('Refilled {n}', {'n': r.planName});
      subtitle =
          '${showTime ? '${formatTime(r.at)} · ' : ''}+${r.doseUnit.describe(r.quantity)}';
      overdue = false;
      state = _CircleState.done;
      onCircle = () => context.go(AppRoutes.refills);
      onCard = () => context.go(AppRoutes.refills);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLg,
        onTap: onCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: symptom != null
                    ? Colors.purple.shade50
                    : refill != null
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHighest,
                child: Icon(
                  icon,
                  color: overdue
                      ? scheme.error
                      : symptom != null
                      ? Colors.purple.shade700
                      : refill != null
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity:
                      state == _CircleState.done ||
                          state == _CircleState.skipped
                      ? 0.65
                      : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.titleMedium?.copyWith(
                          color: overdue ? scheme.error : null,
                          decoration: state == _CircleState.done && dose != null
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: t.bodyMedium?.copyWith(
                          color: overdue ? scheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (dose != null || task != null)
                _CircleButton(
                  state: state,
                  onTap: onCircle,
                  enabled: dose == null || canAct,
                )
              else
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onCard,
                  tooltip: tr('View details'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CircleState { open, overdue, done, skipped }

/// The round check button: an empty ring that fills with a tick when done.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.state,
    required this.onTap,
    required this.enabled,
  });

  final _CircleState state;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (
      Color fill,
      Color border,
      IconData? icon,
      String label,
    ) = switch (state) {
      _CircleState.done => (
        scheme.primary,
        scheme.primary,
        Icons.check,
        tr('Taken. Tap to undo'),
      ),
      _CircleState.skipped => (
        scheme.surfaceContainerHighest,
        scheme.outline,
        Icons.remove,
        tr('Skipped. Tap to undo'),
      ),
      _CircleState.overdue => (
        Colors.transparent,
        scheme.error,
        null,
        tr('Overdue. Tap to mark as taken'),
      ),
      _CircleState.open => (
        Colors.transparent,
        scheme.outline,
        null,
        tr('Tap to mark as taken'),
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 32,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(
                  color: enabled ? border : scheme.outlineVariant,
                  width: 2.2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: icon == null
                    ? const SizedBox.shrink(key: ValueKey('empty'))
                    : Icon(
                        icon,
                        key: ValueKey(state),
                        size: 20,
                        color: state == _CircleState.done
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showDoseSheet(
  BuildContext context,
  WidgetRef ref,
  DoseEntry entry,
  bool canAct,
) {
  final plan = entry.plan;
  final actions = ref.read(doseActionsProvider);
  final t = context.textTheme;
  final timing = plan.mealTiming == MealTiming.anytime
      ? ''
      : ' · ${plan.mealTiming.label.toLowerCase()}';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${formatTime(entry.dose.at)} · ${plan.doseUnit.describe(entry.dose.amount)}$timing',
              style: t.bodyLarge,
            ),
            if (plan.condition != null)
              Text(
                trf('For {n}', {'n': '${plan.condition}'}),
                style: t.bodyMedium,
              ),
            if (plan.stock != null)
              Text(
                trf('{n} left', {'n': plan.doseUnit.describe(plan.stock!)}),
                style: t.bodyMedium,
              ),
            const SizedBox(height: AppSpacing.md),
            if (canAct &&
                entry.isOpen &&
                entry.dose.at.isBefore(DateTime.now())) ...[
              MissedDoseCard(entry: entry),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (!canAct)
              Text(
                tr('You can mark doses once the day arrives.'),
                style: t.bodyMedium,
              )
            else if (entry.isOpen) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  actions.take(entry.dose);
                },
                icon: const Icon(Icons.check),
                label: Text(tr('Taken')),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _askSkipReasonAndSkip(context, ref, entry);
                },
                child: Text(tr('Skip this dose')),
              ),
            ] else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  actions.undo(entry.dose);
                },
                icon: const Icon(Icons.undo),
                label: Text(
                  entry.status == DoseStatus.taken
                      ? tr('Undo taken')
                      : tr('Undo skip'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _askSkipReasonAndSkip(
  BuildContext context,
  WidgetRef ref,
  DoseEntry entry,
) {
  final actions = ref.read(doseActionsProvider);
  final repo = ref.read(missReasonRepositoryProvider);
  final t = context.textTheme;

  showModalBottomSheet<void>(
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
              tr('Why skip this dose?'),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final r in [
                  MissReasonType.forgot,
                  MissReasonType.ranOut,
                  MissReasonType.sideEffect,
                  MissReasonType.feltFine,
                  MissReasonType.cost,
                  MissReasonType.fastingTravel,
                ])
                  ActionChip(
                    avatar: Text(r.emoji, style: const TextStyle(fontSize: 14)),
                    label: Text(r.label),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await actions.skip(entry.dose);
                      await repo.recordForDose(dose: entry.dose, reason: r);
                      if (context.mounted) {
                        await showMatchedResponseSheet(
                          context: context,
                          ref: ref,
                          entry: entry,
                          reason: r,
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  actions.skip(entry.dose);
                },
                child: Text(tr('Skip without reason')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Banner warning users if notifications or exact alarms are disabled.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(reminderHealthProvider).value;
    if (health == null || health.allGood) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final t = context.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        color: scheme.errorContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'Reminders blocked: notifications or exact alarms are turned off',
                      ),
                      style: t.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      tr(
                        'Allow exact alarms in system settings for accurate reminders',
                      ),
                      style: t.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FilledButton.tonal(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: Text(tr('Fix in settings')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows on today's list while a TB (DOTS) programme is running.
class _TbBanner extends ConsumerWidget {
  const _TbBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(tbProgrammeProvider).value;
    if (programme == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final day = programme.dayNumber(now);
    if (day < 1 || day > tbTotalDays) return const SizedBox.shrink();
    final observed = ref.watch(tbObservationsProvider).value ?? const {};
    final tb = [
      for (final e
          in ref.watch(todayEntriesProvider).value ?? const <DoseEntry>[])
        if (e.plan.condition == tbCondition && e.status != DoseStatus.skipped)
          e,
    ];
    if (tb.isEmpty) return const SizedBox.shrink();
    final missed = tb.any((e) => e.status == DoseStatus.missed);
    final unconfirmed = tb.any((e) => !observed.containsKey(e.dose.key));
    final scheme = context.colorScheme;
    final bg = missed ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = missed ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        color: bg,
        child: ListTile(
          leading: Icon(Icons.vaccines_outlined, color: fg),
          title: Text(
            trf('TB care: day {a} of {b}', {'a': '$day', 'b': '$tbTotalDays'}),
            style: TextStyle(color: fg),
          ),
          subtitle: Text(
            missed
                ? tr('A TB dose was missed. Tell your supporter.')
                : unconfirmed
                ? tr('Have your supporter confirm today\'s dose.')
                : tr('Today\'s dose is confirmed.'),
            style: TextStyle(color: fg),
          ),
          trailing: Icon(Icons.chevron_right, color: fg),
          onTap: () => context.push(AppRoutes.tb),
        ),
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({
    required this.name,
    required this.daysLeft,
    required this.onTap,
  });

  final String name;
  final double? daysLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final left = daysLeft;
    final text = left == null
        ? trf('{n} is running low.', {'n': name})
        : left < 1
        ? trf('{n} will run out today.', {'n': name})
        : trf(
            left.floor() == 1
                ? '{m}: about {n} day left.'
                : '{m}: about {n} days left.',
            {'m': name, 'n': '${left.floor()}'},
          );
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.inventory_2_outlined,
          color: scheme.onTertiaryContainer,
        ),
        title: Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
        onTap: onTap,
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: context.colorScheme.primaryContainer,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            const ReindeerMark(size: 56, interactive: true),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                ReindeerVoice.allDone,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
