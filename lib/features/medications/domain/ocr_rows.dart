/// One line of text found by the OCR engine, with its position on the photo.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.slope = 0,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// How much the line's top edge drops per pixel to the right (a tilted photo).
  final double slope;

  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get width => right - left;
}

/// Puts OCR lines that sit side by side on the page back onto one text line.
///
/// OCR engines group text into columns, so on a prescription the medicine name
/// ("Tab Telma 40") and its dose written further right ("1-0-1") come back as
/// separate blocks, far apart in the text. Reading by position instead keeps
/// each medicine and its dose together.
String joinOcrRows(List<OcrLine> lines) {
  final usable = [
    for (final l in lines)
      if (l.text.trim().isNotEmpty && l.height > 0) l,
  ];
  if (usable.isEmpty) return '';

  // Undo a small tilt so lines on the same row line up again.
  final slopes = [
    for (final l in usable)
      if (l.width > l.height * 2) l.slope,
  ]..sort();
  var tilt = slopes.isEmpty ? 0.0 : slopes[slopes.length ~/ 2];
  if (tilt.abs() > 0.2) tilt = 0; // more than ~11°, not a simple tilt
  double levelled(OcrLine l) => l.centerY - l.centerX * tilt;

  final sorted = [...usable]
    ..sort((a, b) => levelled(a).compareTo(levelled(b)));

  final rows = <_Row>[];
  for (final line in sorted) {
    final y = levelled(line);
    _Row? home;
    // Only the last few rows can overlap, since lines arrive top to bottom.
    for (var i = rows.length - 1; i >= 0 && i >= rows.length - 3; i--) {
      final row = rows[i];
      final reach = (row.height < line.height ? row.height : line.height) / 2;
      if ((row.centerY - y).abs() <= reach &&
          !row.lines.any((o) => _overlapsHorizontally(o, line))) {
        home = row;
        break;
      }
    }
    if (home == null) {
      rows.add(_Row(line, y));
    } else {
      home.add(line, y);
    }
  }

  rows.sort((a, b) => a.centerY.compareTo(b.centerY));
  return [
    for (final row in rows)
      (row.lines..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text.trim())
          .join('  '),
  ].join('\n');
}

bool _overlapsHorizontally(OcrLine a, OcrLine b) {
  final overlap =
      (a.right < b.right ? a.right : b.right) -
      (a.left > b.left ? a.left : b.left);
  final narrower = a.width < b.width ? a.width : b.width;
  return overlap > narrower * 0.5;
}

class _Row {
  _Row(OcrLine first, double y) {
    add(first, y);
  }

  final List<OcrLine> lines = [];
  double _ySum = 0;
  double _hSum = 0;

  double get centerY => _ySum / lines.length;
  double get height => _hSum / lines.length;

  void add(OcrLine line, double y) {
    lines.add(line);
    _ySum += y;
    _hSum += line.height;
  }
}
