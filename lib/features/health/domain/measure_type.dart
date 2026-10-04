import 'package:reindeer/features/medications/domain/models/dose_unit.dart'
    show formatAmount;

/// The few readings Reindeer tracks. Kept small on purpose: this is not a
/// fitness app.
enum MeasureType {
  weight('Weight', 'kg', 20, 300, 1),
  bloodPressure('Blood pressure', 'mmHg', 40, 300, 0),
  glucose('Blood sugar', 'mg/dL', 20, 800, 0),
  bodyFat('Body fat', '%', 2, 70, 1),
  pulse('Pulse', 'bpm', 20, 250, 0);

  const MeasureType(this.label, this.unit, this.min, this.max, this.decimals);

  final String label;
  final String unit;

  /// Plausible range; anything outside is probably a typing mistake.
  final double min;
  final double max;
  final int decimals;

  /// Blood pressure has two numbers (top / bottom).
  bool get hasSecond => this == MeasureType.bloodPressure;

  String get firstLabel => hasSecond ? 'Top (systolic)' : label;
  String get secondLabel => 'Bottom (diastolic)';

  /// Extra choices for when the reading was taken.
  List<String> get contexts => switch (this) {
    MeasureType.glucose => const ['Fasting', 'After meal', 'Bedtime', 'Random'],
    _ => const [],
  };

  /// A short, neutral hint. Never a diagnosis.
  String get hint => switch (this) {
    MeasureType.weight =>
      'Weigh yourself at the same time of day for a fair trend.',
    MeasureType.bloodPressure =>
      'Sit and rest for a few minutes before measuring.',
    MeasureType.glucose => 'Note whether it was fasting or after a meal.',
    MeasureType.bodyFat => 'Reading from a body-composition scale or machine.',
    MeasureType.pulse => 'Beats per minute, at rest if you can.',
  };

  static MeasureType? byName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }

  String formatValue(double v) => decimals == 0
      ? v.round().toString()
      : formatAmount(double.parse(v.toStringAsFixed(decimals)));

  /// Whether [v] is a believable value for the first (or only) number.
  bool plausible(double v) => v >= min && v <= max;
}

/// One saved reading.
class Measurement {
  const Measurement({
    this.id,
    required this.type,
    required this.value,
    this.value2,
    this.context,
    required this.at,
    this.note,
  });

  final int? id;
  final MeasureType type;
  final double value;
  final double? value2;
  final String? context;
  final DateTime at;
  final String? note;

  /// For example `72.5 kg` or `120/80 mmHg`.
  String get display {
    final v = type.hasSecond && value2 != null
        ? '${type.formatValue(value)}/${type.formatValue(value2!)}'
        : type.formatValue(value);
    return '$v ${type.unit}';
  }

  /// Just the number part, without the unit.
  String get number => type.hasSecond && value2 != null
      ? '${type.formatValue(value)}/${type.formatValue(value2!)}'
      : type.formatValue(value);
}

/// Body mass index from kilograms and centimetres; null if either is unusable.
double? bmi(double weightKg, double? heightCm) {
  if (heightCm == null || heightCm < 50 || heightCm > 260 || weightKg <= 0) {
    return null;
  }
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Min, average and max of [values]; null for an empty list.
({double min, double avg, double max})? stats(Iterable<double> values) {
  if (values.isEmpty) return null;
  var min = double.infinity, max = -double.infinity, sum = 0.0;
  var n = 0;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
    sum += v;
    n++;
  }
  return (min: min, avg: sum / n, max: max);
}

/// A repeating reminder to take a reading.
class MeasureReminder {
  const MeasureReminder({required this.minutes, this.weekday});

  /// Minutes after midnight.
  final int minutes;

  /// 1 = Monday .. 7 = Sunday; null means every day.
  final int? weekday;

  String encode() =>
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}|${weekday == null ? 'daily' : 'w$weekday'}';

  static MeasureReminder? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('|');
    if (parts.length != 2) return null;
    final hm = parts[0].split(':');
    if (hm.length != 2) return null;
    final h = int.tryParse(hm[0]);
    final m = int.tryParse(hm[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    int? weekday;
    if (parts[1] != 'daily') {
      if (!parts[1].startsWith('w')) return null;
      weekday = int.tryParse(parts[1].substring(1));
      if (weekday == null || weekday < 1 || weekday > 7) return null;
    }
    return MeasureReminder(minutes: h * 60 + m, weekday: weekday);
  }

  static String settingsKey(MeasureType t) => 'mrem_${t.name}';
}
