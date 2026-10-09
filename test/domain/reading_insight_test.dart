import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/domain/reading_insight.dart';

Measurement m(
  MeasureType t,
  double v, {
  double? v2,
  String? ctx,
  int day = 1,
}) => Measurement(
  type: t,
  value: v,
  value2: v2,
  context: ctx,
  at: DateTime(2026, 10, day),
);

void main() {
  test('normal blood pressure has no flag', () {
    expect(
      assessReading(m(MeasureType.bloodPressure, 120, v2: 80), const []),
      isNull,
    );
  });

  test('blood pressure levels', () {
    expect(
      assessReading(m(MeasureType.bloodPressure, 150, v2: 95), const [])!.level,
      FlagLevel.warning,
    );
    expect(
      assessReading(
        m(MeasureType.bloodPressure, 190, v2: 100),
        const [],
      )!.level,
      FlagLevel.urgent,
    );
    expect(
      assessReading(m(MeasureType.bloodPressure, 85, v2: 55), const [])!.level,
      FlagLevel.warning,
    );
  });

  test('glucose depends on context', () {
    expect(
      assessReading(m(MeasureType.glucose, 130, ctx: 'Fasting'), const []),
      isNotNull,
    );
    expect(
      assessReading(m(MeasureType.glucose, 130, ctx: 'After meal'), const []),
      isNull,
    );
    expect(
      assessReading(m(MeasureType.glucose, 60), const [])!.level,
      FlagLevel.urgent,
    );
    expect(
      assessReading(m(MeasureType.glucose, 320), const [])!.level,
      FlagLevel.urgent,
    );
  });

  test('pulse limits', () {
    expect(assessReading(m(MeasureType.pulse, 72), const []), isNull);
    expect(
      assessReading(m(MeasureType.pulse, 120), const [])!.level,
      FlagLevel.warning,
    );
    expect(
      assessReading(m(MeasureType.pulse, 35), const [])!.level,
      FlagLevel.urgent,
    );
  });

  test('weight jump compared with own history', () {
    final history = [
      for (var i = 0; i < 6; i++)
        m(MeasureType.weight, 70 + (i % 2) * 0.2, day: i + 1),
    ];
    final flag = assessReading(m(MeasureType.weight, 74.5, day: 10), history);
    expect(flag, isNotNull);
    expect(flag!.level, FlagLevel.note);
    expect(
      assessReading(m(MeasureType.weight, 70.4, day: 10), history),
      isNull,
    );
  });

  test('too little history gives no personal flag', () {
    final history = [m(MeasureType.weight, 70), m(MeasureType.weight, 70)];
    expect(assessReading(m(MeasureType.weight, 80), history), isNull);
  });
}
