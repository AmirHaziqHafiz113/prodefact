import 'package:drift/drift.dart';

import '../../core/inspection/inspection_domain.dart';
import 'database.dart';
import 'element_serialization.dart';

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
        elementId: row.elementId,
        componentId: row.componentId,
        description: row.description,
        notes: row.notes,
        status: FindingStatus.values.byName(row.status),
        evidence: evidence,
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
            suggestedElementId: row.suggestedElementId,
            suggestedComponentId: row.suggestedComponentId,
            suggestedDefectType: row.suggestedDefectType,
            suggestedRecommendation: row.suggestedRecommendation,
            suggestedNotes: row.suggestedNotes,
            finalElementId: row.finalElementId,
            finalComponentId: row.finalComponentId,
            finalDefectType: row.finalDefectType,
            finalRecommendation: row.finalRecommendation,
            finalNotes: row.finalNotes,
            status: AiSuggestionStatus.values.byName(row.status),
            reviewedAt: row.reviewedAt,
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
          ),
        )
        .toList();
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
              elementId: finding.elementId,
              componentId: Value(finding.componentId),
              description: Value(finding.description),
              notes: Value(finding.notes),
              status: Value(finding.status.name),
              createdAt: finding.createdAt,
              updatedAt: finding.updatedAt,
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
            suggestedElementId: Value(suggestion.suggestedElementId),
            suggestedComponentId: Value(suggestion.suggestedComponentId),
            suggestedDefectType: Value(suggestion.suggestedDefectType),
            suggestedRecommendation: Value(suggestion.suggestedRecommendation),
            suggestedNotes: Value(suggestion.suggestedNotes),
            finalElementId: Value(suggestion.finalElementId),
            finalComponentId: Value(suggestion.finalComponentId),
            finalDefectType: Value(suggestion.finalDefectType),
            finalRecommendation: Value(suggestion.finalRecommendation),
            finalNotes: Value(suggestion.finalNotes),
            status: Value(suggestion.status.name),
            reviewedAt: Value(suggestion.reviewedAt),
          ),
        );
  }

  Future<void> _touchSession(String sessionId, DateTime timestamp) {
    return (_db.update(_db.inspectionSessionRows)
          ..where((t) => t.id.equals(sessionId)))
        .write(InspectionSessionRowsCompanion(updatedAt: Value(timestamp)));
  }

  @override
  Future<void> close() => _db.close();
}
