import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/allergy/domain/allergy.dart';

void main() {
  test('penicillin group catches amoxycillin', () {
    final m = findAllergyMatches(
      allergies: ['Penicillins'],
      ingredientKey: 'acid amoxycillin clavulanic',
    );
    expect(m.map((e) => e.ingredient), ['amoxycillin']);
  });

  test('typed alias maps to the group', () {
    final m = findAllergyMatches(
      allergies: ['penicillin'],
      ingredientKey: 'amoxycillin',
    );
    expect(m, isNotEmpty);
    expect(groupFor('Sulfa'), isNotNull);
  });

  test('cephalosporins and quinolones by name pattern', () {
    expect(
      findAllergyMatches(
        allergies: ['Cephalosporins'],
        ingredientKey: 'cefixime',
      ),
      isNotEmpty,
    );
    expect(
      findAllergyMatches(
        allergies: ['Quinolone antibiotics'],
        ingredientKey: 'ofloxacin ornidazole',
      ).map((e) => e.ingredient),
      ['ofloxacin'],
    );
  });

  test('nsaid group does not catch paracetamol or solifenacin', () {
    expect(
      findAllergyMatches(
        allergies: ['Aspirin and painkillers (NSAIDs)'],
        ingredientKey: 'paracetamol solifenacin',
      ),
      isEmpty,
    );
    expect(
      findAllergyMatches(
        allergies: ['Aspirin and painkillers (NSAIDs)'],
        ingredientKey: 'aceclofenac paracetamol',
      ).map((e) => e.ingredient),
      ['aceclofenac'],
    );
  });

  test('custom allergy matches an ingredient or the typed name', () {
    expect(
      findAllergyMatches(
        allergies: ['pantoprazole'],
        ingredientKey: 'pantoprazole domperidone',
      ),
      isNotEmpty,
    );
    expect(
      findAllergyMatches(
        allergies: ['pantoprazole'],
        text: 'Pantoprazole 40 mg',
      ),
      isNotEmpty,
    );
    expect(
      findAllergyMatches(
        allergies: ['pantoprazole'],
        ingredientKey: 'metformin',
      ),
      isEmpty,
    );
  });

  test('sulfa group ignores sulphate salts but catches real sulfa drugs', () {
    expect(
      findAllergyMatches(
        allergies: ['Sulfa drugs'],
        ingredientKey: 'ferrous sulphate salbutamol sulfate',
      ),
      isEmpty,
    );
    expect(
      findAllergyMatches(
        allergies: ['Sulfa drugs'],
        ingredientKey: 'sulfamethoxazole trimethoprim',
      ),
      isNotEmpty,
    );
  });

  test('brand names typed by hand are caught through aliases', () {
    expect(
      findAllergyMatches(allergies: ['Penicillins'], text: 'Augmentin 625'),
      isNotEmpty,
    );
    expect(
      findAllergyMatches(allergies: ['Paracetamol'], text: 'Dolo 650'),
      isNotEmpty,
    );
  });

  test('empty inputs are safe', () {
    expect(findAllergyMatches(allergies: const []), isEmpty);
    expect(findAllergyMatches(allergies: ['  ']), isEmpty);
  });
}
