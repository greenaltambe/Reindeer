import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// Settings key holding the chosen language code.
const keyLanguage = 'language';

/// The app language. Changing it saves the choice, redraws the app and
/// rebuilds reminders so their text matches.
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => I18n.current;

  Future<void> set(AppLanguage language) async {
    if (language == state) return;
    I18n.current = language;
    state = language;
    await ref.read(settingsRepositoryProvider).set(keyLanguage, language.code);
    ref.read(dataVersionProvider.notifier).bump();
    try {
      await ref.read(reminderServiceProvider).rescheduleAll();
    } catch (_) {
      // Reminder text updates the next time reminders are rebuilt.
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);
