import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/routine/domain/routine_learning.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// Settings key: doses due before this moment are ignored when learning, so a
/// suggestion that was applied does not come straight back.
const keyRoutineFrom = 'routine_from';

/// Meal-time changes suggested by the last four weeks of taken doses.
final routineSuggestionsProvider = FutureProvider<List<RoutineSuggestion>>((
  ref,
) async {
  ref.watch(dataVersionProvider);
  final settings = ref.read(settingsRepositoryProvider);
  final anchors = await settings.loadMealAnchors();
  final today = dateOnly(DateTime.now());
  final from = DateTime(today.year, today.month, today.day - 27);
  final logs = await ref.read(doseLogRepositoryProvider).between(from, today);
  final cut = await settings.get(keyRoutineFrom);
  final after = cut == null ? null : DateTime.tryParse(cut);
  final used = [
    for (final l in logs.values)
      if (after == null || l.scheduledAt.isAfter(after)) l,
  ];
  return learnRoutine(logs: used, anchors: anchors);
});
