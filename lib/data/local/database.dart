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
/// - v5: (Phase 8) added indexes on the foreign-key columns SQLite
///   doesn't index automatically (`FindingRows.sessionId`,
///   `EvidenceRows.findingId`, `AiSuggestionRows.sessionId`/`findingId`)
///   — `loadSession` looks up rows by exactly these columns, and an
///   inspection with many findings/suggestions would otherwise force a
///   full table scan per lookup. Indexes only; no column/table changes,
///   so nothing here can affect existing data. See
///   `docs/production_readiness.md` ("Database hardening").
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createV5Indexes(migrator);
    },
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
      if (from < 5) {
        await _createV5Indexes(migrator);
      }
    },
  );

  static Future<void> _createV5Indexes(Migrator migrator) async {
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finding_rows_session_id '
      'ON finding_rows (session_id)',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_evidence_rows_finding_id '
      'ON evidence_rows (finding_id)',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_suggestion_rows_session_id '
      'ON ai_suggestion_rows (session_id)',
    );
    await migrator.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_suggestion_rows_finding_id '
      'ON ai_suggestion_rows (finding_id)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'prodefact.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
