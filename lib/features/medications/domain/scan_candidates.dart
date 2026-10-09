/// Picks the lines of text read off a medicine strip or bottle that are most
/// likely to be the medicine's name, best guess first.
///
/// Packaging is full of other words (batch numbers, "tablets IP", price,
/// manufacturer). Brand names are usually short, mostly letters, and may be
/// followed by a strength such as `650` or `500mg`.
List<String> medicineNameCandidates(String recognized, {int limit = 8}) {
  const noise = {
    'tablets',
    'tablet',
    'capsules',
    'capsule',
    'ip',
    'bp',
    'usp',
    'each',
    'film',
    'coated',
    'uncoated',
    'contains',
    'composition',
    'mfg',
    'mfd',
    'exp',
    'expiry',
    'batch',
    'lic',
    'price',
    'mrp',
    'inclusive',
    'taxes',
    'store',
    'below',
    'keep',
    'out',
    'reach',
    'children',
    'schedule',
    'rx',
    'manufactured',
    'marketed',
    'by',
    'for',
    'the',
    'and',
    'of',
    'strip',
    'pack',
    'use',
    'only',
    'under',
    'supervision',
    'registered',
    'medical',
    'practitioner',
    'dosage',
    'as',
    'directed',
    'physician',
    'date',
    'no',
    'limited',
    'ltd',
    'pvt',
    'pharma',
    'pharmaceuticals',
    'laboratories',
    'lab',
    'labs',
    'india',
    'made',
    'in',
    'to',
    'be',
    'sold',
    'rs',
    'inr',
    'prescription',
    'warning',
    'protect',
    'from',
    'light',
    'moisture',
  };
  final seen = <String>{};
  final scored = <({String line, double score, int order})>[];
  final lines = recognized.split(RegExp(r'[\r\n]+'));
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replaceAll(RegExp(r"[^A-Za-z0-9 .+\-]"), ' ');
    line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    if (letters < 3 || line.length > 40) continue;
    final words = line
        .split(' ')
        .where((w) => RegExp(r'[A-Za-z]{2,}').hasMatch(w))
        .toList();
    if (words.isEmpty) continue;
    final real = words
        .where(
          (w) => !noise.contains(
            w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''),
          ),
        )
        .toList();
    if (real.isEmpty) continue;
    // A line that is mostly digits is a batch number or a price.
    final digits = RegExp(r'[0-9]').allMatches(line).length;
    if (digits > letters) continue;

    var score = 0.0;
    if (RegExp(r'^[A-Za-z]{4,}( ?[0-9]{2,4} ?(mg|mcg|ml|g)?)?$')
        .hasMatch(line)) {
      score += 3; // looks like "Dolo 650" or "Pantocid"
    }
    if (real.length <= 2) score += 1;
    score -= (words.length - real.length) * 0.5;
    score -= i * 0.05; // names are usually near the top

    final key = line.toLowerCase();
    if (!seen.add(key)) continue;
    scored.add((line: line, score: score, order: i));
  }
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    return c != 0 ? c : a.order.compareTo(b.order);
  });
  return [for (final s in scored.take(limit)) s.line];
}
