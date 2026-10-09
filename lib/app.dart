import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_constants.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/i18n/language_provider.dart';
import 'package:reindeer/core/router/app_router.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/features/care/application/care_messaging.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/core/theme/app_theme.dart';
import 'package:reindeer/core/theme/theme_provider.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/widget/application/widget_sync.dart';

/// Root application widget configuring routing and theming.
///
/// Also refreshes data and reminders whenever the app comes to the foreground,
/// so doses handled from a notification show up straight away.
class ReindeerApp extends ConsumerStatefulWidget {
  const ReindeerApp({super.key});

  @override
  ConsumerState<ReindeerApp> createState() => _ReindeerAppState();
}

class _ReindeerAppState extends ConsumerState<ReindeerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notificationActionTick.addListener(_onNotificationAction);
    notificationRouteRequest.addListener(_onRouteRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _startFamilyAlerts();
    });
  }

  void _onNotificationAction() => ref.read(dataVersionProvider.notifier).bump();

  void _onRouteRequest() {
    final route = notificationRouteRequest.value;
    if (route == null) return;
    notificationRouteRequest.value = null;
    _open(route);
  }

  void _open(String route) {
    final router = ref.read(appRouterProvider);
    // Already there (for example a caretaker-only phone opening on Family).
    if (router.routerDelegate.currentConfiguration.uri.path == route) return;
    if (route == AppRoutes.today) {
      router.go(route);
    } else {
      router.push(route);
    }
  }

  /// Listens for family alerts once this phone takes part in sharing.
  void _startFamilyAlerts() {
    if (ref.read(careUidProvider) == null) return;
    CareMessaging.start(_open);
  }

  @override
  void dispose() {
    notificationActionTick.removeListener(_onNotificationAction);
    notificationRouteRequest.removeListener(_onRouteRequest);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    ref.read(dataVersionProvider.notifier).bump();
    ref.invalidate(reminderHealthProvider);
    try {
      await ref.read(reminderServiceProvider).rescheduleAll();
    } catch (_) {
      // Reminders are best-effort here; Settings shows their health.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(widgetSyncProvider);
    ref.watch(careWatcherProvider);
    ref.listen<String?>(careUidProvider, (_, uid) {
      if (uid != null) _startFamilyAlerts();
    });
    ref.listen(languageProvider, (_, _) => CareBackend.registerDevice());
    final language = ref.watch(languageProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: Locale(language.code),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // A new key rebuilds every screen, so words already on screen change.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(language),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
