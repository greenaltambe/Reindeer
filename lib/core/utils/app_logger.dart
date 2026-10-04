import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight structured logger for application diagnostics.
abstract final class AppLogger {
  static void info(String message, {String tag = 'Reindeer'}) {
    if (kDebugMode) {
      developer.log(message, name: '$tag.INFO');
    }
  }

  static void warning(String message, {String tag = 'Reindeer'}) {
    if (kDebugMode) {
      developer.log(message, name: '$tag.WARN');
    }
  }

  static void error(
    String message, {
    String tag = 'Reindeer',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      developer.log(
        message,
        name: '$tag.ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
