import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';

void main() {
  test('weeks start on Sunday', () {
    // 7 Oct 2026 is a Wednesday; the Sunday before is 4 Oct.
    expect(startOfWeek(DateTime(2026, 10, 7, 15, 30)), DateTime(2026, 10, 4));
    expect(
      startOfWeek(DateTime(2026, 10, 4)),
      DateTime(2026, 10, 4),
    ); // a Sunday
    expect(
      startOfWeek(DateTime(2026, 10, 10)),
      DateTime(2026, 10, 4),
    ); // Saturday
    expect(
      startOfWeek(DateTime(2026, 10, 3)),
      DateTime(2026, 9, 27),
    ); // across a month
  });

  test('labels', () {
    expect(formatWeekdayShort(DateTime(2026, 10, 7)), 'Wed');
    expect(formatMonthYear(DateTime(2026, 10, 7)), 'October 2026');
  });
}
