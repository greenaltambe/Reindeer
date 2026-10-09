import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/ocr_rows.dart';

OcrLine _l(String t, double x, double y, {double w = 200, double slope = 0}) =>
    OcrLine(
      text: t,
      left: x,
      top: y,
      right: x + w,
      bottom: y + 30,
      slope: slope,
    );

void main() {
  test('puts a dose column back next to its medicine', () {
    // OCR returns the names block first, then the dose block.
    final text = joinOcrRows([
      _l('Tab Telma 40', 50, 100),
      _l('Tab Glycomet 500', 50, 160),
      _l('1-0-0', 600, 104, w: 80),
      _l('1-0-1', 600, 158, w: 80),
    ]);
    expect(text, 'Tab Telma 40  1-0-0\nTab Glycomet 500  1-0-1');
  });

  test('keeps stacked lines apart', () {
    final text = joinOcrRows([
      _l('Tab Telma 40', 50, 100),
      _l('Tab Pan 40', 50, 118),
    ]);
    expect(text, 'Tab Telma 40\nTab Pan 40');
  });

  test('follows a tilted photo', () {
    // Page tilted so each line drops 0.08 px per px to the right.
    const s = 0.08;
    final text = joinOcrRows([
      _l('Tab Telma 40', 50, 100, slope: s),
      _l('1-0-0', 600, 100 + 550 * s, w: 80, slope: s),
      _l('Tab Pan 40', 50, 150, slope: s),
      _l('0-0-1', 600, 150 + 550 * s, w: 80, slope: s),
    ]);
    expect(text, 'Tab Telma 40  1-0-0\nTab Pan 40  0-0-1');
  });
}
