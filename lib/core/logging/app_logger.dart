import 'package:flutter/foundation.dart';

/// A modest structured logging seam so development diagnostics
/// (`AppLogger.debug`/`.info`) are clearly distinguishable from
/// warnings/errors worth noticing, without pulling in a logging
/// package or spamming the console.
///
/// Deliberately never logs secrets, tokens, or full evidence file
/// paths — callers should pass a short, generic description (e.g. "a
/// finding's photo") rather than interpolating [Evidence.filePath] or
/// any auth token into a message. See `docs/production_readiness.md`.
abstract final class AppLogger {
  static void debug(String message) => _log('DEBUG', message);

  static void info(String message) => _log('INFO', message);

  static void warning(String message, [Object? error]) =>
      _log('WARN', message, error);

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, error);
    if (stackTrace != null && !kReleaseMode) {
      debugPrint(stackTrace.toString());
    }
  }

  static void _log(String level, String message, [Object? error]) {
    final suffix = error == null ? '' : ' — ${error.runtimeType}';
    debugPrint('[ProDefact][$level] $message$suffix');
  }
}
