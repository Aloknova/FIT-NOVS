import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(
    String message, {
    String scope = 'app',
    Map<String, Object?> details = const {},
  }) {
    _log(
      level: 800,
      message: message,
      scope: scope,
      details: details,
    );
  }

  static void warning(
    String message, {
    String scope = 'app',
    Map<String, Object?> details = const {},
  }) {
    _log(
      level: 900,
      message: message,
      scope: scope,
      details: details,
    );
  }

  static void error(
    String message, {
    String scope = 'app',
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> details = const {},
  }) {
    _log(
      level: 1000,
      message: message,
      scope: scope,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
  }

  static void action(
    String action, {
    Map<String, Object?> details = const {},
  }) {
    info(
      'User action: $action',
      scope: 'action',
      details: details,
    );
  }

  static void _log({
    required int level,
    required String message,
    required String scope,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> details = const {},
  }) {
    developer.log(
      message,
      name: 'fitnova.$scope',
      level: level,
      error: error,
      stackTrace: stackTrace,
    );

    if (!kDebugMode) {
      return;
    }

    final buffer = StringBuffer('[fitnova.$scope] $message');
    if (details.isNotEmpty) {
      buffer.write(' ${jsonEncode(details)}');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    debugPrint(buffer.toString());
  }
}
