import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// The result of reading a prescription line such as
/// `dolo 650 1-0-1 after food 5 days`.
///
/// [query] is whatever is left once the schedule words are taken out, so it can
/// be used to search for the medicine. The other fields are null when the line
/// did not say anything about them.
class ParsedShorthand {
  const ParsedShorthand({
    required this.query,
    this.amounts,
    this.timing,
    this.days,
    this.intervalDays,
  });

  final String query;

  /// 2 for "every other day"; null when not mentioned.
  final int? intervalDays;

  /// Amount per time of day. Slots that are not taken have 0.
  final Map<DaySlot, double>? amounts;
  final MealTiming? timing;
  final int? days;

  bool get hasSchedule =>
      amounts != null || timing != null || days != null || intervalDays != null;

  /// A short human description, e.g. "1-0-1 · after food · 5 days".
  String get summary {
    final parts = <String>[];
    final a = amounts;
    if (a != null) {
      parts.add([for (final s in DaySlot.values) _fmt(a[s] ?? 0)].join('-'));
    }
    if (timing != null && timing != MealTiming.anytime) {
      parts.add(timing!.label.toLowerCase());
    }
    if (intervalDays == 2) parts.add('every other day');
    if (days != null) parts.add(days == 1 ? '1 day' : '$days days');
    return parts.join(' · ');
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    if (v == 0.5) return '½';
    if (v == 1.5) return '1½';
    return v.toString();
  }
}

final _pattern = RegExp(
  r'^([0-9]+(?:\.[0-9]+)?|[0-9]/[0-9]|½)-([0-9]+(?:\.[0-9]+)?|[0-9]/[0-9]|½)-([0-9]+(?:\.[0-9]+)?|[0-9]/[0-9]|½)$',
);
final _durationToken = RegExp(
  r'^([0-9]{1,3})(d|day|days|w|wk|wks|week|weeks|mo|month|months)$',
);
final _unitWord = RegExp(r'^(d|day|days|w|wk|wks|week|weeks|mo|month|months)$');

double? _amount(String s) {
  if (s == '½') return 0.5;
  if (s.contains('/')) {
    final p = s.split('/');
    final n = double.tryParse(p[0]);
    final d = double.tryParse(p[1]);
    if (n == null || d == null || d == 0) return null;
    return n / d;
  }
  return double.tryParse(s);
}

int _daysFor(int n, String unit) {
  if (unit.startsWith('w')) return n * 7;
  if (unit.startsWith('m')) return n * 30;
  return n;
}

Map<DaySlot, double> _slots(List<DaySlot> taken) => {
  for (final s in DaySlot.values) s: taken.contains(s) ? 1.0 : 0.0,
};

/// Reads Indian prescription shorthand. Never throws; unknown words stay in
/// [ParsedShorthand.query].
ParsedShorthand parseShorthand(String input) {
  var text = input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  MealTiming? timing;
  // Multi-word phrases first.
  final phrases = <RegExp, MealTiming>{
    RegExp(r'\b(before|bef|empty stomach)( food| meals?| eating)?\b'):
        MealTiming.beforeFood,
    RegExp(r'\b(after|aft)( food| meals?| eating)\b'): MealTiming.afterFood,
    RegExp(r'\bwith (food|meals?)\b'): MealTiming.withFood,
  };
  phrases.forEach((re, t) {
    if (re.hasMatch(text)) {
      timing ??= t;
      text = text.replaceAll(re, ' ');
    }
  });

  int? interval;
  final everyOther = RegExp(r'\b(every other day|alternate days?|alt days?)\b');
  if (everyOther.hasMatch(text)) {
    interval = 2;
    text = text.replaceAll(everyOther, ' ');
  }

  final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
  final rest = <String>[];
  Map<DaySlot, double>? amounts;
  int? days;

  for (var i = 0; i < tokens.length; i++) {
    final tok = tokens[i];

    final m = _pattern.firstMatch(tok);
    if (m != null && amounts == null) {
      final a = [for (var g = 1; g <= 3; g++) _amount(m.group(g)!)];
      if (a.every((v) => v != null) && a.any((v) => v! > 0)) {
        amounts = {for (var k = 0; k < 3; k++) DaySlot.values[k]: a[k]!};
        continue;
      }
    }

    final freq = switch (tok) {
      'od' || 'qd' || 'daily' => [DaySlot.morning],
      'bd' || 'bid' => [DaySlot.morning, DaySlot.night],
      'tds' || 'tid' => DaySlot.values.toList(),
      'hs' => [DaySlot.night],
      _ => null,
    };
    if (freq != null && amounts == null) {
      amounts = _slots(freq);
      continue;
    }

    if (tok == 'eod') {
      interval ??= 2;
      continue;
    }

    switch (tok) {
      case 'ac':
        timing ??= MealTiming.beforeFood;
        continue;
      case 'pc':
        timing ??= MealTiming.afterFood;
        continue;
    }

    final d = _durationToken.firstMatch(tok);
    if (d != null && days == null) {
      days = _daysFor(int.parse(d.group(1)!), d.group(2)!);
      if (rest.isNotEmpty && rest.last == 'x') rest.removeLast();
      continue;
    }
    // "5 days" written as two words.
    if (days == null &&
        RegExp(r'^[0-9]{1,3}$').hasMatch(tok) &&
        i + 1 < tokens.length &&
        _unitWord.hasMatch(tokens[i + 1]) &&
        i > 0) {
      days = _daysFor(int.parse(tok), tokens[i + 1]);
      if (rest.isNotEmpty && rest.last == 'x') rest.removeLast();
      i++;
      continue;
    }

    rest.add(tok);
  }

  return ParsedShorthand(
    query: rest.join(' ').trim(),
    amounts: amounts,
    timing: timing,
    days: days,
    intervalDays: interval,
  );
}
