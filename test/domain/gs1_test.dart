import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/barcode/domain/gs1.dart';

void main() {
  test('plain EAN-13 becomes a 14-digit GTIN', () {
    expect(parseGs1('8901234567890').gtin, '08901234567890');
    expect(barcodeKey('8901234567890'), 'gtin:08901234567890');
  });

  test('bracketed element string', () {
    final d = parseGs1('(01)08901234567890(17)280531(10)AB12');
    expect(d.gtin, '08901234567890');
    expect(d.expiry, DateTime(2028, 5, 31));
    expect(d.batch, 'AB12');
  });

  test('unbracketed element string with day 00 means end of month', () {
    final d = parseGs1(
      '0108901234567890172806001'
      '0AB12',
    );
    expect(d.gtin, '08901234567890');
    expect(d.expiry, DateTime(2028, 6, 30));
    expect(d.batch, 'AB12');
  });

  test('GS separator after a variable-length field', () {
    final d = parseGs1('0108901234567890\u001d10LOT7\u001d17250131');
    expect(d.batch, 'LOT7');
    expect(d.expiry, DateTime(2025, 1, 31));
  });

  test('GS1 Digital Link', () {
    final d = parseGs1(
      'https://id.gs1.org/01/08901234567890/10/AB12?17=280531',
    );
    expect(d.gtin, '08901234567890');
    expect(d.batch, 'AB12');
    expect(d.expiry, DateTime(2028, 5, 31));
  });

  test('symbology identifier is ignored', () {
    expect(parseGs1(']C10108901234567890').gtin, '08901234567890');
  });

  test('unknown text falls back to a raw key', () {
    expect(parseGs1('hello').gtin, isNull);
    expect(barcodeKey('1500563027'), 'raw:1500563027');
  });
}
