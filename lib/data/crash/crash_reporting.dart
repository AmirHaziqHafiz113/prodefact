import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';

/// Wires Flutter framework errors and uncaught async/platform errors to
/// Firebase Crashlytics — called from `main.dart` only after
/// `Firebase.initializeApp` has already succeeded.
///
/// Never sends a test/fake crash on its own; it only forwards *real*
/// errors the app would otherwise have to handle itself. Crash
/// collection is disabled in debug builds (so routine `flutter run`/
/// `flutter test` sessions never appear in a real project's Crashlytics
/// dashboard) and enabled in release builds — see
/// `docs/production_readiness.md` ("Crashlytics setup").
///
/// Any failure while wiring this up is caught and logged — Crashlytics
/// itself must never be a reason the app fails to start.
Future<void> initializeCrashReporting() async {
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };
  } catch (error, stackTrace) {
    AppLogger.error('Could not initialize Crashlytics', error, stackTrace);
  }
}
