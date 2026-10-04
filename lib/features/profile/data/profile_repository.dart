import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/features/profile/domain/user_profile.dart';
import 'package:sqflite/sqflite.dart';

/// The profile and the person's health conditions.
class ProfileRepository {
  ProfileRepository(this._db);

  final Database _db;

  static const _id = AppDatabase.defaultProfileId;

  Future<UserProfile> get() async {
    final rows = await _db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [_id],
      limit: 1,
    );
    if (rows.isEmpty) return const UserProfile(name: '');
    final r = rows.first;
    final name = (r['name'] as String?) ?? '';
    return UserProfile(
      name: name == 'Me' ? '' : name,
      birthYear: r['birth_year'] as int?,
      heightCm: (r['height_cm'] as num?)?.toDouble(),
    );
  }

  Future<void> save({
    required String name,
    int? birthYear,
    double? heightCm,
  }) async {
    await _db.update(
      'profiles',
      {
        'name': name.trim().isEmpty ? 'Me' : name.trim(),
        'birth_year': birthYear,
        'height_cm': heightCm,
      },
      where: 'id = ?',
      whereArgs: [_id],
    );
  }

  Future<List<String>> conditions() async {
    final rows = await _db.query(
      'profile_conditions',
      where: 'profile_id = ?',
      whereArgs: [_id],
      orderBy: 'id ASC',
    );
    return [for (final r in rows) r['name'] as String];
  }

  Future<void> setConditions(Iterable<String> names) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'profile_conditions',
        where: 'profile_id = ?',
        whereArgs: [_id],
      );
      for (final n in names) {
        final t = n.trim();
        if (t.isEmpty) continue;
        await txn.insert('profile_conditions', {
          'profile_id': _id,
          'name': t,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

final profileProvider = FutureProvider<UserProfile>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(profileRepositoryProvider).get();
});

final profileConditionsProvider = FutureProvider<List<String>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(profileRepositoryProvider).conditions();
});
