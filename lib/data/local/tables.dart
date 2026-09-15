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

  @override
  Set<Column> get primaryKey => {sessionId, id};
}

/// A defect/observation recorded against an element (and, optionally, a
/// component) within a section.
class FindingRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    InspectionSessionRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get sectionId => text()();
  TextColumn get elementId => text()();
  TextColumn get componentId => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
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

  @override
  Set<Column> get primaryKey => {id};
}
