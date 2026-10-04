/// Data read from a GS1 element string, GS1 Digital Link, or plain product
/// barcode. Any field may be null.
class Gs1Data {
  const Gs1Data({this.gtin, this.batch, this.expiry, this.serial});

  /// 14-digit GTIN (shorter codes are left-padded with zeros).
  final String? gtin;
  final String? batch;

  /// Expiry date; when the code says day `00`, the last day of that month.
  final DateTime? expiry;
  final String? serial;
}

/// Parses what a pack's barcode or QR code says.
///
/// Understands:
/// - plain EAN-8, UPC-A, EAN-13 and GTIN-14 digits,
/// - GS1 element strings, with or without brackets, for example
///   `(01)08901234567890(17)280531(10)AB12` or the same with FNC1/GS separators,
/// - GS1 Digital Link URLs such as `https://id.example/01/08901234567890/10/AB12?17=280531`.
Gs1Data parseGs1(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return const Gs1Data();
  // Symbology identifier such as ]C1, ]d2, ]Q3.
  if (s.startsWith(']') && s.length > 3) s = s.substring(3);

  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) {
    return _parseDigitalLink(s);
  }

  if (RegExp(r'^\d{8}$|^\d{12,14}$').hasMatch(s)) {
    return Gs1Data(gtin: s.padLeft(14, '0'));
  }

  if (s.contains('(')) {
    // Turn "(01)123(17)280531" into "01123\x1d17280531" with explicit separators.
    s = s
        .replaceAllMapped(RegExp(r'\((\d{2,4})\)'), (m) => '\u001d${m[1]}')
        .replaceFirst('\u001d', '');
  }
  return _parseElementString(s);
}

const Map<String, int> _fixedLengths = {
  '00': 18,
  '01': 14,
  '02': 14,
  '11': 6,
  '12': 6,
  '13': 6,
  '15': 6,
  '16': 6,
  '17': 6,
};

const Set<String> _variableAis = {
  '10',
  '21',
  '22',
  '240',
  '241',
  '30',
  '37',
  '91',
  '92',
  '93',
  '94',
  '95',
  '96',
  '97',
  '98',
  '99',
};

Gs1Data _parseElementString(String s) {
  final values = <String, String>{};
  var i = 0;
  while (i < s.length) {
    if (s[i] == '\u001d') {
      i++;
      continue;
    }
    String? ai;
    for (final len in [2, 3]) {
      if (i + len > s.length) continue;
      final cand = s.substring(i, i + len);
      if (_fixedLengths.containsKey(cand) || _variableAis.contains(cand)) {
        ai = cand;
        break;
      }
    }
    if (ai == null) {
      break; // unknown application identifier: stop, keep what we have
    }
    i += ai.length;
    final fixed = _fixedLengths[ai];
    if (fixed != null) {
      if (i + fixed > s.length) break;
      values[ai] = s.substring(i, i + fixed);
      i += fixed;
    } else {
      var end = s.indexOf('\u001d', i);
      if (end < 0) end = s.length;
      if (end - i > 20) end = i + 20;
      values[ai] = s.substring(i, end);
      i = end;
    }
  }
  return _build(values);
}

Gs1Data _parseDigitalLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return const Gs1Data();
  final values = <String, String>{};
  final seg = uri.pathSegments;
  for (var i = 0; i + 1 < seg.length; i++) {
    final key = seg[i];
    if (RegExp(r'^\d{2,4}$').hasMatch(key)) {
      values[key] = Uri.decodeComponent(seg[i + 1]);
      i++;
    }
  }
  uri.queryParameters.forEach((k, v) {
    if (RegExp(r'^\d{2,4}$').hasMatch(k)) values[k] = v;
  });
  return _build(values);
}

Gs1Data _build(Map<String, String> v) {
  final gtinRaw = v['01'];
  final gtin = gtinRaw != null && RegExp(r'^\d{14}$').hasMatch(gtinRaw)
      ? gtinRaw
      : null;
  return Gs1Data(
    gtin: gtin,
    batch: v['10'],
    expiry: _parseDate(v['17']),
    serial: v['21'],
  );
}

DateTime? _parseDate(String? yymmdd) {
  if (yymmdd == null || !RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  if (mm < 1 || mm > 12) return null;
  final year = 2000 + yy;
  if (dd == 0) return DateTime(year, mm + 1, 0); // last day of the month
  if (dd > 31) return null;
  return DateTime(year, mm, dd);
}

/// Stable key for remembering which medicine a barcode belongs to.
///
/// Uses the GTIN when there is one (so every batch of a product shares a key),
/// otherwise the raw text.
String barcodeKey(String raw) {
  final data = parseGs1(raw);
  final gtin = data.gtin;
  if (gtin != null) return 'gtin:$gtin';
  return 'raw:${raw.trim()}';
}
