import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';

void main() {
  testWidgets('ChoiceTile shows its label and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChoiceTile(
            label: MealTiming.afterFood.label,
            caption: '30 min after the meal',
            selected: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('After food'), findsOneWidget);
    await tester.tap(find.byType(ChoiceTile));
    expect(taps, 1);
  });
}
