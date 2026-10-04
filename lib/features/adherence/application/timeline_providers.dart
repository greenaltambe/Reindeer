import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// The current time, ticking once a minute (only emits when the minute changes).
final clockProvider = StreamProvider<DateTime>((ref) async* {
  DateTime trunc(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute);
  var last = trunc(DateTime.now());
  yield DateTime.now();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 15));
    final now = DateTime.now();
    if (trunc(now) != last) {
      last = trunc(now);
      yield now;
    }
  }
});

/// Doses for [fromDay]..[toDay] (inclusive) with their effective status.
Future<List<DoseEntry>> _entries(
  Ref ref,
  DateTime fromDay,
  DateTime toDay,
  DateTime now,
) async {
  final plans = await ref.read(planRepositoryProvider).all();
  final anchors = await ref.read(settingsRepositoryProvider).loadMealAnchors();
  final logs = await ref
      .read(doseLogRepositoryProvider)
      .between(fromDay, toDay);
  return DoseTimeline.build(
    plans: plans,
    logs: logs,
    anchors: anchors,
    fromDay: fromDay,
    toDay: toDay,
    now: now,
  );
}

/// Today's doses.
final todayEntriesProvider = FutureProvider<List<DoseEntry>>((ref) async {
  ref.watch(dataVersionProvider);
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  final today = dateOnly(now);
  return _entries(ref, today, today, now);
});

/// Doses for the last [days] days up to and including today.
final recentEntriesProvider = FutureProvider.family<List<DoseEntry>, int>((
  ref,
  days,
) async {
  ref.watch(dataVersionProvider);
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  final today = dateOnly(now);
  final from = DateTime(today.year, today.month, today.day - (days - 1));
  return _entries(ref, from, today, now);
});

/// Today's doses plus tomorrow's, used to find "the next dose".
final upcomingEntriesProvider = FutureProvider<List<DoseEntry>>((ref) async {
  ref.watch(dataVersionProvider);
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  final today = dateOnly(now);
  return _entries(ref, today, nextDay(today), now);
});
