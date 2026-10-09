import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/i18n/translations_hi.dart';
import 'package:reindeer/core/i18n/translations_mr.dart';

Set<String> _placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  tearDown(() => I18n.current = AppLanguage.en);

  test('Hindi and Marathi cover the same text', () {
    expect(hiStrings.keys.toSet(), mrStrings.keys.toSet());
  });

  test('translations keep their {placeholders}', () {
    for (final e in hiStrings.entries) {
      expect(
        _placeholders(e.value),
        _placeholders(e.key),
        reason: 'hi: ${e.key}',
      );
    }
    for (final e in mrStrings.entries) {
      expect(
        _placeholders(e.value),
        _placeholders(e.key),
        reason: 'mr: ${e.key}',
      );
    }
  });

  test('no translation is empty', () {
    expect(hiStrings.values.every((v) => v.trim().isNotEmpty), isTrue);
    expect(mrStrings.values.every((v) => v.trim().isNotEmpty), isTrue);
  });

  test('tr switches language and falls back to English', () {
    expect(tr('Today'), 'Today');
    I18n.current = AppLanguage.hi;
    expect(tr('Medicines'), 'दवाइयां');
    expect(tr('Some text nobody translated'), 'Some text nobody translated');
    I18n.current = AppLanguage.mr;
    expect(tr('Medicines'), 'औषधे');
  });

  test('trf and trn fill placeholders', () {
    I18n.current = AppLanguage.hi;
    expect(trf('Time for {n}', {'n': 'Dolo'}), 'Dolo का समय');
    expect(
      trn(1, '{n} day left in course', '{n} days left in course'),
      'कोर्स में 1 दिन बचा',
    );
    I18n.current = AppLanguage.en;
    expect(trn(3, '{n} day', '{n} days'), '3 days');
  });

  test('language codes round trip', () {
    expect(AppLanguage.fromCode('mr'), AppLanguage.mr);
    expect(AppLanguage.fromCode(null), AppLanguage.en);
    expect(AppLanguage.fromCode('xx'), AppLanguage.en);
  });
}
