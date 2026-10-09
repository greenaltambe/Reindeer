import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';

void main() {
  test('plain name is untouched', () {
    final p = parseShorthand('dolo 650');
    expect(p.query, 'dolo 650');
    expect(p.hasSchedule, isFalse);
  });

  test('m-a-n pattern, food and days', () {
    final p = parseShorthand('Dolo 650 1-0-1 after food 5 days');
    expect(p.query, 'dolo 650');
    expect(p.amounts![DaySlot.morning], 1);
    expect(p.amounts![DaySlot.afternoon], 0);
    expect(p.amounts![DaySlot.night], 1);
    expect(p.timing, MealTiming.afterFood);
    expect(p.days, 5);
    expect(p.summary, '1-0-1 · after food · 5 days');
  });

  test('halves and fractions', () {
    final p = parseShorthand('thyronorm ½-0-0 ac');
    expect(p.amounts![DaySlot.morning], 0.5);
    expect(p.timing, MealTiming.beforeFood);
    expect(parseShorthand('x 1/2-0-1').amounts![DaySlot.morning], 0.5);
  });

  test('abbreviations', () {
    expect(parseShorthand('pan 40 od').amounts![DaySlot.night], 0);
    final bd = parseShorthand('augmentin bd pc 1w');
    expect(bd.amounts![DaySlot.morning], 1);
    expect(bd.amounts![DaySlot.night], 1);
    expect(bd.timing, MealTiming.afterFood);
    expect(bd.days, 7);
    expect(parseShorthand('azee tds').amounts![DaySlot.afternoon], 1);
    final hs = parseShorthand('montair hs');
    expect(hs.amounts![DaySlot.morning], 0);
    expect(hs.amounts![DaySlot.night], 1);
  });

  test('durations', () {
    expect(parseShorthand('cefix 5d').days, 5);
    expect(parseShorthand('cefix x 3 days').days, 3);
    expect(parseShorthand('cefix x 3 days').query, 'cefix');
    expect(parseShorthand('metformin 2 weeks').days, 14);
    expect(parseShorthand('vit d 1 month').days, 30);
    // A strength is not a duration.
    expect(parseShorthand('dolo 650').days, isNull);
    expect(parseShorthand('amox 500mg').query, 'amox 500mg');
  });

  test('with food and all zero pattern', () {
    expect(parseShorthand('metformin with food').timing, MealTiming.withFood);
    expect(parseShorthand('abc 0-0-0').amounts, isNull);
  });

  test('every other day', () {
    expect(
      parseShorthand('metformin 500 1-0-1 every other day').intervalDays,
      2,
    );
    expect(parseShorthand('warfarin eod').intervalDays, 2);
    expect(parseShorthand('warfarin alternate days').query, 'warfarin');
    expect(parseShorthand('dolo 650').intervalDays, isNull);
  });
}
