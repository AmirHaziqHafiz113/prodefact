import 'package:drift/drift.dart';

/// One inspection session: identity plus top-level lifecycle metadata.
/// Sections, findings, and evidence live in their own tables, keyed by
/// [id].
class InspectionSessionRows extends Table {
  TextColumn get id => text()();
  TextColumn get industry => text()();
  TextColumn get assetTypeId => text()();
  TextColumn get status => text()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// The authenticated user this session belongs to. Null for a "guest"
  /// session created while signed out (added in schema v2).
  TextColumn get ownerUid => text().nullable()();

  /// State of the whole-session AI analysis run (added in schema v3) —
  /// see `AiReviewState`.
  TextColumn get aiReviewState =>
      text().withDefault(const Constant('notStarted'))();

  // ---- property details (added in schema v7) — see `PropertyDetails`.
  // All nullable: a pre-v7 session has none of these and falls back to
  // `assetTypeId`'s property-type label wherever this would be shown.
  TextColumn get propertyTitle => text().nullable()();
  TextColumn get propertyAddress => text().nullable()();

  /// Deprecated in schema v10 in favor of [projectDeveloperName] — kept
  /// (read-only from new code) so an inspection saved before that merge
  /// still loads with its data intact. See
  /// `PropertyDetails.resolvedProjectDeveloperName`.
  TextColumn get projectName => text().nullable()();
  TextColumn get blockTower => text().nullable()();
  TextColumn get unitNumber => text().nullable()();
  TextColumn get clientName => text().nullable()();
  TextColumn get inspectorName => text().nullable()();
  TextColumn get developerName => text().nullable()();
  TextColumn get contactNumber => text().nullable()();
  DateTimeColumn get inspectionDate => dateTime().nullable()();

  /// The inspector-confirmed report cover-page metadata (added in
  /// schema v8), JSON-encoded — see `ReportMetadata`. Null until
  /// confirmed at least once via the Report Details step; the report
  /// falls back to deriving it fresh from the property-details columns
  /// above in that case. A blob column (like `SectionRows.elementsJson`)
  /// rather than one column per field, since it's edited as a whole
  /// unit on one screen and never queried by individual field.
  TextColumn get reportMetadataJson => text().nullable()();

  /// An optional, contextual note about the whole inspection (added in
  /// schema v8) — e.g. "Unit occupied during inspection." Not a defect;
  /// never sent through AI classification.
  TextColumn get inspectionNote => text().nullable()();

  /// How this inspection pays for AI analysis — `flexCredits` or
  /// `housePass` (added in schema v9), chosen once via the Choose AI
  /// Plan step. Null for a pre-v9 session or one still awaiting that
  /// choice — see `CommercialMode`, docs/commercial_model.md.
  TextColumn get commercialMode => text().nullable()();

  /// The inspector's chosen AI quality tier for this inspection —
  /// `fast`/`smart`/`expert` (added in schema v9). See `AiLevel`.
  TextColumn get selectedAiLevel => text().nullable()();

  /// Whether AI analysis should run automatically after Save Finding
  /// (added in schema v9). Defaults to false (Flex Credits' safe
  /// default) — never true for any pre-existing session.
  BoolColumn get autoAnalyseEnabled =>
      boolean().withDefault(const Constant(false))();

  /// The single "Project / Developer Name" field (added in schema v10,
  /// QA/QC setup-simplification pass) — replaces the previous separate
  /// [projectName]/[developerName] fields going forward. Both legacy
  /// columns are kept, untouched, for backward compatibility; see
  /// `PropertyDetails.resolvedProjectDeveloperName`.
  TextColumn get projectDeveloperName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A configured area within a session. [elementsJson] stores the area's
/// element/component template as JSON rather than as normalized tables —
/// inspectors configure areas (include/exclude/rename/add/remove) but
/// never edit elements/components independently, so a template blob is
/// simpler than a join without losing any capability.
///
/// [id] is only unique *within* a session, not globally — default areas
/// get deterministic, name-derived ids (e.g. "kitchen"), so the same id
/// reappears in every session of the same property type. The primary
/// key is therefore the (sessionId, id) pair.
class SectionRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    InspectionSessionRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get name => text()();
  BoolColumn get isPlumbing => boolean().withDefault(const Constant(false))();
  BoolColumn get isIncluded => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('notStarted'))();
  TextColumn get elementsJson => text()();
  IntColumn get orderIndex => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// An optional, contextual note about this area (added in schema v8)
  /// — see `Section.note`.
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId, id};
}

/// A defect/observation recorded against a section ("area"). Camera-
/// first (schema v6+): the inspector doesn't pick an element/component
/// up front any more, so [elementId] is stored as `''` (never SQL
/// NULL — see the class doc comment) to mean "not classified by the
/// inspector"; classification instead comes from AI, tracked via
/// [aiStatus] and the linked `AiSuggestionRows` row.
///
/// A pre-v6 (legacy, component-first) finding still has a real,
/// non-empty [elementId] here — nothing about existing rows changes.
class FindingRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    InspectionSessionRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get sectionId => text()();

  /// `''` means "not set" (camera-first finding) — see the class doc
  /// comment for why this is an empty string rather than SQL NULL:
  /// relaxing an existing NOT NULL column's constraint isn't something
  /// Drift/SQLite's `ALTER TABLE` supports without a full table
  /// rebuild, so nullability is handled at the application layer
  /// instead (`DriftInspectionRepository` maps `''` <-> `null`) — zero
  /// schema risk to the column that already holds every legacy
  /// finding's real element id.
  TextColumn get elementId => text()();
  TextColumn get componentId => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();

  /// The per-finding AI processing pipeline state (added in schema v6)
  /// — see `AiFindingStatus`. Defaults to `notQueued`, which is also
  /// the correct value for every finding that existed before this
  /// column did.
  TextColumn get aiStatus => text().withDefault(const Constant('notQueued'))();

  /// The outstanding AI analysis request's idempotency key, level, and
  /// most recent submission time (added in schema v11) — see
  /// `AiAnalysisAttempt`. All three are null when no request may still
  /// be unresolved, which is also the correct value for every finding
  /// that existed before these columns did.
  TextColumn get aiAttemptKey => text().nullable()();
  TextColumn get aiAttemptLevel => text().nullable()();
  DateTimeColumn get aiAttemptSubmittedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadata for one photo attached to a finding. The file itself lives
/// in app-managed local storage at [filePath] — never raw bytes here.
class EvidenceRows extends Table {
  TextColumn get id => text()();
  TextColumn get findingId =>
      text().references(FindingRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  TextColumn get mediaType => text().withDefault(const Constant('photo'))();
  TextColumn get source => text().withDefault(const Constant('gallery'))();
  TextColumn get caption => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get createdAt => dateTime()();

  /// Where this file lives in cloud storage once uploaded (added in
  /// schema v2). Null until the first successful upload.
  TextColumn get storagePath => text().nullable()();

  /// Local path of the inspector's marked-up copy (added in schema v12)
  /// — see `Evidence.annotatedFilePath`. The original at [filePath] is
  /// never overwritten. Null for every pre-existing photo.
  TextColumn get annotatedFilePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One AI suggestion for one finding (added in schema v3). The
/// `suggested*` columns are the original AI output and are never
/// updated after insertion; the `final*` columns hold whatever the
/// inspector ultimately approved/corrected — see `AiSuggestion` for why
/// these are kept separate.
///
/// `suggestedElementId`/`suggestedComponentId`/`suggestedDefectType`/
/// `suggestedRecommendation`/`suggestedNotes`/`finalElementId`/
/// `finalComponentId`/`finalDefectType`/`finalRecommendation`/
/// `finalNotes` are legacy (pre-v6, free-text) columns — still read
/// for a pre-existing suggestion row, never written by new code, which
/// instead uses the catalogue-id columns added in v6 below.
class AiSuggestionRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    InspectionSessionRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get findingId =>
      text().references(FindingRows, #id, onDelete: KeyAction.cascade)();

  TextColumn get suggestedElementId => text().nullable()();
  TextColumn get suggestedComponentId => text().nullable()();
  TextColumn get suggestedDefectType => text().nullable()();
  TextColumn get suggestedRecommendation => text().nullable()();
  TextColumn get suggestedNotes => text().nullable()();

  TextColumn get finalElementId => text().nullable()();
  TextColumn get finalComponentId => text().nullable()();
  TextColumn get finalDefectType => text().nullable()();
  TextColumn get finalRecommendation => text().nullable()();
  TextColumn get finalNotes => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get providerId => text()();
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();

  /// The controlled catalogue entry id AI selected (added in schema
  /// v6) — null if AI could not confidently classify. See
  /// `DefectCatalogue`/`AiSuggestion.suggestedCatalogueEntryId`.
  TextColumn get suggestedCatalogueEntryId => text().nullable()();
  RealColumn get suggestedConfidence => real().nullable()();
  TextColumn get suggestedShortReason => text().nullable()();

  /// JSON-encoded `List<String>` of ranked alternative catalogue entry
  /// ids (added in schema v6) — empty/absent means no alternates.
  TextColumn get suggestedCandidateEntryIds => text().nullable()();

  /// The inspector-approved/corrected catalogue entry id (added in
  /// schema v6) — see `AiSuggestion.finalCatalogueEntryId` for why an
  /// empty string (not SQL NULL) means "reviewed, explicitly left
  /// unresolved".
  TextColumn get finalCatalogueEntryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadata for the generated PDF report of one session (added in
/// schema v4). Keyed by [sessionId] rather than a separate report id —
/// this directly encodes the "latest report per inspection" policy: a
/// regenerated report replaces this row rather than accumulating
/// history. Never stores raw PDF bytes — only the local file reference.
class ReportRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    InspectionSessionRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get filePath => text()();
  TextColumn get fileName => text()();
  DateTimeColumn get generatedAt => dateTime()();

  /// Snapshot of the session's `updatedAt` at generation time, used to
  /// detect staleness — see `Report.isStaleRelativeTo`.
  DateTimeColumn get sourceUpdatedAt => dateTime()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();

  /// Incremented each time this session's report is regenerated (added
  /// in schema v7) — surfaced to the inspector as "v2", "v3", etc., so
  /// regenerating after inspection data changed is visibly a new
  /// version rather than a silent overwrite. Starts at 1.
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// A single, on-device inspector profile (added in schema v7) — not
/// synced to Firebase; purely local prefill data for report metadata
/// (company name) and new-inspection setup (inspector name). Always one
/// row, keyed by the constant id `'local'` — see `UserProfile`.
class UserProfileRows extends Table {
  TextColumn get id => text()();
  TextColumn get companyName => text().nullable()();
  TextColumn get inspectorName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// The inspector's preferred default AI quality tier for new
  /// inspections (added in schema v9) — see `AiLevel`, `UserProfile.
  /// defaultAiLevel`. Null falls back to the app-wide default.
  TextColumn get defaultAiLevel => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A local, non-authoritative display cache of the last-known Credits
/// wallet balance (added in schema v9) — purely so the Wallet/Home UI
/// has something to show instantly and offline. The backend ledger
/// (`users/{uid}/walletTransactions`) is always the source of truth;
/// this cache is refreshed opportunistically whenever a commercial
/// callable returns a fresh balance, and is never read by any pricing/
/// charging decision. Always one row, keyed by the constant id
/// `'local'` — see `WalletCache`.
class WalletCacheRows extends Table {
  TextColumn get id => text()();
  IntColumn get balanceCredits => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Newly discovered areas queued for submission as candidates (added in
/// schema v13) — see `AreaCandidate`. Holds only the typed name and
/// property type; never inspection or client details.
class AreaCandidateRows extends Table {
  TextColumn get id => text()();
  TextColumn get rawName => text()();
  TextColumn get normalizedName => text()();
  TextColumn get propertyType => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
