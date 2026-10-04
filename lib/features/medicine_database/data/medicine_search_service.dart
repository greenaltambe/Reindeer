import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/medicine_database.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:sqflite/sqflite.dart';

/// Typo-tolerant, word-order-independent search over the bundled medicine
/// database.
///
/// This is a line-by-line port of `tools/search_reference.py`; keep the two in
/// step. `test/fixtures/search_cases.json` holds expected results produced by
/// the Python version.
class MedicineSearchService {
  MedicineSearchService._(
    this._db,
    this._vocab,
    this._ingWords,
    this._salts,
    this._fillers,
    this._syn,
  );

  static const int _limit = 30;
  static const int _prefixExpansions = 12;
  static const int _ing = 1;

  /// Used when a query has no single "key"; never equals a real ingredient.
  static const String _noKey = '\u0001';

  static final RegExp _token = RegExp(r'\d+(?:\.\d+)?|[a-z]+');
  static final RegExp _segmentSplit = RegExp(
    r',|;|\+|&|\band\b|/(?=\s*[a-z])',
    caseSensitive: false,
  );
  static final RegExp _parens = RegExp(r'\([^)]*\)');

  final Database _db;
  final Map<String, _VocabEntry> _vocab;
  final List<String> _ingWords;
  final Set<String> _salts;
  final Set<String> _fillers;
  final Map<String, String> _syn;

  /// Loads the vocabulary and normalisation lists from [db].
  static Future<MedicineSearchService> load(Database db) async {
    final vocab = <String, _VocabEntry>{};
    final ingWords = <String>[];
    for (final r in await db.rawQuery('SELECT word, kind, freq FROM vocab')) {
      final word = r['word'] as String;
      final kind = r['kind'] as int;
      vocab[word] = _VocabEntry(kind, r['freq'] as int);
      if (kind & _ing != 0) ingWords.add(word);
    }
    final salts = <String>{};
    final fillers = <String>{};
    final syn = <String, String>{};
    for (final r in await db.rawQuery('SELECT kind, word, canon FROM norm')) {
      final word = r['word'] as String;
      switch (r['kind'] as String) {
        case 'salt':
          salts.add(word);
        case 'filler':
          fillers.add(word);
        case 'syn':
          syn[word] = (r['canon'] as String?) ?? word;
      }
    }
    return MedicineSearchService._(db, vocab, ingWords, salts, fillers, syn);
  }

  // --- query normalisation -------------------------------------------------

  /// Returns the required words (in query order) and the strength numbers.
  ({List<String> words, List<String> numbers}) parse(String query) {
    final words = <String>[];
    final numbers = <String>[];
    for (final seg in query.replaceAll(_parens, ' ').split(_segmentSplit)) {
      var first = true;
      for (final m in _token.allMatches(seg.toLowerCase())) {
        var t = m.group(0)!;
        t = _syn[t] ?? t;
        if (_isNumeric(t)) {
          if (!numbers.contains(t)) numbers.add(t);
          continue;
        }
        if (_fillers.contains(t)) continue;
        if (_salts.contains(t) && !first) continue;
        first = false;
        words.add(t);
      }
    }
    return (words: words, numbers: numbers);
  }

  static bool _isNumeric(String t) {
    final c = t.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  // --- per-word candidates -------------------------------------------------

  String? _correct(String w) {
    if (_vocab.containsKey(w)) return w;
    var hits = _edits1(w).where(_vocab.containsKey).toList();
    if (hits.isEmpty && w.length >= 6) {
      hits = [
        for (final c in _ingWords)
          if (_osaWithin(w, c, 2)) c,
      ];
    }
    if (hits.isEmpty) return null;
    String best = hits.first;
    for (final c in hits.skip(1)) {
      if (_betterThan(c, best)) best = c;
    }
    return best;
  }

  /// (ING bit, frequency, word) comparison, larger wins.
  bool _betterThan(String a, String b) {
    final va = _vocab[a]!;
    final vb = _vocab[b]!;
    final ia = va.kind & _ing;
    final ib = vb.kind & _ing;
    if (ia != ib) return ia > ib;
    if (va.freq != vb.freq) return va.freq > vb.freq;
    return a.compareTo(b) > 0;
  }

  Future<List<String>> _prefixWords(String p) async {
    final rows = await _db.rawQuery(
      'SELECT word FROM vocab WHERE word >= ? AND word < ? '
      'ORDER BY freq DESC, word LIMIT ?',
      [p, '$p￿', _prefixExpansions],
    );
    return [for (final r in rows) r['word'] as String];
  }

  Future<List<List<String>>> _candidates(
    List<String> words,
    bool asYouType,
  ) async {
    final out = <List<String>>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final last = i == words.length - 1;
      var cands = <String>[];
      if (last && asYouType && w.length >= 2) {
        cands = await _prefixWords(w);
        if (_vocab.containsKey(w) && !cands.contains(w)) cands.insert(0, w);
      }
      if (cands.isEmpty) {
        final c = _correct(w);
        cands = c == null ? <String>[] : <String>[c];
      }
      if (cands.isNotEmpty) out.add(cands);
    }
    return out;
  }

  // --- retrieval -----------------------------------------------------------

  Future<List<MedicineHit>> search(
    String query, {
    bool asYouType = false,
    int limit = _limit,
  }) async {
    final rows = await searchRows(query, asYouType: asYouType, limit: limit);
    return rows.map(_toHit).toList();
  }

  /// Raw rows (`id`, `name`, ...) in ranked order. Exposed for parity tests.
  Future<List<Map<String, Object?>>> searchRows(
    String query, {
    bool asYouType = false,
    int limit = _limit,
  }) async {
    final parsed = parse(query);
    final words = parsed.words;
    final numbers = parsed.numbers;
    if (words.isEmpty) return const [];

    var cand = await _candidates(words, asYouType);
    if (cand.isEmpty) return const [];

    // Drop duplicate candidate groups (the same word typed twice).
    final seen = <String>{};
    final uniq = <List<String>>[];
    for (final c in cand) {
      if (seen.add(c.join('\u0000'))) uniq.add(c);
    }
    cand = uniq;

    final single = cand.every((c) => c.length == 1);
    final ingredientMode = cand.every(
      (c) => c.every((w) => _vocab[w]!.kind & _ing != 0),
    );
    final key = single
        ? (cand.map((c) => c.first).toSet().toList()..sort()).join(' ')
        : null;

    final bonus = numbers.isEmpty
        ? '0.0'
        : List.filled(numbers.length, '(instr(m.nums, ?) > 0)').join(' + ');
    final bonusArgs = [for (final n in numbers) ' $n '];

    final String order;
    final List<Object?> orderArgs;
    if (ingredientMode) {
      order =
          '(m.ing = ?) DESC, m.ingn ASC, ($bonus) DESC, m.disc ASC, m.src DESC, '
          'length(m.name) ASC, m.id ASC';
      orderArgs = [key ?? _noKey, ...bonusArgs];
    } else {
      order =
          "((' ' || m.bw) LIKE ?) DESC, ($bonus) DESC, m.src ASC, m.bwn ASC, "
          'm.disc ASC, length(m.name) ASC, m.id ASC';
      orderArgs = ['% ${words.last}%', ...bonusArgs];
    }

    int groupFreq(List<String> c) => c.fold(0, (s, w) => s + _vocab[w]!.freq);
    final groups = [...cand]
      ..sort((a, b) => groupFreq(a).compareTo(groupFreq(b)));

    final conds = <String>[];
    final args = <Object?>[];
    for (var n = 0; n < groups.length; n++) {
      final c = groups[n];
      final ph = List.filled(c.length, '?').join(',');
      if (n == 0) {
        conds.add('m.id IN (SELECT id FROM word_index WHERE word IN ($ph))');
      } else {
        conds.add(
          'EXISTS (SELECT 1 FROM word_index x WHERE x.id = m.id AND x.word IN ($ph))',
        );
      }
      args.addAll(c);
    }

    const cols =
        'm.id, m.name, m.mfr, m.pack, m.pack_qty, m.comp, m.form, m.src, m.inc, m.use, m.uses';
    final sql =
        'SELECT $cols FROM medicine m WHERE ${conds.join(' AND ')} '
        'ORDER BY $order LIMIT ?';
    final rows = await _db.rawQuery(sql, [...args, ...orderArgs, limit]);
    if (rows.isNotEmpty || cand.length == 1) return rows;

    // Relax: rank by how many query words matched.
    final flat = [for (final c in cand) ...c];
    final ph = List.filled(flat.length, '?').join(',');
    final relaxed =
        'SELECT $cols FROM medicine m JOIN '
        '(SELECT id, COUNT(DISTINCT word) c FROM word_index WHERE word IN ($ph) GROUP BY id) t '
        'ON t.id = m.id ORDER BY t.c DESC, m.ingn ASC, m.disc ASC, m.src DESC, m.id ASC LIMIT ?';
    return _db.rawQuery(relaxed, [...flat, limit]);
  }

  MedicineHit _toHit(Map<String, Object?> r) {
    final src = (r['src'] as int?) ?? 0;
    return MedicineHit(
      id: r['id'] as int,
      name: r['name'] as String,
      manufacturer: (r['mfr'] as String?) ?? '',
      pack: (r['pack'] as String?) ?? '',
      packQty: (r['pack_qty'] as num?)?.toDouble(),
      composition: src == 1 ? '' : ((r['comp'] as String?) ?? ''),
      form: (r['form'] as String?) ?? 'other',
      kind: src == 1 ? MedicineKind.generic : MedicineKind.brand,
      compositionMayBeIncomplete: ((r['inc'] as int?) ?? 0) == 1,
      usedFor: (r['use'] as String?) ?? '',
      uses: [
        for (final u in ((r['uses'] as String?) ?? '').split('|'))
          if (u.isNotEmpty) u,
      ],
    );
  }

  /// Other products with the same ingredients and strength as [hit], generics
  /// first. Empty when the database has no ingredient information for it.
  Future<List<MedicineHit>> alternatives(
    MedicineHit hit, {
    int limit = 8,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT m.id, m.name, m.mfr, m.pack, m.pack_qty, m.comp, m.form, m.src, m.inc, m.use, m.uses '
      'FROM medicine m, (SELECT ing, nums, form FROM medicine WHERE id = ?) s '
      "WHERE m.ing = s.ing AND s.ing != '' AND m.nums = s.nums AND m.form = s.form AND m.id != ? "
      'ORDER BY m.src DESC, m.disc ASC, length(m.name) ASC, m.id ASC LIMIT ?',
      [hit.id, hit.id, limit],
    );
    return rows.map(_toHit).toList();
  }

  /// Looks up one medicine by id (used when re-opening a plan).
  Future<MedicineHit?> byId(int id) async {
    final rows = await _db.rawQuery(
      'SELECT m.id, m.name, m.mfr, m.pack, m.pack_qty, m.comp, m.form, m.src, m.inc, m.use, m.uses '
      'FROM medicine m WHERE m.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _toHit(rows.first);
  }
}

class _VocabEntry {
  const _VocabEntry(this.kind, this.freq);
  final int kind;
  final int freq;
}

const String _letters = 'abcdefghijklmnopqrstuvwxyz';

/// All strings one edit (delete, swap, substitute, insert) away from [w].
Set<String> _edits1(String w) {
  final out = <String>{};
  for (var i = 0; i <= w.length; i++) {
    final a = w.substring(0, i);
    final b = w.substring(i);
    if (b.isNotEmpty) out.add(a + b.substring(1));
    if (b.length > 1) out.add('$a${b[1]}${b[0]}${b.substring(2)}');
    for (var k = 0; k < _letters.length; k++) {
      final c = _letters[k];
      if (b.isNotEmpty) out.add('$a$c${b.substring(1)}');
      out.add('$a$c$b');
    }
  }
  out.remove(w);
  return out;
}

/// Optimal-string-alignment distance of [a] and [b] is at most [k].
bool _osaWithin(String a, String b, int k) {
  if ((a.length - b.length).abs() > k) return false;
  List<int>? prev2;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = prev[j] + 1;
      if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
      if (prev[j - 1] + c < v) v = prev[j - 1] + c;
      if (prev2 != null &&
          i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        if (prev2[j - 2] + 1 < v) v = prev2[j - 2] + 1;
      }
      cur[j] = v;
    }
    prev2 = prev;
    prev = cur;
  }
  return prev.last <= k;
}

/// The search service; loads the vocabulary once.
final medicineSearchProvider = FutureProvider<MedicineSearchService>((ref) {
  return MedicineSearchService.load(ref.watch(medicineDatabaseProvider));
});

/// Same-ingredient alternatives for a medicine id's hit.
final alternativesProvider =
    FutureProvider.family<List<MedicineHit>, MedicineHit>((ref, hit) async {
      final service = await ref.watch(medicineSearchProvider.future);
      return service.alternatives(hit);
    });
