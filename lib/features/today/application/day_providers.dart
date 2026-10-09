import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/health/data/measurement_repository.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/refills/data/refill_repository.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/features/symptoms/data/symptom_repository.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';

/// The day shown on the Today screen (a date at midnight).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);

  void reset() => state = dateOnly(DateTime.now());
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

/// A "take a reading" reminder or logged measurement that falls on a given day.
class MeasureTask {
  const MeasureTask({required this.type, required this.at, this.reading});

  final MeasureType type;
  final DateTime at;

  /// The reading taken that day, if any (then the task is done).
  final Measurement? reading;

  bool get done => reading != null;
}

/// Measurement reminders due on [day] or actual readings recorded on [day].
///
/// Ensures both scheduled tasks and ad-hoc measurements appear on the day's timeline.
final dayMeasureTasksProvider =
    FutureProvider.family<List<MeasureTask>, DateTime>((ref, day) async {
      ref.watch(dataVersionProvider);
      final d = dateOnly(day);
      final settings = ref.read(settingsRepositoryProvider);
      final repo = ref.read(measurementRepositoryProvider);
      final tasks = <MeasureTask>[];

      for (final type in MeasureType.values) {
        final r = MeasureReminder.decode(
          await settings.get(MeasureReminder.settingsKey(type)),
        );
        final readings = await repo.forType(type, since: d, limit: 20);
        final end = nextDay(d);
        final dayReadings = [
          for (final m in readings)
            if (m.at.isBefore(end) && !m.at.isBefore(d)) m,
        ];

        if (dayReadings.isNotEmpty) {
          // All measurements recorded on this day appear as completed entries
          for (final m in dayReadings) {
            tasks.add(MeasureTask(type: type, at: m.at, reading: m));
          }
        } else if (r != null && r.occursOn(d)) {
          final since = r.since;
          if (since == null || !d.isBefore(dateOnly(since))) {
            tasks.add(
              MeasureTask(
                type: type,
                at: DateTime(
                  d.year,
                  d.month,
                  d.day,
                  r.minutes ~/ 60,
                  r.minutes % 60,
                ),
                reading: null,
              ),
            );
          }
        }
      }
      tasks.sort((a, b) => a.at.compareTo(b.at));
      return tasks;
    });

/// Symptoms logged on [day].
final daySymptomsProvider = FutureProvider.family<List<SymptomEntry>, DateTime>(
  (ref, day) async {
    ref.watch(dataVersionProvider);
    final symptoms = await ref.watch(symptomsProvider.future);
    return [
      for (final s in symptoms)
        if (isSameDay(s.at, day)) s,
    ]..sort((a, b) => a.at.compareTo(b.at));
  },
);

/// Refill events recorded on [day].
final dayRefillsProvider = FutureProvider.family<List<RefillRecord>, DateTime>((
  ref,
  day,
) async {
  ref.watch(dataVersionProvider);
  final refills = await ref.watch(recentRefillsProvider.future);
  return [
    for (final r in refills)
      if (isSameDay(r.at, day)) r,
  ]..sort((a, b) => a.at.compareTo(b.at));
});
