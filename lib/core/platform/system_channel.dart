import 'package:flutter/services.dart';

/// Small bridge to Android features Flutter does not expose: sharing text,
/// the battery-optimisation setting and the app's system settings page.
///
/// Every call is safe: if the platform side is missing it returns null/false.
abstract final class SystemChannel {
  static const MethodChannel _channel = MethodChannel('reindeer/system');

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the system share sheet (WhatsApp, messages, email, ...).
  static Future<bool> shareText(String text, {String title = 'Share'}) async =>
      (await _call<bool>('shareText', {'text': text, 'title': title})) ?? false;

  /// Opens the phone dialer with [number] filled in (the person presses call).
  static Future<bool> dial(String number) async =>
      (await _call<bool>('dial', {'number': number})) ?? false;

  /// Opens the messages app with [text] ready to send to [number].
  static Future<bool> sms(String number, String text) async =>
      (await _call<bool>('sms', {'number': number, 'text': text})) ?? false;

  /// Whether Android lets Reindeer run without battery restrictions.
  /// Null when it cannot be read.
  static Future<bool?> isIgnoringBatteryOptimizations() =>
      _call<bool>('isIgnoringBatteryOptimizations');

  static Future<bool> requestIgnoreBatteryOptimizations() async =>
      (await _call<bool>('requestIgnoreBatteryOptimizations')) ?? false;

  static Future<bool> openAppSettings() async =>
      (await _call<bool>('openAppSettings')) ?? false;

  /// Sends the text shown on the home-screen widget and refreshes it.
  static Future<bool> updateWidget(String text) async =>
      (await _call<bool>('updateWidget', {'text': text})) ?? false;

  /// Opens the system "save as" screen and writes [text] to the chosen file.
  /// Returns false when cancelled or on failure.
  static Future<bool> saveTextFile(String name, String text) async =>
      (await _call<bool>('saveTextFile', {'name': name, 'text': text})) ??
      false;

  /// Opens the system file picker and returns the file's text, or null when
  /// cancelled or unreadable.
  static Future<String?> pickTextFile() => _call<String>('pickTextFile');

  /// Dose keys ticked off on the home-screen widget since the app last looked.
  /// Reading them clears the list.
  static Future<List<String>> takeWidgetActions() async {
    final raw = await _call<String>('takeWidgetActions');
    if (raw == null || raw.isEmpty) return const [];
    return raw.split('\n').where((k) => k.isNotEmpty).toList();
  }
}
