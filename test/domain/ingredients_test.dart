import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/medicine_database/domain/ingredients.dart';

void main() {
  test('shared ingredients', () {
    expect(sharedIngredients('aceclofenac paracetamol', 'paracetamol'), [
      'paracetamol',
    ]);
    expect(
      sharedIngredients('amoxycillin acid clavulanic', 'acid folic'),
      isEmpty,
    );
    expect(sharedIngredients('pantoprazole', 'metformin'), isEmpty);
  });
}
