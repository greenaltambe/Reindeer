import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';

/// Taking, skipping and undoing doses from inside the app.
class DoseActions {
  DoseActions(this._ref);

  final Ref _ref;

  Future<void> take(PlannedDose dose) => _record(dose, DoseStatus.taken);

  Future<void> skip(PlannedDose dose) => _record(dose, DoseStatus.skipped);

  Future<void> undo(PlannedDose dose) async {
    await _ref.read(doseLogRepositoryProvider).clear(dose);
    await _afterChange();
  }

  Future<void> _record(PlannedDose dose, DoseStatus status) async {
    await _ref
        .read(doseLogRepositoryProvider)
        .record(dose: dose, status: status, now: DateTime.now());
    await _afterChange();
  }

  Future<void> _afterChange() async {
    _ref.read(dataVersionProvider.notifier).bump();
    // Drops the reminder for a dose that has just been handled.
    await _ref.read(reminderServiceProvider).rescheduleAll();
  }
}

final doseActionsProvider = Provider<DoseActions>(DoseActions.new);
