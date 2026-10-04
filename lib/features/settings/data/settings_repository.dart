import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/settings/domain/meal_anchors.dart';
import 'package:sqflite/sqflite.dart';

/// Key-value settings stored in the app database.
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  static const keyOnboarded = 'onboarded';
  static const keyBreakfast = 'breakfast';
  static const keyLunch = 'lunch';
  static const keyDinner = 'dinner';
  static const keyTimezone = 'timezone';
  static const keyTheme = 'theme';

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isOnboarded() async => (await get(keyOnboarded)) == '1';

  Future<MealAnchors> loadMealAnchors() async {
    const defaults = MealAnchors();
    return MealAnchors(
      breakfast:
          int.tryParse(await get(keyBreakfast) ?? '') ?? defaults.breakfast,
      lunch: int.tryParse(await get(keyLunch) ?? '') ?? defaults.lunch,
      dinner: int.tryParse(await get(keyDinner) ?? '') ?? defaults.dinner,
    );
  }

  Future<void> saveMealAnchors(MealAnchors anchors) async {
    await set(keyBreakfast, '${anchors.breakfast}');
    await set(keyLunch, '${anchors.lunch}');
    await set(keyDinner, '${anchors.dinner}');
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The person's meal times; refreshes after any write.
final mealAnchorsProvider = FutureProvider<MealAnchors>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(settingsRepositoryProvider).loadMealAnchors();
});
