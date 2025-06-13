import 'package:flutter/foundation.dart';

/// Debug utility for conditional logging
class DebugLogger {
  static const String _prefix = '[DEBUG]';

  /// Log a message only in debug mode
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      print('$_prefix $tagPrefix$message');
    }
  }

  /// Log an error only in debug mode
  static void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      print('$_prefix ${tagPrefix}ERROR: $message');
      if (error != null) {
        print('$_prefix ${tagPrefix}Error details: $error');
      }
      if (stackTrace != null) {
        print('$_prefix ${tagPrefix}Stack trace: $stackTrace');
      }
    }
  }

  /// Log a warning only in debug mode
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      print('$_prefix ${tagPrefix}WARNING: $message');
    }
  }

  /// Log info only in debug mode
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      print('$_prefix ${tagPrefix}INFO: $message');
    }
  }
}
