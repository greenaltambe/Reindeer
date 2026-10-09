import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/symptoms/domain/symptom_catalog.dart';

void main() {
  test('search by name, prefix and Hindi words', () {
    expect(searchSymptoms('head').first.name, 'Headache');
    expect(searchSymptoms('bukhar').first.name, 'Fever');
    expect(searchSymptoms('ulti').first.name, 'Vomiting');
    expect(searchSymptoms('pet dard').first.name, 'Stomach pain');
    expect(searchSymptoms('khujli').first.name, 'Rash or itching');
  });

  test('empty or unknown search gives nothing', () {
    expect(searchSymptoms(''), isEmpty);
    expect(searchSymptoms('zzzzqq'), isEmpty);
  });

  test('names are unique and common ones exist', () {
    final names = symptomCatalog.map((s) => s.name.toLowerCase()).toList();
    expect(names.toSet().length, names.length);
    expect(symptomCatalog.where((s) => s.common), isNotEmpty);
  });

  test('side effect matching', () {
    expect(listedAsSideEffect('Nausea', 'Vomiting, Nausea, Diarrhea'), isTrue);
    expect(listedAsSideEffect('Loose motions', 'Vomiting, Diarrhea'), isTrue);
    expect(listedAsSideEffect('Dizziness', 'Headache, Drowsiness'), isFalse);
    expect(listedAsSideEffect('Hiccups', 'Hiccups, Nausea'), isTrue);
    expect(listedAsSideEffect('Nausea', ''), isFalse);
  });
}
