import 'dart:math' as math;

import 'package:reindeer/features/health/domain/measure_type.dart';

/// How seriously to take a reading.
enum FlagLevel { note, warning, urgent }

/// A short, neutral message about a reading. Never a diagnosis.
class ReadingFlag {
  const ReadingFlag(this.level, this.title, this.message);

  final FlagLevel level;
  final String title;
  final String message;
}

const _urgentAdvice =
    'Rest and measure again in a few minutes. If it stays like this, or you feel '
    'unwell (chest pain, severe headache, breathlessness, confusion, fainting), '
    'get medical help now.';

/// Looks at a new reading. Fixed limits come first; if they find nothing and
/// there is enough history, the reading is compared with the person's own
/// recent values.
///
/// [previous] holds earlier readings of the same type, oldest first.
ReadingFlag? assessReading(Measurement m, List<Measurement> previous) {
  return _absolute(m) ?? _personal(m, previous);
}

ReadingFlag? _absolute(Measurement m) {
  final v = m.value;
  switch (m.type) {
    case MeasureType.bloodPressure:
      final d = m.value2;
      if (d == null) return null;
      if (v >= 180 || d >= 120) {
        return const ReadingFlag(
          FlagLevel.urgent,
          'Very high blood pressure',
          _urgentAdvice,
        );
      }
      if (v < 90 || d < 60) {
        return const ReadingFlag(
          FlagLevel.warning,
          'Low blood pressure',
          'This is lower than usual. If you feel dizzy or faint, sit or lie down and drink water. '
              'Tell your doctor if it keeps happening.',
        );
      }
      if (v >= 140 || d >= 90) {
        return const ReadingFlag(
          FlagLevel.warning,
          'High blood pressure',
          'This is above the usual limit. Rest and measure again later. '
              'If it stays high, show your readings to your doctor.',
        );
      }
      return null;
    case MeasureType.glucose:
      if (v < 70) {
        return const ReadingFlag(
          FlagLevel.urgent,
          'Low blood sugar',
          'Eat or drink something sugary now (juice, glucose, sugar). Recheck in 15 minutes. '
              'If you feel confused or faint, get medical help.',
        );
      }
      if (v >= 300) {
        return const ReadingFlag(
          FlagLevel.urgent,
          'Very high blood sugar',
          'Drink water and recheck. If it stays this high, or you feel very thirsty, sick '
              'or drowsy, contact your doctor or get medical help now.',
        );
      }
      final fasting = m.context == 'Fasting';
      if (fasting && v >= 126) {
        return const ReadingFlag(
          FlagLevel.warning,
          'High fasting sugar',
          'This is above the usual fasting limit. Show your readings to your doctor.',
        );
      }
      if (!fasting && v >= 200) {
        return const ReadingFlag(
          FlagLevel.warning,
          'High blood sugar',
          'This is high. Note what you ate, recheck later, and show your readings to your doctor.',
        );
      }
      return null;
    case MeasureType.pulse:
      if (v < 40 || v > 150) {
        return const ReadingFlag(
          FlagLevel.urgent,
          'Unusual pulse',
          _urgentAdvice,
        );
      }
      if (v < 50 || v > 110) {
        return const ReadingFlag(
          FlagLevel.warning,
          'Pulse outside the usual range',
          'Rest for a few minutes and measure again. Tell your doctor if it keeps happening.',
        );
      }
      return null;
    case MeasureType.weight:
    case MeasureType.bodyFat:
      return null;
  }
}

/// Compares with the average of the last few readings of the same type.
ReadingFlag? _personal(Measurement m, List<Measurement> previous) {
  final recent = previous.length > 10
      ? previous.sublist(previous.length - 10)
      : previous;
  if (recent.length < 4) return null;

  final values = [for (final r in recent) r.value];
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
      values.length;
  final sd = math.sqrt(variance);
  final diff = m.value - mean;

  // Ignore tiny absolute changes even when the history is very steady.
  final minChange = switch (m.type) {
    MeasureType.weight => 2.0,
    MeasureType.bloodPressure => 20.0,
    MeasureType.glucose => 40.0,
    MeasureType.pulse => 20.0,
    MeasureType.bodyFat => 3.0,
  };
  if (diff.abs() < minChange) return null;
  if (sd > 0 && diff.abs() < 2.5 * sd) return null;

  final direction = diff > 0 ? 'higher' : 'lower';
  final usual = m.type.formatValue(mean);
  return ReadingFlag(
    FlagLevel.note,
    'Unusual for you',
    'This is much $direction than your recent readings (usually about $usual ${m.type.unit}). '
        'It may be nothing: check you measured the same way, and measure again.',
  );
}
