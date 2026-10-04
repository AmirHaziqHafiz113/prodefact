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
    CommercialMode? commercialMode,
    AiLevel? selectedAiLevel,
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
              projectDeveloperName: Value(
                propertyDetails.projectDeveloperName,
              ),
              blockTower: Value(propertyDetails.blockTower),
              unitNumber: Value(propertyDetails.unitNumber),
              clientName: Value(propertyDetails.clientName),
              inspectorName: Value(propertyDetails.inspectorName),
              contactNumber: Value(propertyDetails.contactNumber),
              inspectionDate: Value(propertyDetails.inspectionDate),
              commercialMode: Value(commercialMode?.name),
              selectedAiLevel: Value(selectedAiLevel?.name),
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
      commercialMode: commercialMode,
      selectedAiLevel: selectedAiLevel,
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
            note: Value(section.note),
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
            note: row.note,
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
              annotatedFilePath: e.annotatedFilePath,
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
        aiAttempt: _aiAttemptFromRow(row),
        captureBatchId: row.captureBatchId,
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
            suggestedDefectTerm: row.suggestedDefectTerm,
            isRelevantInspectionImage: row.imageRelevant,
            imageUsable: row.imageUsable,
            qualityIssues: _decodeQualityIssues(row.imageQualityIssues),
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
      reportMetadata: _reportMetadataFromJson(sessionRow.reportMetadataJson),
      inspectionNote: sessionRow.inspectionNote,
      commercialMode: _commercialModeFromRow(sessionRow.commercialMode),
      selectedAiLevel: _aiLevelFromRow(sessionRow.selectedAiLevel),
    );
  }

  CommercialMode? _commercialModeFromRow(String? raw) =>
      raw == null ? null : CommercialMode.values.byName(raw);

  AiLevel? _aiLevelFromRow(String? raw) =>
      raw == null ? null : AiLevel.values.byName(raw);

  ReportMetadata? _reportMetadataFromJson(String? json) {
    if (json == null) return null;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.parse(value);
    return ReportMetadata(
      title: decoded['title'] as String,
      // `projectDeveloperName` is the field written going forward; a
      // blob saved before the QA/QC merge only has the legacy
      // `projectName` key (`developerName` was never part of this
      // JSON), so that's the fallback — never silently dropped.
      projectDeveloperName:
          decoded['projectDeveloperName'] as String? ??
          decoded['projectName'] as String?,
      address: decoded['address'] as String?,
      blockTower: decoded['blockTower'] as String?,
      unitNumber: decoded['unitNumber'] as String?,
      clientName: decoded['clientName'] as String?,
      inspectorName: decoded['inspectorName'] as String?,
      contactNumber: decoded['contactNumber'] as String?,
      inspectionDate: parseDate(decoded['inspectionDate'] as String?),
      reportDate: parseDate(decoded['reportDate'] as String?),
    );
  }

  String _reportMetadataToJson(ReportMetadata metadata) {
    return jsonEncode({
      'title': metadata.title,
      'projectDeveloperName': metadata.projectDeveloperName,
      'address': metadata.address,
      'blockTower': metadata.blockTower,
      'unitNumber': metadata.unitNumber,
      'clientName': metadata.clientName,
      'inspectorName': metadata.inspectorName,
      'contactNumber': metadata.contactNumber,
      'inspectionDate': metadata.inspectionDate?.toIso8601String(),
      'reportDate': metadata.reportDate?.toIso8601String(),
    });
  }

  PropertyDetails _propertyDetailsFromRow(InspectionSessionRow row) {
    // Every field is optional (only `unitNumber` is required to start
    // an inspection — see the QA/QC simplification pass), so presence
    // is no longer decided by `propertyTitle` alone: a row with a blank
    // title but a real unit number (or any other field) is genuine,
    // captured data and must never be discarded as if setup never
    // happened — see `PropertyDetails.isEmpty`.
    final details = PropertyDetails(
      title: row.propertyTitle ?? '',
      address: row.propertyAddress,
      projectDeveloperName: row.projectDeveloperName,
      // ignore: deprecated_member_use_from_same_package
      projectName: row.projectName,
      blockTower: row.blockTower,
      unitNumber: row.unitNumber,
      clientName: row.clientName,
      inspectorName: row.inspectorName,
      // ignore: deprecated_member_use_from_same_package
      developerName: row.developerName,
      contactNumber: row.contactNumber,
      inspectionDate: row.inspectionDate,
    );
    return details.isEmpty ? PropertyDetails.empty : details;
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
    final pendingSync = await _countPerSession(
      'SELECT f.session_id as session_id, COUNT(*) as c '
      'FROM evidence_rows e '
      'JOIN finding_rows f ON f.id = e.finding_id '
      'WHERE f.session_id IN (${_placeholders(sessionIds.length)}) '
      "AND e.sync_status != 'synced' "
      'GROUP BY f.session_id',
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
            pendingSyncCount: pendingSync[row.id] ?? 0,
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
              captureBatchId: Value(finding.captureBatchId),
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
  Future<void> beginFindingAiAttempt(
    String sessionId,
    String findingId,
    AiAnalysisAttempt attempt,
  ) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.findingRows,
      )..where((t) => t.id.equals(findingId))).write(
        FindingRowsCompanion(
          aiStatus: Value(AiFindingStatus.analyzing.name),
          aiAttemptKey: Value(attempt.idempotencyKey),
          aiAttemptLevel: Value(attempt.aiLevel.name),
          aiAttemptSubmittedAt: Value(attempt.submittedAt),
          updatedAt: Value(now),
        ),
      );
      await _touchSession(sessionId, now);
    });
  }

  @override
  Future<void> finishFindingAiAttempt(
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
          aiAttemptKey: const Value(null),
          aiAttemptLevel: const Value(null),
          aiAttemptSubmittedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _touchSession(sessionId, now);
    });
  }

  /// Null unless a complete attempt was persisted. An unrecognised level
  /// name (a future level read by an older build) still keeps the key,
  /// falling back to Smart: the key is what protects billing, and the
  /// backend returns a stored outcome for it regardless of level.
  static AiAnalysisAttempt? _aiAttemptFromRow(FindingRow row) {
    final key = row.aiAttemptKey;
    final submittedAt = row.aiAttemptSubmittedAt;
    if (key == null || key.isEmpty || submittedAt == null) return null;
    return AiAnalysisAttempt(
      idempotencyKey: key,
      aiLevel: AiLevel.values.asNameMap()[row.aiAttemptLevel] ?? AiLevel.smart,
      submittedAt: submittedAt,
    );
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
              annotatedFilePath: Value(evidence.annotatedFilePath),
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
  Future<void> saveAreaCandidate(AreaCandidate candidate) async {
    await _db
        .into(_db.areaCandidateRows)
        .insertOnConflictUpdate(
          AreaCandidateRowsCompanion.insert(
            id: candidate.id,
            rawName: candidate.rawName,
            normalizedName: candidate.normalizedName,
            propertyType: candidate.propertyType,
            createdAt: candidate.createdAt,
            submitted: Value(candidate.submitted),
          ),
        );
  }

  @override
  Future<List<AreaCandidate>> pendingAreaCandidates() async {
    final rows =
        await (_db.select(_db.areaCandidateRows)
              ..where((t) => t.submitted.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return [
      for (final row in rows)
        AreaCandidate(
          id: row.id,
          rawName: row.rawName,
          normalizedName: row.normalizedName,
          propertyType: row.propertyType,
          createdAt: row.createdAt,
          submitted: row.submitted,
        ),
    ];
  }

  @override
  Future<void> markAreaCandidateSubmitted(String candidateId) async {
    await (_db.update(_db.areaCandidateRows)
          ..where((t) => t.id.equals(candidateId)))
        .write(const AreaCandidateRowsCompanion(submitted: Value(true)));
  }

  @override
  Future<void> setEvidenceAnnotation(
    String sessionId,
    String evidenceId,
    String? annotatedFilePath,
  ) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.evidenceRows,
      )..where((t) => t.id.equals(evidenceId))).write(
        EvidenceRowsCompanion(
          annotatedFilePath: Value(annotatedFilePath),
          syncStatus: Value(SyncStatus.pendingUpdate.name),
        ),
      );
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
            suggestedDefectTerm: Value(suggestion.suggestedDefectTerm),
            imageRelevant: Value(suggestion.isRelevantInspectionImage),
            imageUsable: Value(suggestion.imageUsable),
            imageQualityIssues: Value(
              suggestion.qualityIssues.isEmpty
                  ? null
                  : suggestion.qualityIssues.join(','),
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
      defaultAiLevel: _aiLevelFromRow(row.defaultAiLevel),
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
            defaultAiLevel: Value(profile.defaultAiLevel?.name),
            updatedAt: DateTime.now(),
          ),
        );
  }

  static const _localProfileId = 'local';

  @override
  Future<void> saveReportMetadata(
    String sessionId,
    ReportMetadata metadata,
  ) async {
    await (_db.update(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).write(
      InspectionSessionRowsCompanion(
        reportMetadataJson: Value(_reportMetadataToJson(metadata)),
      ),
    );
  }

  @override
  Future<void> saveInspectionNote(String sessionId, String? note) async {
    await (_db.update(_db.inspectionSessionRows)
          ..where((t) => t.id.equals(sessionId)))
        .write(InspectionSessionRowsCompanion(inspectionNote: Value(note)));
  }

  @override
  Future<void> setCommercialMode(String sessionId, CommercialMode mode) async {
    await (_db.update(
      _db.inspectionSessionRows,
    )..where((t) => t.id.equals(sessionId))).write(
      InspectionSessionRowsCompanion(commercialMode: Value(mode.name)),
    );
  }

  @override
  Future<WalletCache?> loadWalletCache() async {
    final row = await (_db.select(
      _db.walletCacheRows,
    )..where((t) => t.id.equals(_localWalletCacheId))).getSingleOrNull();
    if (row == null) return null;
    return WalletCache(
      balanceCredits: row.balanceCredits,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> saveWalletCache(WalletCache cache) async {
    await _db
        .into(_db.walletCacheRows)
        .insertOnConflictUpdate(
          WalletCacheRowsCompanion.insert(
            id: _localWalletCacheId,
            balanceCredits: cache.balanceCredits,
            updatedAt: cache.updatedAt,
          ),
        );
  }

  static const _localWalletCacheId = 'local';

  Future<void> _touchSession(String sessionId, DateTime timestamp) {
    return (_db.update(_db.inspectionSessionRows)
          ..where((t) => t.id.equals(sessionId)))
        .write(InspectionSessionRowsCompanion(updatedAt: Value(timestamp)));
  }

  @override
  Future<void> close() => _db.close();

  static List<String> _decodeQualityIssues(String? raw) =>
      raw == null || raw.isEmpty ? const [] : raw.split(',');
}
