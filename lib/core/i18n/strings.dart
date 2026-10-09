import 'package:reindeer/core/i18n/translations_hi.dart';
import 'package:reindeer/core/i18n/translations_mr.dart';

/// Languages the app can show. Everything the person types (names, notes)
/// stays as typed; only the app's own words change.
enum AppLanguage {
  en('en', 'English'),
  hi('hi', 'हिन्दी'),
  mr('mr', 'मराठी');

  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// The language's own name, shown in the picker.
  final String nativeName;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage.en,
  );
}

/// The language currently in use. Set at start-up and by the language picker.
abstract final class I18n {
  static AppLanguage current = AppLanguage.en;
}

/// Translates an English UI string. Unknown text is returned unchanged, so a
/// missing translation shows English rather than nothing.
String tr(String en) => switch (I18n.current) {
  AppLanguage.en => en,
  AppLanguage.hi => hiStrings[en] ?? en,
  AppLanguage.mr => mrStrings[en] ?? en,
};

/// Like [tr] for text with `{name}` placeholders: `trf('Time for {n}', {'n': x})`.
String trf(String en, Map<String, String> args) {
  var s = tr(en);
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

/// Picks the singular or plural English text for [n], then fills `{n}`.
String trn(int n, String one, String other) =>
    trf(n == 1 ? one : other, {'n': '$n'});

/// Runs [build] with the app's words in English. Used for text people send to
/// others (doctor summary, Medical ID) so a sentence is never half translated.
T inEnglish<T>(T Function() build) {
  final saved = I18n.current;
  I18n.current = AppLanguage.en;
  try {
    return build();
  } finally {
    I18n.current = saved;
  }
}
