/// Turns what a speech recogniser hears into the prescription shorthand that
/// [parseShorthand] understands, for example
/// "dolo 650 morning and night after food for five days" into
/// "dolo 650 1-0-1 after food 5 days".
///
/// Never throws. Words it does not know are left alone, so the medicine name
/// survives.
String normalizeSpoken(String input) {
  var t = input.toLowerCase().replaceAll(RegExp(r'[,.;]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return '';

  // Number words to digits (only the ones people say about a course).
  const numbers = {
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    'ten': '10', 'eleven': '11', 'twelve': '12', 'fourteen': '14',
    'fifteen': '15', 'twenty': '20', 'thirty': '30',
    // Hindi
    'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'paanch': '5',
    'panch': '5', 'chhe': '6', 'saat': '7', 'aath': '8', 'das': '10',
  };
  final words = t.split(' ');
  for (var i = 0; i < words.length; i++) {
    final n = numbers[words[i]];
    if (n != null) words[i] = n;
  }
  t = words.join(' ');

  // "1 0 1" spoken digit by digit.
  t = t.replaceAllMapped(
    RegExp(r'\b([0-3]) ([0-3]) ([0-3])\b'),
    (m) => '${m[1]}-${m[2]}-${m[3]}',
  );

  // Meal timing words.
  t = t
      .replaceAll(
        RegExp(
          r'\b(khane ke baad|after (breakfast|lunch|dinner|food|meals?|eating))\b',
        ),
        'after food',
      )
      .replaceAll(
        RegExp(
          r'\b(khane se pehle|khane se pahle|empty stomach|before (breakfast|lunch|dinner|food|meals?|eating))\b',
        ),
        'before food',
      )
      .replaceAll(
        RegExp(
          r'\b(khane ke saath|with (breakfast|lunch|dinner|food|meals?))\b',
        ),
        'with food',
      );

  // How often. Whole phrases first.
  String? pattern;
  final frequency = <RegExp, String>{
    RegExp(
      r'\b(thrice|three times|3 times|3 time|teen baar|tds)( a day| daily| per day)?\b',
    ): '1-1-1',
    RegExp(
      r'\b(twice|two times|2 times|2 time|do baar|bd)( a day| daily| per day)?\b',
    ): '1-0-1',
    RegExp(r'\b(once|one time|1 time|ek baar|od)( a day| daily| per day)\b'):
        '1-0-0',
  };
  frequency.forEach((re, p) {
    if (pattern == null && re.hasMatch(t)) {
      pattern = p;
      t = t.replaceAll(re, ' ');
    }
  });

  if (pattern == null) {
    // Parts of the day, in English or Hindi.
    final morning = RegExp(r'\b(morning|subah|savere)\b');
    final afternoon = RegExp(r'\b(afternoon|noon|lunch time|dopahar)\b');
    final night = RegExp(r'\b(night|evening|bedtime|raat|shaam)\b');
    final m = morning.hasMatch(t);
    final a = afternoon.hasMatch(t);
    final n = night.hasMatch(t);
    if (m || a || n) {
      pattern = '${m ? 1 : 0}-${a ? 1 : 0}-${n ? 1 : 0}';
      t = t
          .replaceAll(morning, ' ')
          .replaceAll(afternoon, ' ')
          .replaceAll(night, ' ');
    }
  }

  // "for 5 days", "5 din", "one week".
  t = t
      .replaceAll(RegExp(r'\bfor (?=\d)'), ' ')
      .replaceAll(RegExp(r'\b(din|dino)\b'), 'days')
      .replaceAll(RegExp(r'\b(hafta|hafte|haftey)\b'), 'week');
  t = t.replaceAll(
    RegExp(r'\b(and|aur|then|take|tablet|tablets|capsule|capsules|daily)\b'),
    ' ',
  );
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return pattern == null ? t : '$t $pattern'.trim();
}
