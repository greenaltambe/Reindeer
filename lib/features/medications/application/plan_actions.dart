import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';

/// Changes to medication plans; each one refreshes the screens and reminders.
class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  PlanRepository get _repo => _ref.read(planRepositoryProvider);

  Future<int> add(MedicationPlan plan) async {
    final id = await _repo.insert(plan);
    await _changed();
    return id;
  }

  Future<void> pause(MedicationPlan plan) => _status(plan, PlanStatus.paused);

  Future<void> stop(MedicationPlan plan) =>
      _status(plan, PlanStatus.discontinued);

  Future<void> resume(MedicationPlan plan) => _status(plan, PlanStatus.active);

  Future<void> delete(MedicationPlan plan) async {
    final id = plan.id;
    if (id == null) return;
    await _repo.delete(id);
    await _changed();
  }

  Future<void> refill(MedicationPlan plan, double quantity) async {
    final id = plan.id;
    if (id == null || quantity <= 0) return;
    await _repo.refill(id, quantity, DateTime.now());
    await _changed();
  }

  Future<void> _status(MedicationPlan plan, PlanStatus status) async {
    final id = plan.id;
    if (id == null) return;
    await _repo.setStatus(id, status, DateTime.now());
    await _changed();
  }

  Future<void> _changed() async {
    _ref.read(dataVersionProvider.notifier).bump();
    await _ref.read(reminderServiceProvider).rescheduleAll();
  }
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);
