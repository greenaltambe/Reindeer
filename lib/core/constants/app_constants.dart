/// Global application-wide constants.
abstract final class AppConstants {
  static const String appName = 'Reindeer';
  static const String appVersion = '1.0.0';

  /// Default network and operation timeouts.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Standard animation durations.
  static const Duration fastAnimation = Duration(milliseconds: 180);
  static const Duration normalAnimation = Duration(milliseconds: 300);
}
