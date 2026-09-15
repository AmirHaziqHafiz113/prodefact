import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Asserts the architectural rule from the task: "UI/providers should
/// not query Drift directly" — everything outside `lib/data/` must go
/// through `InspectionRepository`, never touch `package:drift` or the
/// generated `AppDatabase` itself.
void main() {
  test(
    'nothing outside lib/data imports Drift or the generated database',
    () async {
      final libDir = Directory('lib');
      final offenders = <String>[];

      await for (final entity in libDir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final relativePath = p.relative(entity.path, from: 'lib');
        // The data layer itself is allowed to depend on Drift directly.
        if (p.split(relativePath).first == 'data') {
          continue;
        }

        final contents = await entity.readAsString();
        final importsDrift =
            contents.contains("package:drift/drift.dart") ||
            contents.contains("package:drift/native.dart") ||
            contents.contains("'database.dart'") ||
            contents.contains('"database.dart"');
        if (importsDrift) {
          offenders.add(relativePath);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files depend on Drift directly instead of going '
            'through InspectionRepository: $offenders',
      );
    },
  );

  test(
    'the app depends on no network/Firebase package (local-only for now)',
    () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      const disallowed = [
        'firebase_core',
        'firebase_auth',
        'cloud_firestore',
        'firebase_storage',
        'dio',
      ];
      for (final package in disallowed) {
        expect(
          pubspec.contains('$package:'),
          isFalse,
          reason: 'Phase 4 is local-only; found a dependency on $package',
        );
      }
    },
  );
}
