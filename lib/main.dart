import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/remote/remote_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional at startup: a missing/placeholder project
  // configuration (see lib/firebase_options.dart) must never prevent the
  // app from launching in local-only mode. Every provider that depends
  // on Firebase falls back to a safe stub when firebaseReadyProvider is
  // false — see docs/firebase.md.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    debugPrint(
      'Firebase did not initialize ($error) — continuing in local-only '
      'mode. Run `flutterfire configure` to enable cloud sync.',
    );
  }

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const ProDefactApp(),
    ),
  );
}
