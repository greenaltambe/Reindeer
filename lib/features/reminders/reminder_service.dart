import 'dart:typed_data' show Int32List;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const String _channelId = 'dose_reminders';
const String _alarmChannelId = 'dose_alarms';

/// Settings key: loud, repeating reminders.
const String keyPersistentAlarm = 'persistent_alarm';
const String _fallbackZone = 'Asia/Kolkata';
const int _horizonDays = 7;
const Duration snoozeDuration = Duration(minutes: 10);

const String _actionTaken = 'taken';
const String _actionSkip = 'skip';
const String _actionSnooze = 'snooze';

/// What the phone currently allows; shown in Settings.
class ReminderHealth {
  const ReminderHealth({
    required this.notificationsEnabled,
    required this.exactAlarms,
    this.batteryUnrestricted,
  });

  final bool notificationsEnabled;

  /// Whether Android lets the app run without battery restrictions. Null when
  /// it could not be read. Not part of [allGood]: reminders usually work
  /// without it, but some phones need it.
  final bool? batteryUnrestricted;

  /// Whether reminders can fire at the exact minute.
  final bool exactAlarms;

  bool get allGood => notificationsEnabled && exactAlarms;
}

/// What the last "schedule everything" run did, shown in Settings so a problem
/// is visible instead of silent.
class ScheduleReport {
  const ScheduleReport({
    this.scheduled = 0,
    this.failed = 0,
    this.lastError,
    this.at,
  });

  final int scheduled;
  final int failed;
  final String? lastError;
  final DateTime? at;
}

List<AndroidNotificationAction> _doseActions() => [
  AndroidNotificationAction(_actionTaken, tr('Taken')),
  AndroidNotificationAction(_actionSkip, tr('Skip')),
  AndroidNotificationAction(_actionSnooze, tr('Snooze 10 min')),
];

/// Notification style. With [alarm] the reminder uses the alarm volume and
/// keeps ringing until the person responds.
NotificationDetails _details({bool alarm = false}) => NotificationDetails(
  android: alarm
      ? AndroidNotificationDetails(
          _alarmChannelId,
          'Loud dose reminders',
          channelDescription: 'Repeating reminders that ring until you respond',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          // FLAG_INSISTENT: repeat the sound until the notification is handled.
          additionalFlags: Int32List.fromList(<int>[4]),
          autoCancel: false,
          actions: _doseActions(),
        )
      : AndroidNotificationDetails(
          _channelId,
          'Dose reminders',
          channelDescription: 'Reminders to take your medicines',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: _doseActions(),
        ),
);

const InitializationSettings _initSettings = InitializationSettings(
  android: AndroidInitializationSettings('@drawable/ic_notification'),
);

/// Notification id for a dose: unique per plan, day and slot.
int notificationIdFor(PlannedDose dose) {
  final days = dateOnly(dose.at).difference(DateTime(2020)).inDays;
  return dose.planId * 10000 + (days % 1000) * 10 + dose.slot.index;
}

/// Id of the snoozed copy of notification [id] (stays within the same band).
int _snoozeIdFor(int id) {
  final base = id - id % 10;
  return base + (id % 10) % 5 + 5;
}

String _payloadFor(PlannedDose dose) => dose.key;

/// Sets the local time zone and returns its id.
Future<String> initTimezone({String? stored}) async {
  tzdata.initializeTimeZones();
  var id = stored;
  if (id == null || id.isEmpty) {
    try {
      id = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      id = _fallbackZone;
    }
  }
  try {
    tz.setLocalLocation(tz.getLocation(id));
  } catch (_) {
    id = _fallbackZone;
    tz.setLocalLocation(tz.getLocation(id));
  }
  return id;
}

/// Schedules and manages dose reminders.
class ReminderService {
  ReminderService(this._plans, this._logs, this._settings);

  final PlanRepository _plans;
  final DoseLogRepository _logs;
  final SettingsRepository _settings;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _queue = Future<void>.value();

  /// What the most recent [rescheduleAll] did.
  ScheduleReport lastReport = const ScheduleReport();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Call once at start-up, after [initTimezone].
  Future<void> init() async {
    await _plugin.initialize(
      settings: _initSettings,
      onDidReceiveNotificationResponse: (response) async {
        // The app is open: handle the button here (the database is shared).
        await _handleResponse(response, closeDb: false);
        notificationActionTick.value++;
      },
      onDidReceiveBackgroundNotificationResponse:
          reindeerNotificationBackground,
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Dose reminders',
        description: 'Reminders to take your medicines',
        importance: Importance.high,
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        'Loud dose reminders',
        description: 'Repeating reminders that ring until you respond',
        importance: Importance.max,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  /// Asks for the notification permission (Android 13+) and exact alarms.
  Future<ReminderHealth> requestPermissions() async {
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
    return health();
  }

  Future<ReminderHealth> health() async {
    final android = _android;
    if (android == null) {
      return const ReminderHealth(
        notificationsEnabled: true,
        exactAlarms: true,
      );
    }
    return ReminderHealth(
      notificationsEnabled: await android.areNotificationsEnabled() ?? false,
      exactAlarms: await android.canScheduleExactNotifications() ?? false,
      batteryUnrestricted: await SystemChannel.isIgnoringBatteryOptimizations(),
    );
  }

  /// How many reminders Android is currently holding for the app.
  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  /// Schedules a reminder [after] from now through the same path real doses use,
  /// so the person can leave the app and check it still rings. Returns a short
  /// description of how it was scheduled.
  Future<String> scheduleTest(Duration after) async {
    final exact = await health().then((h) => h.exactAlarms);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      // Id ending in 5 survives "cancel dose reminders" (see rescheduleAll).
      id: 5,
      scheduledDate: tz.TZDateTime.now(tz.local).add(after),
      notificationDetails: _details(),
      androidScheduleMode: mode,
      title: 'Test reminder from Reindeer',
      body: 'If you can read this, scheduled reminders work on this phone.',
    );
    try {
      await go(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return exact ? 'exact' : 'approximate';
    } on PlatformException {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
      return 'approximate';
    }
  }

  /// Shows a notification right now so the person can check it works.
  Future<void> showTest() => _plugin.show(
    id: 1,
    title: 'Reindeer reminders are working',
    body: 'This is how a dose reminder will look.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Dose reminders',
        channelDescription: 'Reminders to take your medicines',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  /// Rebuilds all pending reminders for the next [_horizonDays] days.
  ///
  /// Safe to call often: on start-up, on resume, and after any plan change.
  Future<void> rescheduleAll() {
    // One run at a time: overlapping runs could cancel each other's work.
    final next = _queue.then((_) => _rescheduleAllNow()).catchError((
      Object e,
      StackTrace st,
    ) {
      AppLogger.error('Rescheduling failed', error: e, stackTrace: st);
      lastReport = ScheduleReport(
        failed: 1,
        lastError: '$e',
        at: DateTime.now(),
      );
    });
    _queue = next;
    return next;
  }

  Future<void> _rescheduleAllNow() async {
    var scheduled = 0;
    var failed = 0;
    String? lastError;
    // Cancel dose reminders but keep pending snoozes (ids ending in 5-7).
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id % 10 < 5) await _plugin.cancel(id: p.id);
    }
    try {
      await _scheduleMeasureReminders();
    } catch (e, st) {
      // Health reminders must never block dose reminders.
      AppLogger.error(
        'Could not schedule health reminders',
        error: e,
        stackTrace: st,
      );
    }
    final now = DateTime.now();
    final today = dateOnly(now);
    final last = DateTime(
      today.year,
      today.month,
      today.day + _horizonDays - 1,
    );
    final plans = (await _plans.all()).where((p) => p.isActive).toList();
    if (plans.isEmpty) {
      lastReport = ScheduleReport(at: DateTime.now());
      return;
    }
    final anchors = await _settings.loadMealAnchors();
    final logs = await _logs.between(today, last);
    final canExact = await health().then((h) => h.exactAlarms);
    final alarm = (await _settings.get(keyPersistentAlarm)) == '1';

    for (final plan in plans) {
      for (var d = today; !d.isAfter(last); d = nextDay(d)) {
        for (final dose in plan.dosesOn(d, anchors)) {
          if (!dose.at.isAfter(now)) continue;
          if (logs.containsKey(dose.key)) continue;
          try {
            await _schedule(plan, dose, canExact, alarm);
            scheduled++;
          } catch (e, st) {
            // One bad reminder must not stop the rest from being scheduled.
            failed++;
            lastError = '$e';
            AppLogger.error(
              'Could not schedule a reminder',
              error: e,
              stackTrace: st,
            );
          }
        }
      }
    }
    lastReport = ScheduleReport(
      scheduled: scheduled,
      failed: failed,
      lastError: lastError,
      at: DateTime.now(),
    );
  }

  /// Repeating "take a reading" reminders. Ids end in 0 so the dose cleanup
  /// above clears them first and they are rebuilt here.
  Future<void> _scheduleMeasureReminders() async {
    final canExact = await health().then((h) => h.exactAlarms);
    for (final type in MeasureType.values) {
      final r = MeasureReminder.decode(
        await _settings.get(MeasureReminder.settingsKey(type)),
      );
      if (r == null) continue;
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        r.minutes ~/ 60,
        r.minutes % 60,
      );
      if (r.weekday != null) {
        while (when.weekday != r.weekday || !when.isAfter(now)) {
          when = when.add(const Duration(days: 1));
        }
      } else if (!when.isAfter(now)) {
        when = when.add(const Duration(days: 1));
      }
      Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
        id: 9000000 + type.index * 10,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Dose reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: mode,
        title: 'Time to check your ${type.label.toLowerCase()}',
        body: type.hint,
        matchDateTimeComponents: r.weekday == null
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
      );
      try {
        await go(
          canExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on PlatformException {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    }
  }

  Future<void> _schedule(
    MedicationPlan plan,
    PlannedDose dose,
    bool exact,
    bool alarm,
  ) async {
    final when = tz.TZDateTime.from(dose.at, tz.local);
    final timing = plan.mealTiming == MealTiming.anytime
        ? ''
        : ' · ${plan.mealTiming.label.toLowerCase()}';
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: notificationIdFor(dose),
      scheduledDate: when,
      notificationDetails: _details(alarm: alarm),
      androidScheduleMode: mode,
      title: trf('Time for {n}', {'n': plan.name}),
      body: '${plan.doseUnit.describe(dose.amount)}$timing',
      payload: _payloadFor(dose),
    );
    try {
      await go(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException {
      // Exact alarms were refused; an approximate reminder beats none.
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    ref.watch(planRepositoryProvider),
    ref.watch(doseLogRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

/// Handles Taken / Skip / Snooze taps while the app is not running.
///
/// Runs in a background isolate, so it opens the database itself.
@pragma('vm:entry-point')
Future<void> reindeerNotificationBackground(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  await _handleResponse(response, closeDb: true);
}

/// Bumped when a notification button was handled while the app is open, so the
/// UI can refresh.
final ValueNotifier<int> notificationActionTick = ValueNotifier<int>(0);

Future<void> _handleResponse(
  NotificationResponse response, {
  required bool closeDb,
}) async {
  final action = response.actionId;
  final payload = response.payload;
  final notificationId = response.id;
  if (action == null || payload == null || notificationId == null) return;

  final parsed = PlannedDose.parseKey(payload);
  if (parsed == null) return;
  final planId = parsed.planId;
  final scheduledDate = parseIso(parsed.date);

  final db = await AppDatabase.open();
  try {
    final settings = SettingsRepository(db);
    final plans = PlanRepository(db);
    final plan = await plans.byId(planId);
    if (plan == null) return;

    final anchors = await settings.loadMealAnchors();
    PlannedDose? dose;
    for (final d in plan.dosesOn(scheduledDate, anchors)) {
      if (d.key == payload ||
          d.legacyKey == payload ||
          (d.doseDate == parsed.date && d.slot.name == parsed.slot)) {
        dose = d;
        break;
      }
    }
    if (dose == null) return;

    final now = DateTime.now();
    if (action == _actionTaken || action == _actionSkip) {
      await DoseLogRepository(db).record(
        dose: dose,
        status: action == _actionTaken ? DoseStatus.taken : DoseStatus.skipped,
        now: now,
      );
      if (action == _actionSkip) {
        await MissReasonRepository(db).recordForDose(
          dose: dose,
          reason: MissReasonType.unknown,
          note: 'Skipped from notification',
          at: now,
        );
      }
    } else if (action == _actionSnooze) {
      await initTimezone(
        stored: await settings.get(SettingsRepository.keyTimezone),
      );
      final plugin = FlutterLocalNotificationsPlugin();
      // Only the background isolate needs its own initialisation; doing it in the
      // app would replace the callbacks registered at start-up.
      if (closeDb) await plugin.initialize(settings: _initSettings);
      await plugin.zonedSchedule(
        id: _snoozeIdFor(notificationId),
        scheduledDate: tz.TZDateTime.now(tz.local).add(snoozeDuration),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: trf('Time for {n}', {'n': plan.name}),
        body: '${plan.doseUnit.describe(dose.amount)} · snoozed',
        payload: payload,
      );
    }
  } finally {
    if (closeDb) await db.close();
  }
}

/// Current notification / exact-alarm permission state; refreshed when the
/// app returns to the foreground (for example from the system settings).
final reminderHealthProvider = FutureProvider<ReminderHealth>(
  (ref) => ref.watch(reminderServiceProvider).health(),
);

/// How many reminders Android holds and what the last scheduling run did.
final reminderStatusProvider =
    FutureProvider<({int pending, ScheduleReport report})>((ref) async {
      ref.watch(dataVersionProvider);
      final service = ref.watch(reminderServiceProvider);
      return (
        pending: await service.pendingCount(),
        report: service.lastReport,
      );
    });
