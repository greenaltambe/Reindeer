import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/application/dose_actions.dart';
import 'package:reindeer/features/medications/application/plan_actions.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/tb/data/tb_repository.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';

/// Starting, running and ending a TB (DOTS) programme.
class TbActions {
  TbActions(this._ref);

  final Ref _ref;

  /// Saves the programme and creates the two daily plans: intensive phase
  /// (four medicines) then continuation phase (three), on an empty stomach.
  Future<void> start({
    required TbProgramme programme,
    required int tablets,
  }) async {
    // Midnight, so today's earlier dose (and a start date in the past) is
    // not silently skipped by the timeline's createdAt rule.
    final now = dateOnly(DateTime.now());
    final first = programme.firstDay;
    MedicationPlan plan({
      required String name,
      required String composition,
      required DateTime from,
      required int days,
    }) => MedicationPlan(
      profileId: AppDatabase.defaultProfileId,
      name: name,
      composition: composition,
      condition: tbCondition,
      doseUnit: DoseUnit.tablet,
      slotAmounts: {DaySlot.morning: tablets.toDouble()},
      mealTiming: MealTiming.beforeFood,
      startDate: from,
      endDate: DateTime(from.year, from.month, from.day + days - 1),
      createdAt: now,
    );

    final plans = _ref.read(planActionsProvider);
    await plans.add(
      plan(
        name: 'TB medicines (first 2 months)',
        composition: 'Isoniazid + Rifampicin + Pyrazinamide + Ethambutol',
        from: first,
        days: tbIntensiveDays,
      ),
    );
    await plans.add(
      plan(
        name: 'TB medicines (next 4 months)',
        composition: 'Isoniazid + Rifampicin + Ethambutol',
        from: DateTime(first.year, first.month, first.day + tbIntensiveDays),
        days: tbContinuationDays,
      ),
    );
    await _ref.read(tbRepositoryProvider).save(programme);
    _ref.read(dataVersionProvider.notifier).bump();
  }

  /// Marks a dose as taken and watched. The caller checks the supporter's PIN.
  Future<void> confirm(PlannedDose dose, {required bool alreadyTaken}) async {
    final programme = await _ref.read(tbRepositoryProvider).load();
    if (programme == null) return;
    if (!alreadyTaken) await _ref.read(doseActionsProvider).take(dose);
    await _ref
        .read(tbRepositoryProvider)
        .observe(dose, programme.supporterName, DateTime.now());
    _ref.read(dataVersionProvider.notifier).bump();
  }

  /// Ends the programme: stops its plans and forgets the supporter.
  Future<void> end() async {
    final plans = await _ref.read(planRepositoryProvider).all();
    final actions = _ref.read(planActionsProvider);
    for (final p in plans) {
      if (p.condition == tbCondition && p.isActive) await actions.stop(p);
    }
    await _ref.read(tbRepositoryProvider).clear();
    _ref.read(dataVersionProvider.notifier).bump();
  }
}

final tbActionsProvider = Provider<TbActions>(TbActions.new);
