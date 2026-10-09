import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// Turning a "take a reading" reminder on, changing it, or turning it off.
class MeasureReminderActions {
  MeasureReminderActions(this._ref);

  final Ref _ref;

  /// Saves [reminder] for [type] (null turns it off) and reschedules.
  Future<void> set(MeasureType type, MeasureReminder? reminder) async {
    final stored = reminder == null
        ? ''
        : MeasureReminder(
            minutes: reminder.minutes,
            weekday: reminder.weekday,
            since: reminder.since ?? dateOnly(DateTime.now()),
          ).encode();
    await _ref
        .read(settingsRepositoryProvider)
        .set(MeasureReminder.settingsKey(type), stored);
    _ref.read(dataVersionProvider.notifier).bump();
    try {
      final service = _ref.read(reminderServiceProvider);
      if (reminder != null) await service.requestPermissions();
      await service.rescheduleAll();
    } catch (_) {
      // Saved; reminders are rebuilt on the next start or change.
    }
  }
}

final measureReminderActionsProvider = Provider<MeasureReminderActions>(
  MeasureReminderActions.new,
);
