import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// ProDefact's local database.
///
/// Schema history:
/// - v1: baseline (Phase 4) — sessions, sections, findings, evidence.
/// - v2: (Phase 5) added `ownerUid` to sessions (Firebase-user
///   ownership — see `docs/firebase.md`) and `storagePath` to evidence
///   (cloud Storage location once uploaded). Both are nullable, added
///   in place rather than dropping/recreating the database.
@DriftDatabase(
  tables: [InspectionSessionRows, SectionRows, FindingRows, EvidenceRows],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (creating if necessary) the on-device database file under
  /// the app's documents directory.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.ownerUid,
        );
        await migrator.addColumn(evidenceRows, evidenceRows.storagePath);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'prodefact.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
