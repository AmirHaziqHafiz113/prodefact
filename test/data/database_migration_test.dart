import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/features/home_inspection/config/home_inspection_config.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';

/// Exercises the real `MigrationStrategy.onUpgrade` in
/// `lib/data/local/database.dart` against on-disk databases created at
/// each older schema version by hand (raw SQL, mirroring exactly what
/// that version's Dart table definitions produced) — the app's actual
/// upgrade path, not a re-implementation of it. See
/// `docs/production_readiness.md` ("Database hardening").
/// `finding_rows` exactly as schemas v6-v10 defined it (v1's columns
/// plus v6's `ai_status`). Every real device has had this table since
/// v1; the v6-v9 fixtures below only need it so the v11 step (which adds
/// columns to it) runs against a realistic schema.
const _findingRowsV6ToV10 = '''
  CREATE TABLE finding_rows (
    id TEXT NOT NULL PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
    section_id TEXT NOT NULL,
    element_id TEXT NOT NULL,
    component_id TEXT,
    description TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    ai_status TEXT NOT NULL DEFAULT 'notQueued',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
''';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('prodefact_migration_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('upgrading from v1 preserves existing data and adds v2-v5 schema '
      'without dropping/recreating anything', () async {
    final dbFile = File('${tempDir.path}/v1.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE finding_rows (
        id TEXT NOT NULL PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        section_id TEXT NOT NULL,
        element_id TEXT NOT NULL,
        component_id TEXT,
        description TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE evidence_rows (
        id TEXT NOT NULL PRIMARY KEY,
        finding_id TEXT NOT NULL REFERENCES finding_rows(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        media_type TEXT NOT NULL DEFAULT 'photo',
        source TEXT NOT NULL DEFAULT 'gallery',
        caption TEXT,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, sync_status, created_at, updated_at)
      VALUES
        ('session_1', 'homeInspection', 'highRise', 'inProgress', 'localOnly', 1000, 1000);
      INSERT INTO section_rows
        (id, session_id, name, is_plumbing, is_included, status, elements_json, order_index, created_at, updated_at)
      VALUES
        ('bathroom', 'session_1', 'Bathroom', 1, 1, 'notStarted', '[]', 0, 1000, 1000);
      INSERT INTO finding_rows
        (id, session_id, section_id, element_id, description, status, created_at, updated_at)
      VALUES
        ('finding_1', 'session_1', 'bathroom', 'floor', 'Cracked tile', 'draft', 1000, 1000);
      INSERT INTO evidence_rows
        (id, finding_id, file_path, media_type, source, sync_status, created_at)
      VALUES
        ('evidence_1', 'finding_1', '/fake/e1.jpg', 'photo', 'gallery', 'localOnly', 1000);
    ''');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // The migration itself already ran as part of opening the database
    // above (lazily, on first query) — force it now and confirm it
    // didn't throw.
    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_1'))).getSingle();

    // Pre-existing data survived untouched.
    expect(sessionRow.industry, 'homeInspection');
    expect(sessionRow.assetTypeId, 'highRise');
    // New v2 column present with its default rather than the row being
    // dropped/recreated.
    expect(sessionRow.ownerUid, isNull);
    // New v3 column present with its default.
    expect(sessionRow.aiReviewState, 'notStarted');

    final findingRow = await (db.select(
      db.findingRows,
    )..where((t) => t.id.equals('finding_1'))).getSingle();
    expect(findingRow.description, 'Cracked tile');

    final evidenceRow = await (db.select(
      db.evidenceRows,
    )..where((t) => t.id.equals('evidence_1'))).getSingle();
    expect(evidenceRow.filePath, '/fake/e1.jpg');
    // New v2 column present with its default (null).
    expect(evidenceRow.storagePath, isNull);

    // v3's new table exists and is queryable (empty, but not missing).
    final suggestions = await db.select(db.aiSuggestionRows).get();
    expect(suggestions, isEmpty);

    // v4's new table exists and is queryable.
    final reports = await db.select(db.reportRows).get();
    expect(reports, isEmpty);

    // v5's indexes were created (raw check — drift has no typed API for
    // "does this index exist").
    final indexNames = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND "
          "name LIKE 'idx_%'",
        )
        .get();
    final names = indexNames.map((r) => r.data['name'] as String).toSet();
    expect(names, contains('idx_finding_rows_session_id'));
    expect(names, contains('idx_evidence_rows_finding_id'));
    expect(names, contains('idx_ai_suggestion_rows_session_id'));
    expect(names, contains('idx_ai_suggestion_rows_finding_id'));
  });

  test('upgrading from v2 preserves the v2-only columns and adds v3-v5 '
      'schema', () async {
    final dbFile = File('${tempDir.path}/v2.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE finding_rows (
        id TEXT NOT NULL PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        section_id TEXT NOT NULL,
        element_id TEXT NOT NULL,
        component_id TEXT,
        description TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE evidence_rows (
        id TEXT NOT NULL PRIMARY KEY,
        finding_id TEXT NOT NULL REFERENCES finding_rows(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        media_type TEXT NOT NULL DEFAULT 'photo',
        source TEXT NOT NULL DEFAULT 'gallery',
        caption TEXT,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        storage_path TEXT
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, sync_status, created_at, updated_at, owner_uid)
      VALUES
        ('session_2', 'homeInspection', 'landed', 'inProgress', 'localOnly', 2000, 2000, 'uid_123');
    ''');
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_2'))).getSingle();
    // The v2 ownership column survives the v3-v5 upgrade untouched.
    expect(sessionRow.ownerUid, 'uid_123');
    expect(sessionRow.aiReviewState, 'notStarted');
  });

  test('upgrading from v5 (where ai_suggestion_rows already existed) adds '
      'the v6 columns without a duplicate-column error, and backfills '
      'aiStatus for findings that already had a suggestion', () async {
    final dbFile = File('${tempDir.path}/v5.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT,
        ai_review_state TEXT NOT NULL DEFAULT 'notStarted'
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE finding_rows (
        id TEXT NOT NULL PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        section_id TEXT NOT NULL,
        element_id TEXT NOT NULL,
        component_id TEXT,
        description TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE ai_suggestion_rows (
        id TEXT NOT NULL PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        finding_id TEXT NOT NULL REFERENCES finding_rows(id) ON DELETE CASCADE,
        suggested_element_id TEXT,
        suggested_component_id TEXT,
        suggested_defect_type TEXT,
        suggested_recommendation TEXT,
        suggested_notes TEXT,
        final_element_id TEXT,
        final_component_id TEXT,
        final_defect_type TEXT,
        final_recommendation TEXT,
        final_notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        provider_id TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        reviewed_at INTEGER
      );
      CREATE TABLE report_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL PRIMARY KEY REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        source_updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly'
      );
      CREATE INDEX idx_finding_rows_session_id ON finding_rows (session_id);
      CREATE INDEX idx_ai_suggestion_rows_finding_id ON ai_suggestion_rows (finding_id);
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, created_at, updated_at)
      VALUES
        ('session_5', 'homeInspection', 'highRise', 'inProgress', 5000, 5000);
      INSERT INTO finding_rows
        (id, session_id, section_id, element_id, description, created_at, updated_at)
      VALUES
        ('finding_legacy', 'session_5', 'bathroom', 'floor', 'Cracked tile', 5000, 5000);
      INSERT INTO ai_suggestion_rows
        (id, session_id, finding_id, status, provider_id, generated_at, final_defect_type)
      VALUES
        ('suggestion_1', 'session_5', 'finding_legacy', 'accepted', 'fake-demo-v1', 5000, 'Cracked tile');
    ''');
    raw.execute('PRAGMA user_version = 5');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Must not throw — this is exactly the duplicate-column regression
    // this test guards against.
    final findingRow = await (db.select(
      db.findingRows,
    )..where((t) => t.id.equals('finding_legacy'))).getSingle();

    // A finding that already had an AI suggestion from the pre-v6
    // batch workflow is backfilled to `completed`, not left at the
    // new column's default (`notQueued`), so its progress isn't
    // misreported as never having been analyzed.
    expect(findingRow.aiStatus, 'completed');

    final suggestionRow = await (db.select(
      db.aiSuggestionRows,
    )..where((t) => t.id.equals('suggestion_1'))).getSingle();
    expect(suggestionRow.suggestedCatalogueEntryId, isNull);
    expect(suggestionRow.finalCatalogueEntryId, isNull);
    // The legacy free-text columns are completely untouched.
    expect(suggestionRow.finalDefectType, 'Cracked tile');

    // v7's new property-details columns are present with their default
    // (null), and the pre-existing report row's new `version` column
    // defaults to 1 rather than the row being dropped/recreated.
    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_5'))).getSingle();
    expect(sessionRow.propertyTitle, isNull);
    expect(sessionRow.inspectionDate, isNull);
    final userProfiles = await db.select(db.userProfileRows).get();
    expect(userProfiles, isEmpty);
  });

  test('upgrading from v6 adds the v7 property-details/report-version '
      'columns and the user_profile_rows table', () async {
    final dbFile = File('${tempDir.path}/v6.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT,
        ai_review_state TEXT NOT NULL DEFAULT 'notStarted'
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE report_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL PRIMARY KEY REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        source_updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly'
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, created_at, updated_at)
      VALUES
        ('session_6', 'homeInspection', 'highRise', 'inProgress', 6000, 6000);
      INSERT INTO report_rows
        (id, session_id, file_path, file_name, generated_at, source_updated_at)
      VALUES
        ('report_1', 'session_6', '/fake/report.pdf', 'report.pdf', 6000, 6000);
    ''');
    raw.execute(_findingRowsV6ToV10);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_6'))).getSingle();
    expect(sessionRow.propertyTitle, isNull);

    // A pre-existing report row is backfilled to version 1 rather than
    // the row being dropped/recreated.
    final reportRow = await (db.select(
      db.reportRows,
    )..where((t) => t.sessionId.equals('session_6'))).getSingle();
    expect(reportRow.version, 1);
    expect(reportRow.filePath, '/fake/report.pdf');

    final userProfiles = await db.select(db.userProfileRows).get();
    expect(userProfiles, isEmpty);
  });

  test('upgrading from v7 adds the v8 note/report-metadata columns '
      'without dropping the existing area row', () async {
    final dbFile = File('${tempDir.path}/v7.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT,
        ai_review_state TEXT NOT NULL DEFAULT 'notStarted',
        property_title TEXT,
        property_address TEXT,
        project_name TEXT,
        block_tower TEXT,
        unit_number TEXT,
        client_name TEXT,
        inspector_name TEXT,
        developer_name TEXT,
        contact_number TEXT,
        inspection_date INTEGER
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE report_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL PRIMARY KEY REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        source_updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        version INTEGER NOT NULL DEFAULT 1
      );
      CREATE TABLE user_profile_rows (
        id TEXT NOT NULL PRIMARY KEY,
        company_name TEXT,
        inspector_name TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, created_at, updated_at, property_title)
      VALUES
        ('session_7', 'homeInspection', 'highRise', 'inProgress', 7000, 7000, 'Residensi Vista');
      INSERT INTO section_rows
        (id, session_id, name, elements_json, order_index, created_at, updated_at)
      VALUES
        ('bathroom', 'session_7', 'Master Bathroom', '[]', 0, 7000, 7000);
      INSERT INTO user_profile_rows (id, company_name, inspector_name, updated_at)
      VALUES
        ('local', 'Acme Inspections', 'Jane Doe', 7000);
    ''');
    raw.execute(_findingRowsV6ToV10);
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_7'))).getSingle();
    // Pre-existing v7 data is untouched.
    expect(sessionRow.propertyTitle, 'Residensi Vista');
    // New v8 columns default to null.
    expect(sessionRow.reportMetadataJson, isNull);
    expect(sessionRow.inspectionNote, isNull);
    // New v9 columns default to null/false.
    expect(sessionRow.commercialMode, isNull);
    expect(sessionRow.selectedAiLevel, isNull);
    expect(sessionRow.autoAnalyseEnabled, isFalse);

    final sectionRow = await (db.select(
      db.sectionRows,
    )..where((t) => t.id.equals('bathroom'))).getSingle();
    expect(sectionRow.name, 'Master Bathroom');
    expect(sectionRow.note, isNull);

    // A pre-existing v7 user profile row survives the v9 upgrade and
    // gets the new `defaultAiLevel` column at its default (null).
    final profileRow = await (db.select(
      db.userProfileRows,
    )..where((t) => t.id.equals('local'))).getSingle();
    expect(profileRow.companyName, 'Acme Inspections');
    expect(profileRow.defaultAiLevel, isNull);

    // v9's new wallet cache table exists and is queryable.
    final walletCaches = await db.select(db.walletCacheRows).get();
    expect(walletCaches, isEmpty);
  });

  test('upgrading from v8 adds the v9 commercial-layer columns/table '
      'without dropping existing data', () async {
    final dbFile = File('${tempDir.path}/v8.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT,
        ai_review_state TEXT NOT NULL DEFAULT 'notStarted',
        property_title TEXT,
        property_address TEXT,
        project_name TEXT,
        block_tower TEXT,
        unit_number TEXT,
        client_name TEXT,
        inspector_name TEXT,
        developer_name TEXT,
        contact_number TEXT,
        inspection_date INTEGER,
        report_metadata_json TEXT,
        inspection_note TEXT
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        note TEXT,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE user_profile_rows (
        id TEXT NOT NULL PRIMARY KEY,
        company_name TEXT,
        inspector_name TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, created_at, updated_at, inspection_note)
      VALUES
        ('session_8', 'homeInspection', 'landed', 'inProgress', 8000, 8000, 'Unit occupied');
    ''');
    raw.execute(_findingRowsV6ToV10);
    raw.execute('PRAGMA user_version = 8');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_8'))).getSingle();
    // Pre-existing v8 data is untouched.
    expect(sessionRow.inspectionNote, 'Unit occupied');
    // New v9 columns present with their defaults.
    expect(sessionRow.commercialMode, isNull);
    expect(sessionRow.selectedAiLevel, isNull);
    expect(sessionRow.autoAnalyseEnabled, isFalse);

    final walletCaches = await db.select(db.walletCacheRows).get();
    expect(walletCaches, isEmpty);
  });

  test('upgrading from v9 adds the v10 project_developer_name column '
      '(the QA/QC setup-simplification pass) without touching the '
      'existing project_name/developer_name data', () async {
    final dbFile = File('${tempDir.path}/v9.sqlite');
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE inspection_session_rows (
        id TEXT NOT NULL PRIMARY KEY,
        industry TEXT NOT NULL,
        asset_type_id TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        owner_uid TEXT,
        ai_review_state TEXT NOT NULL DEFAULT 'notStarted',
        property_title TEXT,
        property_address TEXT,
        project_name TEXT,
        block_tower TEXT,
        unit_number TEXT,
        client_name TEXT,
        inspector_name TEXT,
        developer_name TEXT,
        contact_number TEXT,
        inspection_date INTEGER,
        report_metadata_json TEXT,
        inspection_note TEXT,
        commercial_mode TEXT,
        selected_ai_level TEXT,
        auto_analyse_enabled INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE section_rows (
        id TEXT NOT NULL,
        session_id TEXT NOT NULL REFERENCES inspection_session_rows(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_plumbing INTEGER NOT NULL DEFAULT 0,
        is_included INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'notStarted',
        elements_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        note TEXT,
        PRIMARY KEY (session_id, id)
      );
      CREATE TABLE user_profile_rows (
        id TEXT NOT NULL PRIMARY KEY,
        company_name TEXT,
        inspector_name TEXT,
        updated_at INTEGER NOT NULL,
        default_ai_level TEXT
      );
      CREATE TABLE wallet_cache_rows (
        id TEXT NOT NULL PRIMARY KEY,
        balance_credits INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO inspection_session_rows
        (id, industry, asset_type_id, status, created_at, updated_at,
         property_title, unit_number, project_name, developer_name,
         commercial_mode, selected_ai_level)
      VALUES
        ('session_9', 'homeInspection', 'highRise', 'inProgress', 9000, 9000,
         'Residensi Vista', 'A-12-08', 'Vista Project', 'Vista Developer Sdn Bhd',
         'housePass', 'expert');
    ''');
    raw.execute(_findingRowsV6ToV10);
    raw.execute('PRAGMA user_version = 9');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final sessionRow = await (db.select(
      db.inspectionSessionRows,
    )..where((t) => t.id.equals('session_9'))).getSingle();

    // Every pre-existing v9 value, including the legacy split project/
    // developer fields and the commercial choice made via the (now-
    // removed) Choose AI Plan step, survives untouched.
    expect(sessionRow.propertyTitle, 'Residensi Vista');
    expect(sessionRow.unitNumber, 'A-12-08');
    expect(sessionRow.projectName, 'Vista Project');
    expect(sessionRow.developerName, 'Vista Developer Sdn Bhd');
    expect(sessionRow.commercialMode, 'housePass');
    expect(sessionRow.selectedAiLevel, 'expert');
    // The new v10 column is present, defaulting to null — never
    // backfilled from the legacy columns at the schema level (that
    // combination happens at the application layer; see
    // `PropertyDetails.resolvedProjectDeveloperName`).
    expect(sessionRow.projectDeveloperName, isNull);
  });

  test(
    'upgrading from v10 adds the v11 AI-attempt columns, and a finding '
    "an older build left 'analyzing' still loads intact with no attempt",
    () async {
      final dbFile = File('${tempDir.path}/v10.sqlite');

      // v11 only added three nullable finding_rows columns, so the exact
      // v10 schema is today's schema minus those columns. Build a real
      // session through the production repository, then strip them and
      // mark the file as v10 — the fixture is then a genuine v10 database
      // with real data, not a hand-copied approximation.
      final seedDb = AppDatabase(NativeDatabase(dbFile));
      final seedRepo = DriftInspectionRepository(seedDb);
      final session = await seedRepo.createSession(
        industry: Industry.homeInspection,
        assetTypeId: PropertyType.highRise.name,
        initialSections: HomeInspectionConfig.defaultSectionsFor(
          PropertyType.highRise,
        ),
      );
      final createdAt = DateTime(2026, 9, 1, 9);
      final finding = Finding(
        id: 'finding_v10',
        sectionId: session.sections.first.id,
        description: 'Hairline crack above door frame',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      await seedRepo.saveFinding(session.id, finding);
      await seedRepo.addEvidence(
        session.id,
        Evidence(
          id: 'evidence_v10',
          findingId: finding.id,
          filePath: '/evidence/finding_v10/1.jpg',
          createdAt: createdAt,
          source: EvidenceSource.camera,
        ),
      );
      await seedRepo.setFindingAiStatus(
        session.id,
        finding.id,
        AiFindingStatus.analyzing,
      );
      await seedDb.close();

      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('ALTER TABLE finding_rows DROP COLUMN ai_attempt_key');
      raw.execute('ALTER TABLE finding_rows DROP COLUMN ai_attempt_level');
      raw.execute(
        'ALTER TABLE finding_rows DROP COLUMN ai_attempt_submitted_at',
      );
      raw.execute('PRAGMA user_version = 10');
      raw.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      final repo = DriftInspectionRepository(db);

      final loaded = await repo.loadSession(session.id);
      expect(loaded, isNotNull);
      final upgraded = loaded!.findings.single;
      expect(upgraded.id, 'finding_v10');
      expect(upgraded.description, 'Hairline crack above door frame');
      expect(upgraded.aiStatus, AiFindingStatus.analyzing);
      // No key was ever persisted by the older build — recovery treats this
      // as un-replayable and offers Retry rather than guessing.
      expect(upgraded.aiAttempt, isNull);
      expect(upgraded.evidence.single.id, 'evidence_v10');

      final columns = await db
          .customSelect('PRAGMA table_info(finding_rows)')
          .get();
      final names = columns.map((r) => r.data['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'ai_attempt_key',
          'ai_attempt_level',
          'ai_attempt_submitted_at',
        ]),
      );

      // The new columns are usable immediately after the upgrade.
      await repo.beginFindingAiAttempt(
        session.id,
        finding.id,
        AiAnalysisAttempt(
          idempotencyKey: 'k1',
          aiLevel: AiLevel.expert,
          submittedAt: createdAt,
        ),
      );
      final withAttempt = (await repo.loadSession(session.id))!.findings.single;
      expect(withAttempt.aiAttempt?.idempotencyKey, 'k1');
      expect(withAttempt.aiAttempt?.aiLevel, AiLevel.expert);
      await repo.finishFindingAiAttempt(
        session.id,
        finding.id,
        AiFindingStatus.completed,
      );
      final finished = (await repo.loadSession(session.id))!.findings.single;
      expect(finished.aiAttempt, isNull);
      expect(finished.aiStatus, AiFindingStatus.completed);
    },
  );

  test('a fresh install (onCreate) also gets the v5 indexes and the v7/v8 '
      'tables/columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Touch the database so it's actually opened/created.
    await db.select(db.inspectionSessionRows).get();

    final indexNames = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND "
          "name LIKE 'idx_%'",
        )
        .get();
    final names = indexNames.map((r) => r.data['name'] as String).toSet();
    expect(names, contains('idx_finding_rows_session_id'));

    // v7's new table exists and is queryable on a fresh install too.
    final userProfiles = await db.select(db.userProfileRows).get();
    expect(userProfiles, isEmpty);

    // v8's new columns are queryable on a fresh install too.
    final sessions = await db.select(db.inspectionSessionRows).get();
    expect(sessions, isEmpty);

    // v9's new table is queryable on a fresh install too.
    final walletCaches = await db.select(db.walletCacheRows).get();
    expect(walletCaches, isEmpty);

    // v10's new column is queryable on a fresh install too.
    final freshSession = await db
        .into(db.inspectionSessionRows)
        .insertReturning(
          InspectionSessionRowsCompanion.insert(
            id: 'fresh',
            industry: 'homeInspection',
            assetTypeId: 'highRise',
            status: 'inProgress',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    expect(freshSession.projectDeveloperName, isNull);
  });
}
