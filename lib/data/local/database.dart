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
/// - v6: (camera-first pass) added `FindingRows.aiStatus` (defaults to
///   `notQueued`, correct for every pre-existing finding) and four new
///   nullable `AiSuggestionRows` columns for controlled-catalogue
///   classification (`suggestedCatalogueEntryId`,
///   `suggestedConfidence`, `suggestedShortReason`,
///   `suggestedCandidateEntryIds`, `finalCatalogueEntryId`) — additive
///   only. A finding that already has an `AiSuggestion` row from the
///   old batch workflow is backfilled to `aiStatus = 'completed'` so
///   its existing progress isn't misreported as "not yet queued" —
///   see `docs/production_readiness.md` ("Camera-first migration").
///   `FindingRows.elementId` stays a NOT NULL column unchanged (SQLite
///   can't relax that via `ALTER TABLE` without a full rebuild);
///   nullability for camera-first findings is handled at the
///   application layer instead (`''` <-> `null`, see the table's doc
///   comment) — no schema change needed for that part at all.
/// - v7: (product flow consolidation pass) added nine nullable property-
///   details columns to `InspectionSessionRows` (title, address,
///   project/development name, block/tower, unit number, client name,
///   inspector name, developer name, contact number) and a nullable
///   `inspectionDate`, all fed by the new Property Details setup step —
///   see `PropertyDetails`. Added `ReportRows.version` (defaults to 1,
///   correct for every pre-existing report) so regenerating after
///   inspection data changed produces a visibly new version rather than
///   a silent overwrite. Added the new `UserProfileRows` table (a
///   single local row) for on-device inspector/company prefill data —
///   see `UserProfile`. All additive; no existing column or table is
///   altered or dropped.
/// - v8: (P0 workflow-closure pass) added `InspectionSessionRows.
///   reportMetadataJson` (nullable, JSON-encoded `ReportMetadata` —
///   the inspector-confirmed report cover-page values, deliberately
///   separate from the v7 property-details columns so confirming/
///   editing report metadata can never corrupt the original New
///   Inspection setup) and `InspectionSessionRows.inspectionNote`
///   (nullable). Added `SectionRows.note` (nullable) for per-area
///   contextual notes. All additive/nullable; no existing data
///   affected.
/// - v9: (commercial layer pass) added `InspectionSessionRows.
///   commercialMode`/`selectedAiLevel` (nullable — see `CommercialMode`/
///   `AiLevel`) and `autoAnalyseEnabled` (defaults to false, correct for
///   every pre-existing session) for the Choose AI Plan step. Added
///   `UserProfileRows.defaultAiLevel` (nullable) for the Profile
///   preference. Added the new `WalletCacheRows` table — a local,
///   non-authoritative *display* cache of the Credits balance; the
///   backend ledger is always the source of truth (see
///   docs/commercial_model.md). All additive; no existing column or
///   table is altered or dropped.
/// - v10: (QA/QC setup-simplification pass) added
///   `InspectionSessionRows.projectDeveloperName` (nullable) — the
///   single combined field replacing the old separate `projectName`/
///   `developerName` split inspectors found confusing. Both legacy
///   columns are kept as-is (never dropped, never backfilled) so an
///   inspection saved before this migration keeps loading exactly as
///   it did; the application layer resolves which to show — see
///   `PropertyDetails.resolvedProjectDeveloperName`. Additive only.
/// - v11: (stuck-AI recovery pass) added three nullable `FindingRows`
///   columns — `aiAttemptKey`, `aiAttemptLevel`,
///   `aiAttemptSubmittedAt` — persisting the idempotency identity of an
///   AI analysis request *before* it is sent, so an interrupted request
///   can be replayed safely after an app restart instead of being left
///   spinning forever or re-sent under a new (separately charged) key.
///   See `AiAnalysisAttempt`. Null for every pre-existing finding, which
///   correctly means "no request outstanding". Additive only.
/// - v13: (QA/QC newly discovered areas) added the `AreaCandidateRows`
///   table: newly discovered area names queued for submission as
///   candidates for future suggestions. New table only.
/// - v12: (QA/QC evidence pass) added `EvidenceRows.annotatedFilePath`
///   (nullable): a separate marked-up copy of a photo. The original file
///   is never modified. Null for every pre-existing photo. Additive only.
/// - v14: (P0 AI workflow pass) added `FindingRows.captureBatchId` and
///   `AiSuggestionRows.suggestedDefectTerm` (both nullable, additive),
///   and set every session's `autoAnalyseEnabled` to true — AI analysis
///   is now always automatic, so an old opt-out is retired, not kept.
/// - v17: (custom catalogue pass) added the `CustomDefectRows` table —
///   defects a company added to its own catalogue. New table only.
/// - v16: (AI accuracy pass) added AI-suggestion evaluation columns —
///   `needsReviewReason`, `noteImageAgreement`, `detectedComponent`,
///   `aiLevel`, `aiJobKey`, `reanalysisCount` (default 0) and
///   `historyJson` (earlier results kept on Reanalyse). Additive only.
/// - v15: (photo guidance pass) added `AiSuggestionRows.imageRelevant`,
///   `imageUsable` and `imageQualityIssues` (all nullable, additive).
@DriftDatabase(
  tables: [
    InspectionSessionRows,
    SectionRows,
    FindingRows,
    EvidenceRows,
    AiSuggestionRows,
    ReportRows,
    UserProfileRows,
    WalletCacheRows,
    AreaCandidateRows,
    CustomDefectRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (creating if necessary) the on-device database file under
  /// the app's documents directory.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 17;

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
      if (from < 6) {
        await migrator.addColumn(findingRows, findingRows.aiStatus);
        // `aiSuggestionRows` only needs these columns added if the
        // table already existed *before* this migration run (from >=
        // 3) — `migrator.createTable` above (for `from < 3`) always
        // builds the table from the current Dart class definition,
        // which already includes every column declared on it today
        // (these v6 ones included). Adding them again in that case
        // would be a duplicate-column error — this is exactly what a
        // device last opened at schema v1/v2 jumping straight to v6
        // would otherwise hit.
        if (from >= 3) {
          await migrator.addColumn(
            aiSuggestionRows,
            aiSuggestionRows.suggestedCatalogueEntryId,
          );
          await migrator.addColumn(
            aiSuggestionRows,
            aiSuggestionRows.suggestedConfidence,
          );
          await migrator.addColumn(
            aiSuggestionRows,
            aiSuggestionRows.suggestedShortReason,
          );
          await migrator.addColumn(
            aiSuggestionRows,
            aiSuggestionRows.suggestedCandidateEntryIds,
          );
          await migrator.addColumn(
            aiSuggestionRows,
            aiSuggestionRows.finalCatalogueEntryId,
          );
        }
        // A finding that already has an AI suggestion from the old
        // batch workflow has, in effect, already completed AI
        // processing — without this, it would default to `notQueued`
        // and misreport as never having been analyzed.
        await migrator.database.customStatement(
          "UPDATE finding_rows SET ai_status = 'completed' "
          'WHERE id IN (SELECT finding_id FROM ai_suggestion_rows)',
        );
      }
      if (from < 7) {
        for (final column in [
          inspectionSessionRows.propertyTitle,
          inspectionSessionRows.propertyAddress,
          inspectionSessionRows.projectName,
          inspectionSessionRows.blockTower,
          inspectionSessionRows.unitNumber,
          inspectionSessionRows.clientName,
          inspectionSessionRows.inspectorName,
          inspectionSessionRows.developerName,
          inspectionSessionRows.contactNumber,
          inspectionSessionRows.inspectionDate,
        ]) {
          await migrator.addColumn(inspectionSessionRows, column);
        }
        // `reportRows`/`userProfileRows` only need special handling the
        // same way `aiSuggestionRows` did at v6: `createTable` for a
        // brand-new table (from < 4, above) already builds it from the
        // *current* Dart definition, which already includes `version` —
        // adding it again in that case would be a duplicate-column
        // error. Only a report row that already existed before this
        // migration run needs the column added here.
        if (from >= 4) {
          await migrator.addColumn(reportRows, reportRows.version);
        }
        await migrator.createTable(userProfileRows);
      }
      if (from < 8) {
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.reportMetadataJson,
        );
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.inspectionNote,
        );
        await migrator.addColumn(sectionRows, sectionRows.note);
      }
      if (from < 9) {
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.commercialMode,
        );
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.selectedAiLevel,
        );
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.autoAnalyseEnabled,
        );
        // `userProfileRows` only needs the column added here if the
        // table already existed before this migration run (from >= 7,
        // when it was created) — the same guard `reportRows.version`
        // used at v7 for the identical reason.
        if (from >= 7) {
          await migrator.addColumn(
            userProfileRows,
            userProfileRows.defaultAiLevel,
          );
        }
        await migrator.createTable(walletCacheRows);
      }
      if (from < 10) {
        await migrator.addColumn(
          inspectionSessionRows,
          inspectionSessionRows.projectDeveloperName,
        );
      }
      if (from < 11) {
        // `findingRows` has existed since v1 and is never recreated by
        // an earlier step above, so these columns are always missing
        // here regardless of which version the device is upgrading from.
        await migrator.addColumn(findingRows, findingRows.aiAttemptKey);
        await migrator.addColumn(findingRows, findingRows.aiAttemptLevel);
        await migrator.addColumn(findingRows, findingRows.aiAttemptSubmittedAt);
      }
      if (from < 12) {
        // `evidenceRows` has existed since v1 and is never recreated
        // above, so the column is always missing here.
        await migrator.addColumn(evidenceRows, evidenceRows.annotatedFilePath);
      }
      if (from < 13) {
        await migrator.createTable(areaCandidateRows);
      }
      if (from < 14) {
        // Purely additive. A table created above from today's Dart
        // definition (e.g. `aiSuggestionRows` for from < 3) already has
        // these columns, so each is added only where it is missing.
        await _addColumnIfMissing(
          migrator,
          findingRows,
          findingRows.captureBatchId,
        );
        await _addColumnIfMissing(
          migrator,
          aiSuggestionRows,
          aiSuggestionRows.suggestedDefectTerm,
        );
        await customStatement(
          'UPDATE inspection_session_rows SET auto_analyse_enabled = 1',
        );
      }
      if (from < 15) {
        for (final column in [
          aiSuggestionRows.imageRelevant,
          aiSuggestionRows.imageUsable,
          aiSuggestionRows.imageQualityIssues,
        ]) {
          await _addColumnIfMissing(migrator, aiSuggestionRows, column);
        }
      }
      if (from < 17) {
        await migrator.createTable(customDefectRows);
      }
      if (from < 16) {
        for (final column in [
          aiSuggestionRows.needsReviewReason,
          aiSuggestionRows.noteImageAgreement,
          aiSuggestionRows.detectedComponent,
          aiSuggestionRows.aiLevel,
          aiSuggestionRows.aiJobKey,
          aiSuggestionRows.reanalysisCount,
          aiSuggestionRows.historyJson,
        ]) {
          await _addColumnIfMissing(migrator, aiSuggestionRows, column);
        }
      }
    },
  );

  /// Adds [column] to [table] unless the table is absent or already has
  /// it — for additive migrations that can follow a step which built
  /// the table from the current definition.
  static Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final info = await migrator.database
        .customSelect('PRAGMA table_info(${table.actualTableName})')
        .get();
    if (info.isEmpty) return; // no such table
    final exists = info.any((row) => row.read<String>('name') == column.name);
    if (!exists) await migrator.addColumn(table, column);
  }

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
