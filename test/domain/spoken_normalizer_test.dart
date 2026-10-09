import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medications/domain/spoken_normalizer.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

void main() {
  test('morning and night after food for five days', () {
    final text = normalizeSpoken(
      'Dolo 650 morning and night after food for five days',
    );
    final p = parseShorthand(text);
    expect(p.query, 'dolo 650');
    expect(p.amounts![DaySlot.morning], 1);
    expect(p.amounts![DaySlot.afternoon], 0);
    expect(p.amounts![DaySlot.night], 1);
    expect(p.timing, MealTiming.afterFood);
    expect(p.days, 5);
  });

  test('twice a day and three times a day', () {
    expect(
      normalizeSpoken('pantoprazole twice a day before food'),
      contains('1-0-1'),
    );
    expect(normalizeSpoken('amoxicillin three times a day'), contains('1-1-1'));
    expect(normalizeSpoken('metformin once a day'), contains('1-0-0'));
  });

  test('digits spoken one by one', () {
    expect(
      normalizeSpoken('pan 40 one zero zero before food'),
      contains('1-0-0'),
    );
    expect(normalizeSpoken('dolo 650 1 0 1'), contains('1-0-1'));
  });

  test('hindi words', () {
    final p = parseShorthand(
      normalizeSpoken('crocin subah raat khane ke baad paanch din'),
    );
    expect(p.query, 'crocin');
    expect(p.amounts![DaySlot.morning], 1);
    expect(p.amounts![DaySlot.night], 1);
    expect(p.timing, MealTiming.afterFood);
    expect(p.days, 5);
  });

  test('only a name is left alone', () {
    expect(normalizeSpoken('Azithromycin'), 'azithromycin');
    expect(normalizeSpoken(''), '');
  });
}
