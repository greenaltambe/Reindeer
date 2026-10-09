/// Ingredient helpers. Pure functions so they can be tested.
library;

/// Words that appear in many ingredient names and say nothing on their own.
const weakIngredientWords = {
  'acid',
  'sodium',
  'potassium',
  'calcium',
  'magnesium',
  'hydrochloride',
  'sulphate',
  'sulfate',
  'phosphate',
  'vitamin',
  'oral',
  'zinc',
  'iron',
  'ferrous',
  'citrate',
  'chloride',
  'bromide',
  'maleate',
  'tartrate',
};

/// Ingredient words that two ingredient keys (space separated, as stored in
/// the medicine database) have in common.
List<String> sharedIngredients(String a, String b) {
  Set<String> words(String s) => {
    for (final w in s.split(' '))
      if (w.length >= 4 && !weakIngredientWords.contains(w)) w,
  };
  final wb = words(b);
  return [
    for (final w in words(a))
      if (wb.contains(w)) w,
  ]..sort();
}
