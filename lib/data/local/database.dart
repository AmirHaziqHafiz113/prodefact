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
/// - v3: (Phase 6) added `aiReviewState` to sessions and the new
///   `AiSuggestionRows` table for AI review — see `docs/ai_review.md`.
/// - v4: (Phase 7) added the new `ReportRows` table for generated PDF
///   report metadata — see `docs/report.md`.
@DriftDatabase(
  tables: [
    InspectionSessionRows,
    SectionRows,
    FindingRows,
    EvidenceRows,
    AiSuggestionRows,
    ReportRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (creating if necessary) the on-device database file under
  /// the app's documents directory.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 4;

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
      if (from < 3) {
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.aiReviewState,
        );
        await migrator.createTable(aiSuggestionRows);
      }
      if (from < 4) {
        await migrator.createTable(reportRows);
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
