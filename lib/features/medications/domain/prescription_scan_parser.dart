import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';

/// One medicine item parsed out of a scanned prescription photo.
class ScannedPrescriptionItem {
  ScannedPrescriptionItem({
    required this.name,
    this.composition = '',
    required this.slotAmounts,
    required this.mealTiming,
    required this.unit,
    this.durationDays,
    this.hit,
    this.isSelected = true,
    this.sourceText = '',
  });

  String name;
  String composition;
  Map<DaySlot, double> slotAmounts;
  MealTiming mealTiming;
  DoseUnit unit;
  int? durationDays;
  MedicineHit? hit;
  bool isSelected;

  /// The line as it was read off the photo, so the person can check it.
  String sourceText;

  /// False when the name was not found in the medicine database.
  bool get isMatched => hit != null;

  double get amountMorning => slotAmounts[DaySlot.morning] ?? 0;
  double get amountAfternoon => slotAmounts[DaySlot.afternoon] ?? 0;
  double get amountNight => slotAmounts[DaySlot.night] ?? 0;

  bool get hasActiveDose =>
      amountMorning > 0 || amountAfternoon > 0 || amountNight > 0;

  /// Human-readable schedule description for quick review, e.g. "1-0-1 · After food · 30 days"
  String get scheduleLabel {
    final m = fmt(amountMorning);
    final a = fmt(amountAfternoon);
    final n = fmt(amountNight);
    final parts = <String>['$m-$a-$n'];

    if (mealTiming != MealTiming.anytime) {
      parts.add(mealTiming.label);
    }
    if (durationDays != null) {
      parts.add(durationDays == 1 ? '1 day' : '$durationDays days');
    }
    return parts.join(' · ');
  }

  static String fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    if (v == 0.5) return '½';
    if (v == 1.5) return '1½';
    return v.toString();
  }
}

/// Parses multi-line doctor prescription text (printed or handwritten OCR)
/// into structured [ScannedPrescriptionItem] records.
class PrescriptionScanParser {
  const PrescriptionScanParser();

  static final _skipPatterns = RegExp(
    r'\b(hospital|clinic|nursing\s*home|patient|name|age|gender|sex|dr|doctor|mbbs|md|reg|review\s*after|follow\s*up|signature|pulse|bp|temp|weight|wt|investigation|diagnosis|complaint|phone|mob|mobile|date|email)\b|\bmmhg\b',
    caseSensitive: false,
  );

  static final _rxPrefix = RegExp(
    r'^\s*(rx|r/|℞)\s*[:.)]?\s*',
    caseSensitive: false,
  );

  static final _leadingIndex = RegExp(
    r'^\s*(\(?[0-9]{1,2}\s*([.)]|[-:](?!\s*[0-9OoIl]))|\(?(i|ii|iii|iv|v|vi|vii|viii|ix)[.)]|[•*#>»-])\s*',
    caseSensitive: false,
  );

  /// Dosage forms written before (or after) the name: "Tab", "T.", "Cap", ...
  static const _formWords = {
    't',
    'tab',
    'tabs',
    'tablet',
    'tablets',
    'c',
    'cap',
    'caps',
    'capsule',
    'capsules',
    'syp',
    'syr',
    'syrup',
    'susp',
    'suspension',
    'inj',
    'injection',
    'oint',
    'ointment',
    'gel',
    'cream',
    'lot',
    'lotion',
    'drop',
    'drops',
    'gtt',
    'gtts',
    'sachet',
    'sach',
    'pwd',
    'powder',
    'inh',
    'inhaler',
    'rotacap',
    'rotacaps',
    'respule',
    'respules',
    'spray',
    'soln',
    'solution',
    'liq',
    'liquid',
    'eye',
    'ear',
    'nasal',
    'mg',
    'mcg',
    'ml',
    'gm',
    'g',
    'iu',
  };

  static final _leadingForm = RegExp(
    r'^(t|tab|tabs|tablets?|c|cap|caps|capsules?|syp|syr|syrup|susp|inj|oint|gel|cream|lot|drops?|gtts?|sachet|pwd|powder|inh|rotacaps?|respules?|spray)\b\.?',
    caseSensitive: false,
  );

  /// Instruction words. The medicine name ends where these begin.
  static const _stopWords = {
    'take',
    'plenty',
    'water',
    'fluids',
    'fluid',
    'rest',
    'sos',
    'stat',
    'prn',
    'if',
    'needed',
    'required',
    'when',
    'fever',
    'pain',
    'for',
    'with',
    'x',
    'times',
    'time',
    'daily',
    'day',
    'days',
    'week',
    'weeks',
    'month',
    'months',
    'a',
    'the',
    'and',
    'then',
    'morning',
    'afternoon',
    'evening',
    'night',
    'noon',
    'breakfast',
    'lunch',
    'dinner',
    'bedtime',
    'bed',
    'meal',
    'meals',
    'food',
    'empty',
    'stomach',
    'apply',
    'local',
    'locally',
    'mouth',
    'orally',
    'oral',
    'continue',
    'cont',
    'once',
    'twice',
    'thrice',
    'weekly',
    'after',
    'before',
    'adv',
    'advice',
    'advised',
    'avoid',
    'oily',
    'spicy',
    'diet',
    'review',
    'nocte',
    'mane',
    'warm',
    'gargle',
    'gargles',
    'to',
    'be',
    'taken',
    'at',
    'in',
    'on',
    'or',
    'only',
    'till',
    'until',
    'each',
    'every',
    'alternate',
    'dose',
    'doses',
    'puff',
    'puffs',
    'qty',
    'quantity',
    'strip',
    'strips',
    'pack',
    'bottle',
    'box',
    'mrp',
    'rs',
    'inr',
    'od',
    'bd',
    'tds',
    'hs',
    'tsf',
    'tsp',
    'tbsp',
    'spoon',
    'spoons',
    'steam',
    'inhalation',
    'nebulization',
    'nebulisation',
    'sitz',
    'bath',
    'drink',
    'lots',
    'exercise',
    'walk',
    'sleep',
  };

  static const _measureWords = {
    'tsf',
    'tsp',
    'tbsp',
    'spoon',
    'spoons',
    'puff',
    'puffs',
    'tabs',
  };

  static final _nightWords = RegExp(
    r'\b(night|bedtime|bed\s*time|hs|nocte)\b',
    caseSensitive: false,
  );

  /// Takes raw OCR text and resolves each candidate prescription line against
  /// [MedicineSearchService], returning a structured list of items.
  static Future<List<ScannedPrescriptionItem>> parse(
    String rawText, {
    MedicineSearchService? searchService,
  }) async {
    final results = <ScannedPrescriptionItem>[];
    final seen = <String>{};
    _Entry? last;

    for (final rawLine in rawText.split(RegExp(r'[\r\n]+'))) {
      var line = normalizeOcrLine(rawLine);
      line = line.replaceFirst(_rxPrefix, '');
      line = line.replaceFirst(_leadingIndex, '').trim();
      if (line.isEmpty) continue;

      final formAtStart = _leadingForm.hasMatch(line);
      if (!formAtStart && _skipPatterns.hasMatch(line)) {
        last = null;
        continue;
      }

      final parsed = parseShorthand(line);
      final nameTokens = _nameTokens(parsed.query);
      final minLetters = formAtStart ? 2 : 3;
      final brandIndex = nameTokens.indexWhere(
        (w) => RegExp('^[a-z]{$minLetters,}\$').hasMatch(w),
      );

      // A row with only a dose ("1-0-1 x 5 days") belongs to the medicine on
      // the row above it (the line wrapped, or the dose sat in its own column).
      if (brandIndex < 0) {
        if (last != null && parsed.hasSchedule) last.merge(parsed, line);
        continue;
      }
      final name = nameTokens.sublist(brandIndex);

      MedicineHit? hit;
      if (searchService != null) {
        hit = await _findMedicine(
          searchService,
          name,
          form: _formFromText(line),
        );
      }

      // Without "Tab"/"Cap" or a dose, only trust lines that name a medicine.
      final exactHit =
          hit != null && _matchesName(hit, name.first, exactOnly: true);
      if (!formAtStart && !parsed.hasSchedule && !exactHit) {
        last = null;
        continue;
      }

      final resolvedName = hit?.name ?? _displayName(name);
      final key = hit != null ? 'id:${hit.id}' : resolvedName.toLowerCase();
      if (!seen.add(key)) {
        last = null;
        continue;
      }

      final item = ScannedPrescriptionItem(
        name: resolvedName,
        composition: hit?.composition ?? '',
        slotAmounts: _slotAmounts(parsed, line),
        mealTiming: parsed.timing ?? MealTiming.afterFood,
        unit: hit != null ? DoseUnit.fromForm(hit.form) : _unitFromText(line),
        durationDays: parsed.days,
        hit: hit,
        isSelected: hit != null,
        sourceText: rawLine.trim(),
      );
      results.add(item);
      last = _Entry(item, parsed);
    }

    return results;
  }

  /// Fixes what OCR commonly gets wrong on prescriptions, so the line can be
  /// read by [parseShorthand]: "1-O-1", "l - 0 - l", "Glyc0met", "a/f",
  /// "x 5/7" (five days), "twice a day".
  static String normalizeOcrLine(String line) {
    var s = line
        .replaceAll(RegExp('[‐-―−]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Dose pattern with letters read for digits or spaces around dashes.
    const slot = r'([0-9OoIl|½]|[0-9]/[0-9])';
    s = s.replaceAllMapped(
      RegExp(
        '(?<![A-Za-z0-9])$slot\\s*[-_~+]\\s*$slot\\s*[-_~+]\\s*$slot(?![A-Za-z0-9])',
      ),
      (m) => [
        for (var g = 1; g <= 3; g++)
          m
              .group(g)!
              .replaceAll(RegExp('[Oo]'), '0')
              .replaceAll(RegExp('[Il|]'), '1'),
      ].join('-'),
    );

    // Digits read inside a word: "Glyc0met", "Te1ma".
    s = s
        .replaceAll(RegExp(r'(?<=[A-Za-z]{2})0(?=[A-Za-z]{2})'), 'o')
        .replaceAll(RegExp(r'(?<=[A-Za-z]{2})1(?=[A-Za-z]{2})'), 'l');

    s = s
        .replaceAll(RegExp(r'\b[aA]\s*/\s*[fF]\b'), ' after food ')
        .replaceAll(RegExp(r'\b[bB]\s*/\s*[fF]\b'), ' before food ')
        .replaceAll(RegExp(r'\bbbf\b', caseSensitive: false), ' before food ');

    s = s.replaceAllMapped(
      RegExp(r'\bx\s*(\d)', caseSensitive: false),
      (m) => 'x ${m.group(1)}',
    );

    // "x 5/7" = 5 days, "x 2/52" = 2 weeks, "x 1/12" = 1 month.
    s = s.replaceAllMapped(RegExp(r'\b(\d{1,2})\s*/\s*(7|52|12)\b'), (m) {
      final unit = switch (m.group(2)) {
        '7' => 'd',
        '52' => 'w',
        _ => 'mo',
      };
      return ' ${m.group(1)}$unit ';
    });

    final phrases = <RegExp, String>{
      RegExp(r'\bonce (a|per|in a) day\b|\bonce daily\b', caseSensitive: false):
          ' od ',
      RegExp(
        r'\btwice (a|per|in a) day\b|\btwice daily\b',
        caseSensitive: false,
      ): ' bd ',
      RegExp(
        r'\b(thrice|three times|3 times) (a|per|in a) day\b|\bthrice daily\b|\b(three|3) times daily\b',
        caseSensitive: false,
      ): ' tds ',
      RegExp(r'\b(at bed ?time|at night|nocte)\b', caseSensitive: false):
          ' hs ',
    };
    phrases.forEach((re, r) => s = s.replaceAll(re, r));

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// The words of a line that can be part of the medicine's name: leading
  /// dosage forms and numbers are dropped, and reading stops at the first
  /// instruction word ("Dolo 650 SOS for fever" gives `dolo 650`).
  static List<String> _nameTokens(String query) {
    final out = <String>[];
    for (final m in RegExp(
      r'\d+(?:\.\d+)?|[a-z]+',
    ).allMatches(query.toLowerCase())) {
      final t = m.group(0)!;
      final hasName = out.any((w) => w.contains(RegExp('[a-z]')));
      if (_stopWords.contains(t)) {
        // "2 tsf", "2 puffs": the number was the amount, not the strength.
        if (_measureWords.contains(t) &&
            out.isNotEmpty &&
            RegExp(r'^\d').hasMatch(out.last)) {
          out.removeLast();
        }
        if (hasName) break;
        continue;
      }
      if (_formWords.contains(t)) continue;
      if (!hasName && !t.contains(RegExp('[a-z]'))) continue;
      out.add(t);
      if (out.length >= 6) break;
    }
    return out;
  }

  static String _displayName(List<String> words) => words
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Finds the medicine in the database. A result is only accepted when its
  /// name (or an ingredient) looks like the first word on the prescription, so
  /// a stray word never turns into an unrelated medicine.
  static Future<MedicineHit?> _findMedicine(
    MedicineSearchService search,
    List<String> name, {
    String? form,
  }) async {
    final brand = ocrCorrected(search, name.first);
    final rest = name.sublist(1);
    final numbers = rest.where((w) => RegExp(r'^\d').hasMatch(w)).toSet();
    // "SP", "LC", "Forte": the search ignores some of these, so check them here.
    final variants = rest
        .where((w) => RegExp(r'^[a-z]{1,5}$').hasMatch(w))
        .toSet();
    final attempts = <String>{
      [brand, ...rest].join(' '),
      if (numbers.isNotEmpty) '$brand ${numbers.first}',
      brand,
    };

    for (final query in attempts) {
      final hits = await search.search(query, limit: 30);
      var ok = hits.where((h) => _matchesName(h, brand)).toList();
      if (ok.isEmpty) {
        ok = hits.where((h) => _matchesIngredient(h, brand)).toList();
      }
      // Injections are given at the clinic; only match one when written.
      if (form != 'injection') {
        ok = ok.where((h) => h.form != 'injection').toList();
      }
      if (ok.isEmpty) continue;

      MedicineHit? best;
      var bestScore = -1;
      for (final h in ok) {
        final words = h.name.toLowerCase().split(RegExp('[^a-z0-9]+')).toSet();
        final variantHits = variants.where(words.contains).length;
        // A different variant ("Neurobion Plus" for "Neurobion Forte") is a
        // different medicine: leave it for the person to pick.
        if (variants.isNotEmpty && variantHits == 0) continue;
        final score =
            variantHits * 4 +
            (numbers.any(_numbersOf(h).contains) ? 2 : 0) +
            (form != null && h.form == form ? 1 : 0);
        if (score > bestScore) {
          best = h;
          bestScore = score;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  /// The database form for a dosage word written on the line, if any.
  static String? _formFromText(String line) {
    final lower = line.toLowerCase();
    bool has(String p) => RegExp('\\b($p)\\b').hasMatch(lower);
    if (has('t|tab|tabs|tablets?')) return 'tablet';
    if (has('c|cap|caps|capsules?')) return 'capsule';
    if (has('syp|syr|syrup|susp|suspension')) return 'liquid';
    if (has('inj|injection')) return 'injection';
    if (has('drops?|gtts?')) return 'drops';
    if (has('oint|ointment|cream|gel|lotion|lot')) return 'topical';
    if (has('inh|inhaler|rotacaps?|respules?')) return 'inhaler';
    return null;
  }

  /// OCR misreads letter shapes ("rn" for "m", "cl" for "d"). When [word] is
  /// not a known medicine word but one such fix is, returns the fixed word.
  static String ocrCorrected(MedicineSearchService search, String word) {
    if (search.isKnownWord(word)) return word;
    const swaps = [
      ('rn', 'm'),
      ('m', 'rn'),
      ('cl', 'd'),
      ('d', 'cl'),
      ('vv', 'w'),
      ('li', 'h'),
      ('h', 'li'),
      ('ii', 'u'),
      ('c', 'e'),
      ('e', 'c'),
      ('i', 'l'),
      ('l', 'i'),
      ('u', 'v'),
      ('v', 'u'),
      ('n', 'h'),
      ('h', 'n'),
      ('a', 'o'),
      ('o', 'a'),
      ('g', 'q'),
      ('q', 'g'),
    ];
    for (final (from, to) in swaps) {
      var i = word.indexOf(from);
      while (i >= 0) {
        final fixed = word.replaceRange(i, i + from.length, to);
        if (search.isKnownWord(fixed)) return fixed;
        i = word.indexOf(from, i + 1);
      }
    }
    return word;
  }

  static bool _matchesName(
    MedicineHit hit,
    String word, {
    bool exactOnly = false,
  }) {
    final words = hit.name
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((w) => w.contains(RegExp('[a-z]')))
        .take(2);
    return words.any((w) => _close(w, word, exactOnly: exactOnly));
  }

  static bool _matchesIngredient(MedicineHit hit, String word) {
    if (word.length < 5) return false;
    return hit.composition
        .toLowerCase()
        .split(RegExp('[^a-z]+'))
        .any((w) => _close(w, word));
  }

  static bool _close(String a, String b, {bool exactOnly = false}) {
    if (a == b) return true;
    if (exactOnly) return false;
    final n = b.length;
    final allowed = n <= 3 ? 0 : (n <= 5 ? 1 : 2);
    return allowed > 0 && _editDistance(a, b, allowed) <= allowed;
  }

  static Set<String> _numbersOf(MedicineHit hit) => {
    for (final m in RegExp(
      r'\d+(?:\.\d+)?',
    ).allMatches('${hit.name} ${hit.composition}'))
      m.group(0)!,
  };

  static Map<DaySlot, double> _slotAmounts(
    ParsedShorthand parsed,
    String line,
  ) {
    final a = parsed.amounts;
    // "OD at night" / "1 tab HS": one dose, taken at night.
    final onceOnly =
        a != null &&
        a[DaySlot.morning] == 1 &&
        a[DaySlot.afternoon] == 0 &&
        a[DaySlot.night] == 0 &&
        !RegExp(r'\d-\d').hasMatch(line);
    if (onceOnly && _nightWords.hasMatch(line)) {
      return {DaySlot.morning: 0, DaySlot.afternoon: 0, DaySlot.night: 1};
    }
    // Nothing written: one dose in the morning, for the person to check.
    return {
      DaySlot.morning: a?[DaySlot.morning] ?? 1,
      DaySlot.afternoon: a?[DaySlot.afternoon] ?? 0,
      DaySlot.night: a?[DaySlot.night] ?? 0,
    };
  }

  static DoseUnit _unitFromText(String line) {
    final lower = line.toLowerCase();
    if (RegExp(r'\b(c|cap|caps|capsules?)\b').hasMatch(lower)) {
      return DoseUnit.capsule;
    }
    if (RegExp(r'\b(syp|syr|syrup|susp|suspension)\b').hasMatch(lower)) {
      return DoseUnit.ml;
    }
    if (RegExp(r'\b(drops?|gtts?)\b').hasMatch(lower)) return DoseUnit.drops;
    return DoseUnit.tablet;
  }
}

/// The last medicine read, so a following dose-only row can fill it in.
class _Entry {
  _Entry(this.item, ParsedShorthand parsed)
    : _hasDose = parsed.amounts != null,
      _hasTiming = parsed.timing != null;

  final ScannedPrescriptionItem item;
  bool _hasDose;
  bool _hasTiming;

  void merge(ParsedShorthand parsed, String line) {
    if (!_hasDose && parsed.amounts != null) {
      item.slotAmounts = PrescriptionScanParser._slotAmounts(parsed, line);
      _hasDose = true;
    }
    if (!_hasTiming && parsed.timing != null) {
      item.mealTiming = parsed.timing!;
      _hasTiming = true;
    }
    item.durationDays ??= parsed.days;
    item.sourceText = '${item.sourceText}  ${line.trim()}';
  }
}

/// Optimal-string-alignment distance of [a] and [b], stopping early once it
/// is certain to be above [limit].
int _editDistance(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
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
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          prev2[j - 2] + 1 < v) {
        v = prev2[j - 2] + 1;
      }
      cur[j] = v;
    }
    prev2 = prev;
    prev = cur;
  }
  return prev.last;
}
