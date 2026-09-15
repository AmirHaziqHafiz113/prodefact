// PLACEHOLDER — this file has NOT been configured with a real Firebase
// project. It contains no real credentials.
//
// To connect this app to a real Firebase project:
//   1. npm install -g firebase-tools   (or: dart pub global activate flutterfire_cli)
//   2. firebase login
//   3. flutterfire configure
//
// Step 3 will overwrite this exact file with real, generated values for
// whichever Firebase project you select — no other code changes are
// needed; every provider in `lib/data/remote/` reads
// `DefaultFirebaseOptions.currentPlatform` exactly as it does today.
//
// Until that's done, `main.dart` catches the failure this placeholder
// causes and the app runs in local-only mode (see docs/firebase.md).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      _ => throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      ),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
  );

  static const android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
  );

  static const ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    iosBundleId: 'com.example.prodefact',
  );

  static const macos = ios;
}
