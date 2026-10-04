import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_constants.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/router/app_router.dart';
import 'package:reindeer/core/theme/app_theme.dart';
import 'package:reindeer/core/theme/theme_provider.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _onNotificationAction() => ref.read(dataVersionProvider.notifier).bump();

  @override
  void dispose() {
    notificationActionTick.removeListener(_onNotificationAction);
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
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
