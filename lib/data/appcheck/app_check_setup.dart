import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';

/// Activates Firebase App Check — called from `main.dart` only after
/// `Firebase.initializeApp` has already succeeded.
///
/// Uses the **debug provider** in debug builds, which needs no real
/// credentials: it generates a random per-install debug token (printed
/// to the console) that a developer registers in the Firebase console
/// to allow that specific install through App Check while iterating.
/// Release builds use the platform's real attestation
/// (Play Integrity on Android, App Attest on iOS) — see
/// `docs/production_readiness.md` ("App Check setup") for the exact
/// manual console steps this still requires; nothing here fabricates a
/// credential, and nothing here is required for the app to run — a
/// failure here is caught and logged, never fatal to startup.
Future<void> initializeAppCheck() async {
  try {
    // The replacement parameters (`providerAndroid`/`providerApple`)
    // take a different provider type in the currently-pinned
    // `firebase_app_check` version; these are still the functioning,
    // documented way to select providers on that version.
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  } catch (error, stackTrace) {
    AppLogger.error('Could not initialize App Check', error, stackTrace);
  }
}
