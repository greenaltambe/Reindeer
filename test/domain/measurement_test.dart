import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';

void main() {
  test('display formats numbers and units', () {
    final w = Measurement(
      type: MeasureType.weight,
      value: 72.5,
      at: DateTime(2026, 10, 1),
    );
    expect(w.display, '72.5 kg');
    final bp = Measurement(
      type: MeasureType.bloodPressure,
      value: 120,
      value2: 80,
      at: DateTime(2026, 10, 1),
    );
    expect(bp.display, '120/80 mmHg');
    final g = Measurement(
      type: MeasureType.glucose,
      value: 98.4,
      at: DateTime(2026, 10, 1),
    );
    expect(g.display, '98 mg/dL');
  });

  test('plausible range catches typing mistakes', () {
    expect(MeasureType.weight.plausible(72), isTrue);
    expect(MeasureType.weight.plausible(720), isFalse);
    expect(MeasureType.pulse.plausible(5), isFalse);
  });

  test('bmi needs a usable height', () {
    expect(bmi(70, 175)!.toStringAsFixed(1), '22.9');
    expect(bmi(70, null), isNull);
    expect(bmi(70, 10), isNull);
  });

  test('stats', () {
    final s = stats([2, 4, 9])!;
    expect((s.min, s.max, s.avg), (2.0, 9.0, 5.0));
    expect(stats(const <double>[]), isNull);
  });

  test('reminder encodes and decodes', () {
    const daily = MeasureReminder(minutes: 8 * 60 + 5);
    expect(daily.encode(), '8:05|daily');
    expect(MeasureReminder.decode('8:05|daily')!.minutes, 485);
    const weekly = MeasureReminder(minutes: 7 * 60, weekday: 3);
    expect(MeasureReminder.decode(weekly.encode())!.weekday, 3);
    expect(MeasureReminder.decode(''), isNull);
    expect(MeasureReminder.decode('25:00|daily'), isNull);
    expect(MeasureReminder.decode('8:00|w9'), isNull);
    expect(MeasureReminder.decode('garbage'), isNull);
  });
}
