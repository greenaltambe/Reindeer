import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/medicine_database.dart';
import 'package:sqflite/sqflite.dart';

/// Searches the bundled list of health conditions (built from the "used for"
/// text of the medicine data, with everyday aliases such as "bp" or "sugar").
class ConditionSearchService {
  ConditionSearchService._(this._items);

  final List<_Condition> _items;

  static Future<ConditionSearchService> load(Database db) async {
    final rows = await db.rawQuery('SELECT name, freq, aliases FROM condition');
    final items = [
      for (final r in rows)
        _Condition(
          name: r['name'] as String,
          freq: (r['freq'] as int?) ?? 0,
          aliases: ((r['aliases'] as String?) ?? '')
              .split(',')
              .map((a) => a.trim().toLowerCase())
              .where((a) => a.isNotEmpty)
              .toList(),
        ),
    ];
    return ConditionSearchService._(items);
  }

  /// Most common conditions, shown before the person types anything.
  List<String> popular({int limit = 10}) {
    final sorted = [..._items]..sort((a, b) => b.freq.compareTo(a.freq));
    return [for (final c in sorted.take(limit)) c.name];
  }

  /// Conditions matching [query], best first. Every typed word must match the
  /// start of a word in the name or an alias.
  List<String> search(String query, {int limit = 10}) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];

    final scored = <(_Condition, int)>[];
    for (final c in _items) {
      final nameLow = c.name.toLowerCase();
      final nameWords = nameLow
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.isNotEmpty)
          .toList();
      final aliasWords = [
        for (final a in c.aliases)
          ...a.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty),
      ];
      var score = 0;
      var ok = true;
      for (final t in tokens) {
        if (nameWords.any((w) => w.startsWith(t))) {
          score += nameLow.startsWith(t) ? 4 : 3;
        } else if (aliasWords.any((w) => w.startsWith(t))) {
          score += 2;
        } else if (t.length >= 3 && nameLow.contains(t)) {
          score += 1;
        } else {
          ok = false;
          break;
        }
      }
      if (ok) scored.add((c, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      final byFreq = b.$1.freq.compareTo(a.$1.freq);
      if (byFreq != 0) return byFreq;
      return a.$1.name.length.compareTo(b.$1.name.length);
    });
    return [for (final s in scored.take(limit)) s.$1.name];
  }
}

class _Condition {
  const _Condition({
    required this.name,
    required this.freq,
    required this.aliases,
  });

  final String name;
  final int freq;
  final List<String> aliases;
}

final conditionSearchProvider = FutureProvider<ConditionSearchService>((ref) {
  return ConditionSearchService.load(ref.watch(medicineDatabaseProvider));
});
