import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/prescription_scan_parser.dart';

void main() {
  group('PrescriptionScanParser', () {
    test('parses multi-line prescription with clinical shorthand', () async {
      const rawPrescription = '''
Dr. R. K. Sharma Clinic
MBBS, MD (Medicine) Reg: 45892
Patient: Rajesh Verma  Age: 62  Date: 12/10/2026
BP: 130/80 mmHg

Rx:
1. Tab Telma 40 1-0-0 before food
2. Tab Glycomet 500 SR 1-0-1 after food x 30 days
3. Cap Omeprazole 20mg 1-0-0 before breakfast
4. Tab Rosuvas 10 0-0-1 night

Review after 1 month.
Signature: Dr. Sharma
''';

      final items = await PrescriptionScanParser.parse(rawPrescription);

      expect(items.length, 4);

      // Telma 40
      final telma = items.firstWhere((i) => i.name.toLowerCase().contains('telma'));
      expect(telma.amountMorning, 1.0);
      expect(telma.amountAfternoon, 0.0);
      expect(telma.amountNight, 0.0);
      expect(telma.mealTiming, MealTiming.beforeFood);
      expect(telma.unit, DoseUnit.tablet);

      // Glycomet 500 SR
      final glycomet = items.firstWhere((i) => i.name.toLowerCase().contains('glycomet'));
      expect(glycomet.amountMorning, 1.0);
      expect(glycomet.amountAfternoon, 0.0);
      expect(glycomet.amountNight, 1.0);
      expect(glycomet.mealTiming, MealTiming.afterFood);
      expect(glycomet.durationDays, 30);

      // Omeprazole
      final omeprazole = items.firstWhere((i) => i.name.toLowerCase().contains('omeprazole'));
      expect(omeprazole.unit, DoseUnit.capsule);
      expect(omeprazole.amountMorning, 1.0);
      expect(omeprazole.mealTiming, MealTiming.beforeFood);

      // Rosuvas 10
      final rosuvas = items.firstWhere((i) => i.name.toLowerCase().contains('rosuvas'));
      expect(rosuvas.amountNight, 1.0);
    });

    test('filters out clinic headers and patient metadata lines', () async {
      const headerNoiseOnly = '''
Apollo Health City Hospital
Dr. A. Sen, MBBS, MS
Phone: +91 9876543210
Date: 2026-10-09
Patient: Anjali Devi (Female, 55 yrs)
Weight: 68 kg, Pulse: 72 bpm
''';

      final items = await PrescriptionScanParser.parse(headerNoiseOnly);
      expect(items, isEmpty);
    });

    test('handles single-line drug with OD and BD notations', () async {
      const rx = '''
1. Paracetamol 650 TDS for 3 days
2. Cetirizine 10mg OD night
''';

      final items = await PrescriptionScanParser.parse(rx);
      expect(items.length, 2);

      final pcm = items[0];
      expect(pcm.amountMorning, 1.0);
      expect(pcm.amountAfternoon, 1.0);
      expect(pcm.amountNight, 1.0);
      expect(pcm.durationDays, 3);

      final cet = items[1];
      expect(cet.amountMorning, 1.0);
    });
  });
}
