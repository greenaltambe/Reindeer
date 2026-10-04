import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// Theme saved from the last run. Overridden in `main`.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Manages the active [ThemeMode] across the application and remembers it.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref
        .read(settingsRepositoryProvider)
        .set(SettingsRepository.keyTheme, mode.name);
  }

  /// Switches between light and dark.
  void toggleLightDark({required bool currentlyDark}) {
    setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Global provider exposing the user's selected [ThemeMode].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
