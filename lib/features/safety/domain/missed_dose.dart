import 'package:reindeer/features/allergy/domain/allergy.dart';

/// General advice for a dose that was missed. Not specific to any medicine.
class MissedDoseGuidance {
  const MissedDoseGuidance({
    required this.headline,
    required this.points,
    required this.needsExtraCare,
    required this.isAntibiotic,
  });

  final String headline;
  final List<String> points;

  /// Medicines where a missed dose can matter a lot (blood thinners, insulin,
  /// thyroid, seizure medicines and similar).
  final bool needsExtraCare;
  final bool isAntibiotic;
}

const _extraCareWords = {
  'warfarin',
  'acenocoumarol',
  'insulin',
  'levothyroxine',
  'thyroxine',
  'phenytoin',
  'carbamazepine',
  'valproate',
  'valproic',
  'divalproex',
  'digoxin',
  'methotrexate',
  'lithium',
  'levetiracetam',
  'ethinylestradiol',
};

const _antibioticLabels = {
  'Penicillins',
  'Cephalosporins',
  'Sulfa drugs',
  'Macrolide antibiotics',
  'Quinolone antibiotics',
  'Tetracyclines',
  'Metronidazole and similar',
};

Set<String> _words(String text) => {
  for (final m in RegExp(r'[a-z]{4,}').allMatches(text.toLowerCase()))
    m.group(0)!,
};

/// Whether the name, composition or ingredient words look like an antibiotic.
bool looksLikeAntibiotic(String text) {
  final words = _words(text);
  for (final g in allergyGroups) {
    if (_antibioticLabels.contains(g.label) && words.any(g.matchesWord)) {
      return true;
    }
  }
  return false;
}

bool needsExtraCare(String text) => _words(text).any(_extraCareWords.contains);

/// Advice for a dose due at [dueAt] that has not been taken at [now].
///
/// [nextDoseAt] is the next planned dose of the same medicine, if known.
/// [text] is the name, composition and ingredient words, space separated.
MissedDoseGuidance missedDoseGuidance({
  required String text,
  required DateTime dueAt,
  required DateTime now,
  DateTime? nextDoseAt,
}) {
  final special = needsExtraCare(text);
  final antibiotic = looksLikeAntibiotic(text);
  final points = <String>[];

  if (special) {
    points.add(
      'This kind of medicine needs extra care when a dose is missed. '
      'Do not guess: call your doctor or pharmacist for advice.',
    );
  } else {
    final soon =
        nextDoseAt != null &&
        nextDoseAt.difference(now) < const Duration(hours: 2);
    points.add(
      soon
          ? 'Your next dose is due soon. Skip the missed dose and take the next one at its time.'
          : 'Take it as soon as you remember.',
    );
  }
  points.add('Never take two doses together to catch up.');
  if (antibiotic) {
    points.add(
      'Antibiotics work best when the whole course is finished. Try not to miss doses, '
      'and finish the course unless your doctor tells you to stop.',
    );
  }
  points.add(
    'This is general advice. If you are unsure, ask your pharmacist or doctor.',
  );

  return MissedDoseGuidance(
    headline: 'Missed a dose?',
    points: points,
    needsExtraCare: special,
    isAntibiotic: antibiotic,
  );
}
