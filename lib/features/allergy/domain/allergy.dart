/// Allergy matching. Pure functions so they can be tested.
///
/// This only compares ingredient names. It cannot know every product and it is
/// not a substitute for asking a doctor or pharmacist.
library;

/// A family of medicines people commonly report allergies to.
class AllergyGroup {
  const AllergyGroup(
    this.label,
    this.aliases, {
    this.words = const {},
    this.prefixes = const [],
    this.suffixes = const [],
    this.parts = const [],
  });

  final String label;

  /// Other names a person might type for the same thing.
  final List<String> aliases;
  final Set<String> words;
  final List<String> prefixes;
  final List<String> suffixes;
  final List<String> parts;

  bool matchesWord(String w) =>
      words.contains(w) ||
      aliases.contains(w) ||
      prefixes.any(w.startsWith) ||
      suffixes.any(w.endsWith) ||
      parts.any(w.contains);
}

const allergyGroups = <AllergyGroup>[
  AllergyGroup(
    'Penicillins',
    ['penicillin', 'amoxicillin', 'amoxycillin', 'ampicillin', 'augmentin'],
    suffixes: ['cillin'],
  ),
  AllergyGroup(
    'Cephalosporins',
    ['cephalosporin', 'cefixime', 'ceftriaxone'],
    prefixes: ['cef', 'ceph'],
  ),
  AllergyGroup(
    'Sulfa drugs',
    ['sulfa', 'sulpha', 'sulfonamide', 'cotrimoxazole', 'septran'],
    prefixes: [
      'sulfam',
      'sulfad',
      'sulfas',
      'sulfac',
      'sulfon',
      'sulfap',
      'sulpham',
      'sulphad',
      'sulphas',
      'sulphac',
      'cotrimoxazole',
    ],
    words: {'sulfamethoxazole', 'sulphamethoxazole'},
  ),
  AllergyGroup(
    'Aspirin and painkillers (NSAIDs)',
    ['nsaid', 'aspirin', 'ibuprofen', 'diclofenac', 'brufen', 'painkiller'],
    words: {
      'aspirin',
      'nimesulide',
      'nimesulid',
      'mefenamic',
      'ketorolac',
      'indomethacin',
      'naproxen',
    },
    suffixes: ['profen', 'fenac', 'coxib', 'oxicam'],
  ),
  AllergyGroup(
    'Paracetamol',
    ['paracetamol', 'acetaminophen', 'crocin', 'dolo'],
    words: {'paracetamol', 'acetaminophen'},
  ),
  AllergyGroup(
    'Macrolide antibiotics',
    ['macrolide', 'azithromycin', 'erythromycin', 'clarithromycin'],
    suffixes: ['thromycin'],
  ),
  AllergyGroup(
    'Quinolone antibiotics',
    [
      'quinolone',
      'fluoroquinolone',
      'ciprofloxacin',
      'levofloxacin',
      'ofloxacin',
    ],
    parts: ['flox'],
  ),
  AllergyGroup(
    'Tetracyclines',
    ['tetracycline', 'doxycycline', 'minocycline'],
    suffixes: ['cycline'],
  ),
  AllergyGroup(
    'Metronidazole and similar',
    ['metronidazole', 'tinidazole', 'ornidazole', 'flagyl'],
    suffixes: ['nidazole'],
  ),
];

/// The group a stored or typed allergy belongs to, if any.
AllergyGroup? groupFor(String allergy) {
  final a = normalizeAllergy(allergy);
  for (final g in allergyGroups) {
    if (g.label.toLowerCase() == a) return g;
    for (final alias in g.aliases) {
      if (alias == a || '${alias}s' == a) return g;
    }
  }
  return null;
}

String normalizeAllergy(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// One allergy that a medicine's ingredient triggers.
class AllergyMatch {
  const AllergyMatch(this.allergy, this.ingredient);

  /// The allergy as the person recorded it.
  final String allergy;

  /// The ingredient word that matched.
  final String ingredient;

  @override
  bool operator ==(Object other) =>
      other is AllergyMatch &&
      other.allergy == allergy &&
      other.ingredient == ingredient;

  @override
  int get hashCode => Object.hash(allergy, ingredient);
}

/// Allergies triggered by a medicine.
///
/// [ingredientKey] is the space separated ingredient words from the medicine
/// database (may be empty). [text] is any extra text, such as the product name
/// and composition, which is what is available for medicines the person typed
/// in themselves.
List<AllergyMatch> findAllergyMatches({
  required List<String> allergies,
  String ingredientKey = '',
  String text = '',
}) {
  final words = <String>{
    for (final w in ingredientKey.toLowerCase().split(' '))
      if (w.length >= 4) w,
    for (final m in RegExp(r'[a-z]{4,}').allMatches(text.toLowerCase()))
      m.group(0)!,
  };
  final out = <AllergyMatch>{};
  for (final allergy in allergies) {
    final a = normalizeAllergy(allergy);
    if (a.isEmpty) continue;
    final group = groupFor(a);
    for (final w in words) {
      final hit = group != null
          ? group.matchesWord(w)
          : (w == a || (a.length >= 4 && (w.startsWith(a) || a.startsWith(w))));
      if (hit) out.add(AllergyMatch(allergy, w));
    }
  }
  return out.toList();
}
