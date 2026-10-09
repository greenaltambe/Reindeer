import 'dart:async';
import 'dart:typed_data' show Int32List;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';

const String careChannelId = 'care_alerts';
const String emergencyChannelId = 'care_emergency';

/// Push notifications between patient and caretaker phones.
///
/// When the app is closed Android shows them by itself (on the channels
/// created here); while it is open they are shown through the local
/// notification plugin so they look the same.
abstract final class CareMessaging {
  static bool _started = false;
  static final List<StreamSubscription<Object?>> _subs = [];

  /// Creates the channels. Cheap and offline; called at every start.
  static Future<void> createChannels() async {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        careChannelId,
        'Family alerts',
        description: 'Missed doses and news about people you look after',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        emergencyChannelId,
        'Help alerts',
        description: 'When someone you look after presses Help',
        importance: Importance.max,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  /// Starts listening once this phone has signed in for sharing.
  /// [open] navigates to a route inside the app.
  static Future<void> start(void Function(String route) open) async {
    if (_started || CareBackend.uid == null) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      _subs.add(FirebaseMessaging.onMessage.listen(_showWhileOpen));
      _subs.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m, open)),
      );
      _subs.add(
        messaging.onTokenRefresh.listen(
          (t) => CareBackend.registerDevice(token: t),
        ),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial, open);
      // A family alert shown while the app was open, tapped after it closed.
      final launch = await FlutterLocalNotificationsPlugin()
          .getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload ?? '';
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload.startsWith(routePayloadPrefix)) {
        open(payload.substring(routePayloadPrefix.length));
      }
      await CareBackend.registerDevice();
    } catch (e, s) {
      _started = false;
      AppLogger.error('Could not start family alerts', error: e, stackTrace: s);
    }
  }

  /// Asks Android 13+ for permission to show notifications.
  static Future<bool> requestPermission() async {
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  static void _open(RemoteMessage m, void Function(String route) open) {
    final route = m.data['route'];
    if (route is String && route.startsWith('/')) open(route);
  }

  static Future<void> _showWhileOpen(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    final emergency = n.android?.channelId == emergencyChannelId;
    final route = m.data['route'] as String? ?? '/care';
    await FlutterLocalNotificationsPlugin().show(
      // A band of ids far above dose reminders; the same tag replaces the
      // earlier notification, as it does when Android shows it.
      id:
          0x40000000 +
          ((n.android?.tag ?? m.messageId ?? '${n.title}').hashCode &
              0x0fffffff),
      title: n.title,
      body: n.body,
      payload: '$routePayloadPrefix$route',
      notificationDetails: NotificationDetails(
        android: emergency
            ? AndroidNotificationDetails(
                emergencyChannelId,
                'Help alerts',
                channelDescription: 'When someone you look after presses Help',
                importance: Importance.max,
                priority: Priority.max,
                category: AndroidNotificationCategory.alarm,
                audioAttributesUsage: AudioAttributesUsage.alarm,
                // FLAG_INSISTENT: keeps ringing until it is opened.
                additionalFlags: Int32List.fromList(<int>[4]),
              )
            : const AndroidNotificationDetails(
                careChannelId,
                'Family alerts',
                channelDescription:
                    'Missed doses and news about people you look after',
                importance: Importance.high,
                priority: Priority.high,
              ),
      ),
    );
  }
}
