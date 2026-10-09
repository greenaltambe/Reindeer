import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:reindeer/app.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/database/medicine_database.dart';
import 'package:reindeer/core/i18n/language_provider.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_router.dart';
import 'package:reindeer/core/theme/app_theme.dart';
import 'package:reindeer/core/theme/theme_provider.dart';
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/care/application/care_messaging.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/application/care_sync.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('Uncaught platform error', error: error, stackTrace: stack);
    return true;
  };

  runApp(const BootApp());
}

/// Opens the databases and the reminder system, then shows the real app.
///
/// The first launch unpacks the bundled medicine database, which takes a few
/// seconds, so a splash is shown meanwhile.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  List<Override>? _overrides;
  Object? _error;
  String _message = 'Starting...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final medicineDb = await MedicineDatabase.open(
        onInstalling: () {
          if (mounted) {
            setState(
              () => _message =
                  'Setting up the medicine list (first time only)...',
            );
          }
        },
      );
      final appDb = await AppDatabase.open();
      final settings = SettingsRepository(appDb);
      I18n.current = AppLanguage.fromCode(await settings.get(keyLanguage));

      final tzId = await initTimezone(
        stored: await settings.get(SettingsRepository.keyTimezone),
      );
      // Remembered so notification buttons can use it when the app is closed.
      await settings.set(SettingsRepository.keyTimezone, tzId);

      try {
        await ReminderService(
          PlanRepository(appDb),
          DoseLogRepository(appDb),
          settings,
        ).init();
      } catch (e, s) {
        // The app is still useful without reminders; Settings shows their health.
        AppLogger.error('Reminder set-up failed', error: e, stackTrace: s);
      }
      // Local only: nothing is sent until the person sets up family sharing.
      await CareBackend.init();
      try {
        await CareMessaging.createChannels();
      } catch (_) {
        // Family alerts fall back to Android's default channel.
      }
      final careMode = CareMode.fromName(await settings.get(keyCareMode));
      final onboarded = await settings.isOnboarded();
      final savedTheme = await settings.get(SettingsRepository.keyTheme);
      final themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == savedTheme,
        orElse: () => ThemeMode.system,
      );

      if (!mounted) return;
      setState(() {
        _overrides = [
          medicineDatabaseProvider.overrideWithValue(medicineDb),
          appDatabaseProvider.overrideWithValue(appDb),
          initialOnboardedProvider.overrideWithValue(onboarded),
          initialCareModeProvider.overrideWithValue(careMode),
          initialThemeModeProvider.overrideWithValue(themeMode),
        ];
      });
    } catch (e, s) {
      AppLogger.error('Start-up failed', error: e, stackTrace: s);
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrides = _overrides;
    if (overrides != null) {
      return ProviderScope(overrides: overrides, child: const ReindeerApp());
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _error != null
                ? Text(
                    'Reindeer could not start.\n\n$_error',
                    textAlign: TextAlign.center,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ReindeerMark(size: 80),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(_message, textAlign: TextAlign.center),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
