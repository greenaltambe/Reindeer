/// A searchable list of everyday symptoms, with the other names people use
/// (including common Hindi words written in English) and the words that show
/// up in medicine side-effect lists.
library;

enum SymptomCategory {
  head('Head and mind'),
  stomach('Stomach'),
  chest('Chest and breathing'),
  skin('Skin and allergy'),
  body('Body'),
  mouth('Mouth, eyes and ears'),
  urine('Urine');

  const SymptomCategory(this.label);

  final String label;
}

class SymptomInfo {
  const SymptomInfo(
    this.name,
    this.category, {
    this.aliases = const [],
    this.effectTerms = const [],
    this.common = false,
  });

  final String name;
  final SymptomCategory category;
  final List<String> aliases;

  /// Lower-case fragments to look for in a side-effect list.
  final List<String> effectTerms;

  /// Shown first, before the person searches.
  final bool common;
}

const symptomCatalog = <SymptomInfo>[
  // Head and mind
  SymptomInfo(
    'Headache',
    SymptomCategory.head,
    aliases: ['sir dard', 'sar dard', 'sardard', 'migraine'],
    effectTerms: ['headache', 'migraine'],
    common: true,
  ),
  SymptomInfo(
    'Dizziness',
    SymptomCategory.head,
    aliases: ['chakkar', 'giddiness', 'lightheaded', 'vertigo'],
    effectTerms: ['dizz', 'vertigo', 'lightheaded'],
    common: true,
  ),
  SymptomInfo(
    'Sleepiness',
    SymptomCategory.head,
    aliases: ['drowsy', 'sleepy', 'neend', 'sedation'],
    effectTerms: ['drows', 'sleep', 'sedat'],
    common: true,
  ),
  SymptomInfo(
    'Trouble sleeping',
    SymptomCategory.head,
    aliases: ['insomnia', 'neend nahi', 'cannot sleep'],
    effectTerms: ['insomnia', 'sleeplessness'],
  ),
  SymptomInfo(
    'Anxiety or restlessness',
    SymptomCategory.head,
    aliases: ['ghabrahat', 'tension', 'restless', 'nervous'],
    effectTerms: ['anxiety', 'restless', 'nervous', 'agitation'],
  ),
  SymptomInfo(
    'Confusion',
    SymptomCategory.head,
    aliases: ['confused', 'forgetful'],
    effectTerms: ['confusion', 'memory'],
  ),
  SymptomInfo(
    'Shaking or tremor',
    SymptomCategory.head,
    aliases: ['tremors', 'kampan', 'hands shaking'],
    effectTerms: ['tremor', 'shak'],
  ),
  SymptomInfo(
    'Fainting',
    SymptomCategory.head,
    aliases: ['blackout', 'behoshi', 'passed out'],
    effectTerms: ['faint', 'syncope'],
  ),
  // Stomach
  SymptomInfo(
    'Nausea',
    SymptomCategory.stomach,
    aliases: ['ji michlana', 'ji machlana', 'queasy', 'feeling sick'],
    effectTerms: ['nausea'],
    common: true,
  ),
  SymptomInfo(
    'Vomiting',
    SymptomCategory.stomach,
    aliases: ['ulti', 'vomit', 'throwing up'],
    effectTerms: ['vomit'],
    common: true,
  ),
  SymptomInfo(
    'Stomach pain',
    SymptomCategory.stomach,
    aliases: ['pet dard', 'pet me dard', 'abdominal pain', 'stomach cramps'],
    effectTerms: [
      'stomach pain',
      'abdominal pain',
      'stomach upset',
      'upset stomach',
      'gastro',
      'cramp',
    ],
    common: true,
  ),
  SymptomInfo(
    'Loose motions',
    SymptomCategory.stomach,
    aliases: ['dast', 'diarrhea', 'diarrhoea', 'loose stool'],
    effectTerms: ['diarrh'],
    common: true,
  ),
  SymptomInfo(
    'Constipation',
    SymptomCategory.stomach,
    aliases: ['kabz', 'hard stool'],
    effectTerms: ['constipat'],
  ),
  SymptomInfo(
    'Acidity or heartburn',
    SymptomCategory.stomach,
    aliases: ['acid', 'heartburn', 'jalan', 'sour belching'],
    effectTerms: ['heartburn', 'acidity', 'indigestion', 'dyspepsia'],
  ),
  SymptomInfo(
    'Gas or bloating',
    SymptomCategory.stomach,
    aliases: ['gas', 'bloating', 'flatulence', 'pet fulna'],
    effectTerms: ['flatulence', 'bloating', 'gas'],
  ),
  SymptomInfo(
    'Loss of appetite',
    SymptomCategory.stomach,
    aliases: ['bhookh nahi', 'not hungry', 'no appetite'],
    effectTerms: ['appetite'],
  ),
  // Chest and breathing
  SymptomInfo(
    'Cough',
    SymptomCategory.chest,
    aliases: ['khansi', 'khasi', 'dry cough'],
    effectTerms: ['cough'],
    common: true,
  ),
  SymptomInfo(
    'Breathlessness',
    SymptomCategory.chest,
    aliases: ['saans', 'shortness of breath', 'dama', 'breathing trouble'],
    effectTerms: ['breath', 'dyspnea'],
  ),
  SymptomInfo(
    'Wheezing',
    SymptomCategory.chest,
    aliases: ['whistling breath', 'seeti'],
    effectTerms: ['wheez', 'bronchospasm'],
  ),
  SymptomInfo(
    'Chest pain',
    SymptomCategory.chest,
    aliases: ['seene me dard', 'chest tightness'],
    effectTerms: ['chest pain', 'chest'],
  ),
  SymptomInfo(
    'Racing heart',
    SymptomCategory.chest,
    aliases: ['palpitations', 'dhadkan', 'heart racing', 'fast heartbeat'],
    effectTerms: ['palpit', 'heart rate', 'tachycardia'],
    common: true,
  ),
  // Skin and allergy
  SymptomInfo(
    'Rash or itching',
    SymptomCategory.skin,
    aliases: ['khujli', 'itching', 'allergy', 'daane', 'skin rash'],
    effectTerms: ['rash', 'itch', 'allerg', 'urticaria'],
    common: true,
  ),
  SymptomInfo(
    'Hives',
    SymptomCategory.skin,
    aliases: ['red patches', 'welts', 'chakatte'],
    effectTerms: ['hives', 'urticaria'],
  ),
  SymptomInfo(
    'Swelling',
    SymptomCategory.skin,
    aliases: ['sujan', 'edema', 'swollen feet', 'swollen face'],
    effectTerms: ['swell', 'edema', 'oedema'],
    common: true,
  ),
  SymptomInfo(
    'Dry skin',
    SymptomCategory.skin,
    aliases: ['skin dryness', 'peeling'],
    effectTerms: ['dry skin', 'dryness'],
  ),
  SymptomInfo(
    'Sweating',
    SymptomCategory.skin,
    aliases: ['pasina', 'night sweats'],
    effectTerms: ['sweat'],
  ),
  // Body
  SymptomInfo(
    'Fever',
    SymptomCategory.body,
    aliases: ['bukhar', 'temperature', 'high temperature'],
    effectTerms: ['fever'],
    common: true,
  ),
  SymptomInfo(
    'Weakness',
    SymptomCategory.body,
    aliases: ['kamzori', 'fatigue', 'tired', 'thakan', 'low energy'],
    effectTerms: ['weakness', 'fatigue', 'tired'],
    common: true,
  ),
  SymptomInfo(
    'Body ache',
    SymptomCategory.body,
    aliases: ['badan dard', 'body pain', 'muscle pain'],
    effectTerms: ['muscle pain', 'myalgia', 'body ache'],
  ),
  SymptomInfo(
    'Joint pain',
    SymptomCategory.body,
    aliases: ['jodo ka dard', 'arthritis', 'knee pain'],
    effectTerms: ['joint', 'arthralgia'],
  ),
  SymptomInfo(
    'Muscle cramps',
    SymptomCategory.body,
    aliases: ['cramp', 'pair me dard', 'leg cramps'],
    effectTerms: ['cramp'],
  ),
  SymptomInfo(
    'Back pain',
    SymptomCategory.body,
    aliases: ['kamar dard', 'back ache'],
    effectTerms: ['back pain'],
  ),
  SymptomInfo(
    'Chills',
    SymptomCategory.body,
    aliases: ['thand lagna', 'shivering'],
    effectTerms: ['chill'],
  ),
  SymptomInfo(
    'Weight gain or loss',
    SymptomCategory.body,
    aliases: ['weight change', 'vajan'],
    effectTerms: ['weight'],
  ),
  // Mouth, eyes, ears
  SymptomInfo(
    'Sore throat',
    SymptomCategory.mouth,
    aliases: ['gala dard', 'gale me dard', 'throat pain'],
    effectTerms: ['sore throat', 'throat'],
  ),
  SymptomInfo(
    'Dry mouth',
    SymptomCategory.mouth,
    aliases: ['mooh sukhna', 'dryness in mouth', 'thirsty'],
    effectTerms: ['dry mouth', 'dryness in mouth', 'dryness of mouth'],
  ),
  SymptomInfo(
    'Bad taste',
    SymptomCategory.mouth,
    aliases: ['metallic taste', 'taste change'],
    effectTerms: ['taste'],
  ),
  SymptomInfo(
    'Mouth ulcers',
    SymptomCategory.mouth,
    aliases: ['chhale', 'mouth sores'],
    effectTerms: ['ulcer', 'sore'],
  ),
  SymptomInfo(
    'Blurred vision',
    SymptomCategory.mouth,
    aliases: ['dhundhla dikhna', 'eye problem', 'blurry'],
    effectTerms: ['blurred', 'vision'],
  ),
  SymptomInfo(
    'Ringing in ears',
    SymptomCategory.mouth,
    aliases: ['tinnitus', 'kaan me awaaz'],
    effectTerms: ['tinnitus', 'ringing'],
  ),
  // Urine
  SymptomInfo(
    'Frequent urination',
    SymptomCategory.urine,
    aliases: ['baar baar peshab', 'peeing a lot'],
    effectTerms: ['urination', 'urinary'],
  ),
  SymptomInfo(
    'Burning urination',
    SymptomCategory.urine,
    aliases: ['peshab me jalan', 'painful urination'],
    effectTerms: ['burning urination', 'urinary'],
  ),
];

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The catalog entry named [name] (any case), if there is one.
SymptomInfo? symptomInfoFor(String name) {
  final n = _norm(name);
  for (final s in symptomCatalog) {
    if (s.name.toLowerCase() == n) return s;
  }
  return null;
}

/// Symptoms matching what the person typed: names and other names, best first.
List<SymptomInfo> searchSymptoms(String query, {int limit = 8}) {
  final q = _norm(query);
  if (q.isEmpty) return const [];
  final scored = <(int, SymptomInfo)>[];
  for (final s in symptomCatalog) {
    final name = s.name.toLowerCase();
    int? best;
    void consider(int score) {
      if (best == null || score < best!) best = score;
    }

    if (name.startsWith(q)) consider(0);
    if (name.split(' ').any((w) => w.startsWith(q))) consider(1);
    if (name.contains(q)) consider(2);
    for (final a in s.aliases) {
      if (a.startsWith(q)) consider(3);
      if (a.contains(q)) consider(4);
    }
    if (best != null) scored.add((best!, s));
  }
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in scored.take(limit)) e.$2];
}

/// Whether [symptom] appears in a medicine's side-effect text.
bool listedAsSideEffect(String symptom, String effects) {
  if (effects.isEmpty) return false;
  final e = effects.toLowerCase();
  final info = symptomInfoFor(symptom);
  final terms = info != null
      ? info.effectTerms
      : [
          for (final m in RegExp(
            r'[a-z]{4,}',
          ).allMatches(symptom.toLowerCase()))
            m.group(0)!,
        ];
  return terms.any(e.contains);
}
