import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Asserts the architectural rules from the task: "UI/providers should
/// not query Drift directly" (Phase 4) and "Firebase SDK types [must]
/// not leak through domain entities" / "UI should not call Firestore or
/// Firebase Storage directly" (Phase 5).
///
/// Everything outside `lib/data/` must go through `InspectionRepository`
/// / `CloudInspectionRepository` / `AuthService`, never touch Drift or
/// a Firebase package directly. `lib/main.dart` is the one accepted
/// exception: it's the composition root, and its only Firebase-specific
/// line is the single `Firebase.initializeApp(...)` bootstrap call.
void main() {
  test('nothing outside lib/data (and the main.dart bootstrap) imports '
      'Drift or a Firebase SDK package directly', () async {
    final libDir = Directory('lib');
    final offenders = <String>[];

    const disallowedImports = [
      'package:drift/drift.dart',
      'package:drift/native.dart',
      "'database.dart'",
      '"database.dart"',
      'package:firebase_core/firebase_core.dart',
      'package:firebase_auth/firebase_auth.dart',
      'package:cloud_firestore/cloud_firestore.dart',
      'package:firebase_storage/firebase_storage.dart',
    ];

    const exemptPaths = {'main.dart', 'firebase_options.dart'};

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: 'lib');
      // The data layer itself is allowed to depend on Drift/Firebase
      // directly — that's the whole point of the boundary.
      if (p.split(relativePath).first == 'data') {
        continue;
      }
      if (exemptPaths.contains(relativePath)) {
        continue;
      }

      final contents = await entity.readAsString();
      final hasDisallowedImport = disallowedImports.any(contents.contains);
      if (hasDisallowedImport) {
        offenders.add(relativePath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files depend on Drift or a Firebase SDK package '
          'directly instead of going through the repository/service '
          'abstractions: $offenders',
    );
  });
}
