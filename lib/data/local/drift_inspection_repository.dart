import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/inspection/inspection_domain.dart';
import 'database.dart';
import 'element_serialization.dart';

/// [FindingRows.elementId] stays a NOT NULL SQL column (see its doc
/// comment) — this sentinel round-trips "not classified" through it
/// without a schema change.
String? _elementIdFromRow(String raw) => raw.isEmpty ? null : raw;
String _elementIdToRow(String? value) => value ?? '';

List<String> _decodeCandidateIds(String? json) {
  if (json == null || json.isEmpty) return const [];
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  return decoded.whereType<String>().toList();
}

String? _encodeCandidateIds(List<String> ids) =>
    ids.isEmpty ? null : jsonEncode(ids);

/// Drift-backed implementation of [InspectionRepository]. This is the
/// only place that touches [AppDatabase]/generated row types directly —
/// everything else in the app depends on the abstract interface.
class DriftInspectionRepository implements InspectionRepository {
  DriftInspectionRepository(this._db);

  final AppDatabase _db;

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<InspectionSession> createSession({
    required Industry industry,
    required String assetTypeId,
    required List<Section> initialSections,
    String? ownerUid,
    PropertyDetails propertyDetails = PropertyDetails.empty,
  }) async {
    final now = DateTime.now();
    final id = _newId('session');

    await _db.transaction(() async {
      await _db
          .into(_db.inspectionSessionRows)
          .insert(
            InspectionSessionRowsCompanion.insert(
              id: id,
              industry: industry.name,
              assetTypeId: assetTypeId,
              status: InspectionStatus.inProgress.name,
              createdAt: now,
              updatedAt: now,
              ownerUid: Value(ownerUid),
              propertyTitle: Value(
                propertyDetails.title.isEmpty ? null : propertyDetails.title,
              ),
              propertyAddress: Value(propertyDetails.address),
              projectName: Value(propertyDetails.projectName),
              blockTower: Value(propertyDetails.blockTower),
              unitNumber: Value(propertyDetails.unitNumber),
              clientName: Value(propertyDetails.clientName),
              inspectorName: Value(propertyDetails.inspectorName),
              developerName: Value(propertyDetails.developerName),
              contactNumber: Value(propertyDetails.contactNumber),
              inspectionDate: Value(propertyDetails.inspectionDate),
            ),
          );

      for (var i = 0; i < initialSections.length; i++) {
        await _insertSection(
          sessionId: id,
          section: initialSections[i],
          orderIndex: i,
          timestamp: now,
        );
      }
    });

    return InspectionSession(
      id: id,
      industry: industry,
      assetTypeId: assetTypeId,
      sections: initialSections,
      sectionStatuses: const {},
      findings: const [],
      createdAt: now,
      updatedAt: now,
      ownerUid: ownerUid,
      propertyDetails: propertyDetails,
    );
  }

  Future<void> _insertSection({
    required String sessionId,
    required Section section,
    required int orderIndex,
    required DateTime timestamp,
  }) {
    return _db
        .into(_db.sectionRows)
        .insert(
          SectionRowsCompanion.insert(
            id: section.id,
            sessionId: sessionId,
            name: section.name,
            isPlumbing: Value(section.isPlumbing),
            isIncluded: Value(section.isIncluded),
            elementsJson: encodeElements(section.elements),
            orderIndex: orderIndex,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  @override
  Future<InspectionSession?> loadSession(String id) async {
    final sessionRow = await (_db.select(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (sessionRow == null) return null;

    final sectionRows =
        await (_db.select(_db.sectionRows)
              ..where((t) => t.sessionId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get();

    final findingRows = await (_db.select(
      _db.findingRows,
    )..where((t) => t.sessionId.equals(id))).get();

    final findingIds = findingRows.map((f) => f.id).toList();
    final evidenceRows = findingIds.isEmpty
        ? <EvidenceRow>[]
        : await (_db.select(
            _db.evidenceRows,
          )..where((t) => t.findingId.isIn(findingIds))).get();

    final aiSuggestionRows = await (_db.select(
      _db.aiSuggestionRows,
    )..where((t) => t.sessionId.equals(id))).get();

    final reportRow = await (_db.select(
      _db.reportRows,
    )..where((t) => t.sessionId.equals(id))).getSingleOrNull();

    final sections = sectionRows
        .map(
          (row) => Section(
            id: row.id,
            name: row.name,
            elements: decodeElements(row.elementsJson),
            isPlumbing: row.isPlumbing,
            isIncluded: row.isIncluded,
          ),
        )
        .toList();

    final sectionStatuses = {
      for (final row in sectionRows)
        row.id: SectionStatus.values.byName(row.status),
    };

    final findings = findingRows.map((row) {
      final evidence = evidenceRows
          .where((e) => e.findingId == row.id)
          .map(
            (e) => Evidence(
              id: e.id,
              findingId: e.findingId,
              filePath: e.filePath,
              createdAt: e.createdAt,
              mediaType: EvidenceMediaType.values.byName(e.mediaType),
              source: EvidenceSource.values.byName(e.source),
              caption: e.caption,
              syncStatus: SyncStatus.values.byName(e.syncStatus),
              storagePath: e.storagePath,
            ),
          )
          .toList();

      return Finding(
        id: row.id,
        sectionId: row.sectionId,
        elementId: _elementIdFromRow(row.elementId),
        componentId: row.componentId,
        description: row.description,
        notes: row.notes,
        status: FindingStatus.values.byName(row.status),
        evidence: evidence,
        aiStatus: AiFindingStatus.values.byName(row.aiStatus),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }).toList();

    final aiSuggestions = aiSuggestionRows
        .map(
          (row) => AiSuggestion(
            id: row.id,
            sessionId: row.sessionId,
            findingId: row.findingId,
            providerId: row.providerId,
            generatedAt: row.generatedAt,
            suggestedCatalogueEntryId: row.suggestedCatalogueEntryId,
            suggestedConfidence: row.suggestedConfidence,
            suggestedShortReason: row.suggestedShortReason,
            suggestedCandidateEntryIds: _decodeCandidateIds(
              row.suggestedCandidateEntryIds,
            ),
            finalCatalogueEntryId: row.finalCatalogueEntryId,
            status: AiSuggestionStatus.values.byName(row.status),
            reviewedAt: row.reviewedAt,
            legacyFinalElementId: row.finalElementId,
            legacyFinalComponentId: row.finalComponentId,
            legacyFinalDefectType: row.finalDefectType,
            legacyFinalRecommendation: row.finalRecommendation,
            legacyFinalNotes: row.finalNotes,
          ),
        )
        .toList();

    return InspectionSession(
      id: sessionRow.id,
      industry: Industry.values.byName(sessionRow.industry),
      assetTypeId: sessionRow.assetTypeId,
      sections: sections,
      sectionStatuses: sectionStatuses,
      findings: findings,
      status: InspectionStatus.values.byName(sessionRow.status),
      createdAt: sessionRow.createdAt,
      updatedAt: sessionRow.updatedAt,
      syncStatus: SyncStatus.values.byName(sessionRow.syncStatus),
      ownerUid: sessionRow.ownerUid,
      aiReviewState: AiReviewState.values.byName(sessionRow.aiReviewState),
      aiSuggestions: aiSuggestions,
      report: reportRow == null
          ? null
          : Report(
              id: reportRow.id,
              sessionId: reportRow.sessionId,
              filePath: reportRow.filePath,
              fileName: reportRow.fileName,
              generatedAt: reportRow.generatedAt,
              sourceUpdatedAt: reportRow.sourceUpdatedAt,
              syncStatus: SyncStatus.values.byName(reportRow.syncStatus),
              version: reportRow.version,
            ),
      propertyDetails: _propertyDetailsFromRow(sessionRow),
    );
  }

  PropertyDetails _propertyDetailsFromRow(InspectionSessionRow row) {
    final title = row.propertyTitle;
    if (title == null || title.isEmpty) return PropertyDetails.empty;
    return PropertyDetails(
      title: title,
      address: row.propertyAddress,
      projectName: row.projectName,
      blockTower: row.blockTower,
      unitNumber: row.unitNumber,
      clientName: row.clientName,
      inspectorName: row.inspectorName,
      developerName: row.developerName,
      contactNumber: row.contactNumber,
      inspectionDate: row.inspectionDate,
    );
  }

  @override
  Future<List<InspectionSessionSummary>> listSessions({
    String? ownerUid,
  }) async {
    // Signed out (ownerUid == null): only still-unclaimed guest
    // sessions. Signed in: that user's own sessions *plus* any
    // still-unclaimed guest sessions on this device — never another
    // user's already-claimed sessions. See docs/firebase.md.
    final query = _db.select(_db.inspectionSessionRows)
      ..where(
        (t) => ownerUid == null
            ? t.ownerUid.isNull()
            : (t.ownerUid.equals(ownerUid) | t.ownerUid.isNull()),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final sessionIds = rows.map((r) => r.id).toList();
    final eligible = await _countPerSession(
      "SELECT session_id, COUNT(*) as c FROM finding_rows f "
      'WHERE f.session_id IN (${_placeholders(sessionIds.length)}) '
      'AND EXISTS (SELECT 1 FROM evidence_rows e WHERE e.finding_id = f.id) '
      'GROUP BY session_id',
      sessionIds,
    );
    final processed = await _countPerSession(
      "SELECT session_id, COUNT(*) as c FROM finding_rows f "
      'WHERE f.session_id IN (${_placeholders(sessionIds.length)}) '
      "AND f.ai_status IN ('completed', 'needsReview', 'failed') "
      'AND EXISTS (SELECT 1 FROM evidence_rows e WHERE e.finding_id = f.id) '
      'GROUP BY session_id',
      sessionIds,
    );
    final pendingReview = await _countPerSession(
      'SELECT session_id, COUNT(*) as c FROM ai_suggestion_rows '
      'WHERE session_id IN (${_placeholders(sessionIds.length)}) '
      "AND status = 'pending' "
      'GROUP BY session_id',
      sessionIds,
    );
    final failed = await _countPerSession(
      "SELECT session_id, COUNT(*) as c FROM finding_rows f "
      'WHERE f.session_id IN (${_placeholders(sessionIds.length)}) '
      "AND f.ai_status = 'failed' "
      'GROUP BY session_id',
      sessionIds,
    );

    return rows
        .map(
          (row) => InspectionSessionSummary(
            id: row.id,
            industry: Industry.values.byName(row.industry),
            assetTypeId: row.assetTypeId,
            status: InspectionStatus.values.byName(row.status),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            syncStatus: SyncStatus.values.byName(row.syncStatus),
            ownerUid: row.ownerUid,
            aiEligibleFindingsCount: eligible[row.id] ?? 0,
            aiProcessedFindingsCount: processed[row.id] ?? 0,
            aiPendingReviewCount: pendingReview[row.id] ?? 0,
            aiFailedFindingsCount: failed[row.id] ?? 0,
            propertyTitle: row.propertyTitle,
            propertyAddress: row.propertyAddress,
            unitNumber: row.unitNumber,
          ),
        )
        .toList();
  }

  String _placeholders(int count) => List.filled(count, '?').join(', ');

  Future<Map<String, int>> _countPerSession(
    String sql,
    List<String> sessionIds,
  ) async {
    final rows = await _db
        .customSelect(
          sql,
          variables: [for (final id in sessionIds) Variable.withString(id)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('session_id'): row.read<int>('c'),
    };
  }

  @override
  Future<void> setSessionOwner(String sessionId, String ownerUid) async {
    // Only claims a session that has no owner yet — never reassigns a
    // session that already belongs to a (possibly different) user.
    await (_db.update(_db.inspectionSessionRows)
          ..where((t) => t.id.equals(sessionId) & t.ownerUid.isNull()))
        .write(InspectionSessionRowsCompanion(ownerUid: Value(ownerUid)));
  }

  @override
  Future<void> saveSections(String sessionId, List<Section> sections) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(
        _db.sectionRows,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      for (var i = 0; i < sections.length; i++) {
        await _insertSection(
          sessionId: sessionId,
          section: sections[i],
          orderIndex: i,
          timestamp: now,
        );
      }
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> saveSectionStatus(
    String sessionId,
    String sectionId,
    SectionStatus status,
  ) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.sectionRows)..where(
            (t) => t.sessionId.equals(sessionId) & t.id.equals(sectionId),
          ))
          .write(
            SectionRowsCompanion(
              status: Value(status.name),
              updatedAt: Value(now),
            ),
          );
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> saveFinding(String sessionId, Finding finding) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.findingRows)
          .insertOnConflictUpdate(
            FindingRowsCompanion.insert(
              id: finding.id,
              sessionId: sessionId,
              sectionId: finding.sectionId,
              elementId: _elementIdToRow(finding.elementId),
              componentId: Value(finding.componentId),
              description: Value(finding.description),
              notes: Value(finding.notes),
              status: Value(finding.status.name),
              aiStatus: Value(finding.aiStatus.name),
              createdAt: finding.createdAt,
              updatedAt: finding.updatedAt,
            ),
          );
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> setFindingAiStatus(
    String sessionId,
    String findingId,
    AiFindingStatus status,
  ) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.findingRows,
      )..where((t) => t.id.equals(findingId))).write(
        FindingRowsCompanion(
          aiStatus: Value(status.name),
          updatedAt: Value(now),
        ),
      );
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> deleteFinding(String sessionId, String findingId) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(
        _db.evidenceRows,
      )..where((t) => t.findingId.equals(findingId))).go();
      await (_db.delete(
        _db.findingRows,
      )..where((t) => t.id.equals(findingId))).go();
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await (_db.delete(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).go();
  }

  @override
  Future<void> addEvidence(String sessionId, Evidence evidence) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.evidenceRows)
          .insert(
            EvidenceRowsCompanion.insert(
              id: evidence.id,
              findingId: evidence.findingId,
              filePath: evidence.filePath,
              mediaType: Value(evidence.mediaType.name),
              source: Value(evidence.source.name),
              caption: Value(evidence.caption),
              syncStatus: Value(evidence.syncStatus.name),
              createdAt: evidence.createdAt,
              storagePath: Value(evidence.storagePath),
            ),
          );
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> removeEvidence(String sessionId, String evidenceId) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(
        _db.evidenceRows,
      )..where((t) => t.id.equals(evidenceId))).go();
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> updateEvidenceSyncState(
    String evidenceId, {
    required SyncStatus syncStatus,
    String? storagePath,
  }) async {
    await (_db.update(
      _db.evidenceRows,
    )..where((t) => t.id.equals(evidenceId))).write(
      EvidenceRowsCompanion(
        syncStatus: Value(syncStatus.name),
        storagePath: storagePath == null
            ? const Value.absent()
            : Value(storagePath),
      ),
    );
  }

  @override
  Future<void> setSessionStatus(
    String sessionId,
    InspectionStatus status,
  ) async {
    final now = DateTime.now();
    await (_db.update(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).write(
      InspectionSessionRowsCompanion(
        status: Value(status.name),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> setSessionSyncStatus(
    String sessionId,
    SyncStatus syncStatus,
  ) async {
    await (_db.update(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).write(
      InspectionSessionRowsCompanion(syncStatus: Value(syncStatus.name)),
    );
  }

  @override
  Future<void> setAiReviewState(String sessionId, AiReviewState state) async {
    await (_db.update(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).write(
      InspectionSessionRowsCompanion(aiReviewState: Value(state.name)),
    );
  }

  @override
  Future<void> saveAiSuggestion(AiSuggestion suggestion) async {
    await _db
        .into(_db.aiSuggestionRows)
        .insertOnConflictUpdate(
          AiSuggestionRowsCompanion.insert(
            id: suggestion.id,
            sessionId: suggestion.sessionId,
            findingId: suggestion.findingId,
            providerId: suggestion.providerId,
            generatedAt: suggestion.generatedAt,
            status: Value(suggestion.status.name),
            reviewedAt: Value(suggestion.reviewedAt),
            suggestedCatalogueEntryId: Value(
              suggestion.suggestedCatalogueEntryId,
            ),
            suggestedConfidence: Value(suggestion.suggestedConfidence),
            suggestedShortReason: Value(suggestion.suggestedShortReason),
            suggestedCandidateEntryIds: Value(
              _encodeCandidateIds(suggestion.suggestedCandidateEntryIds),
            ),
            finalCatalogueEntryId: Value(suggestion.finalCatalogueEntryId),
          ),
        );
  }

  @override
  Future<void> saveReport(Report report) async {
    await _db
        .into(_db.reportRows)
        .insertOnConflictUpdate(
          ReportRowsCompanion.insert(
            id: report.id,
            sessionId: report.sessionId,
            filePath: report.filePath,
            fileName: report.fileName,
            generatedAt: report.generatedAt,
            sourceUpdatedAt: report.sourceUpdatedAt,
            syncStatus: Value(report.syncStatus.name),
            version: Value(report.version),
          ),
        );
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    final row = await (_db.select(
      _db.userProfileRows,
    )..where((t) => t.id.equals(_localProfileId))).getSingleOrNull();
    if (row == null) return UserProfile.empty;
    return UserProfile(
      companyName: row.companyName,
      inspectorName: row.inspectorName,
    );
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _db
        .into(_db.userProfileRows)
        .insertOnConflictUpdate(
          UserProfileRowsCompanion.insert(
            id: _localProfileId,
            companyName: Value(profile.companyName),
            inspectorName: Value(profile.inspectorName),
            updatedAt: DateTime.now(),
          ),
        );
  }

  static const _localProfileId = 'local';

  Future<void> _touchSession(String sessionId, DateTime timestamp) {
    return (_db.update(_db.inspectionSessionRows)
          ..where((t) => t.id.equals(sessionId)))
        .write(InspectionSessionRowsCompanion(updatedAt: Value(timestamp)));
  }

  @override
  Future<void> close() => _db.close();
}
