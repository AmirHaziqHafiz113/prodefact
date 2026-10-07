import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

/// Persistence-safety bug fix (2026-10-07): once a session reached
/// `synced`, no further local mutation ever demoted it back to
/// `pendingUpdate` — `_touchSession` only bumped `updatedAt`, and 7 of
/// 17 session-scoped write methods (`saveAiSuggestion` chief among
/// them) never called it at all. The sync-status badge could claim
/// "Synced" indefinitely while real local changes — a new AI result, a
/// manual correction, a reanalysis, a report note — sat un-pushed. Every
/// one of those mutations must now demote a `synced` session back to
/// `pendingUpdate`; a session not yet synced at all must stay exactly
/// as it was (never "promoted" by a mutation).
void main() {
  late DriftInspectionRepository repository;

  Section section() => const Section(
    id: 'bathroom',
    name: 'Bathroom',
    isPlumbing: true,
    elements: [],
  );

  Future<String> syncedSession() async {
    final session = await repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [section()],
    );
    await repository.setSessionSyncStatus(session.id, SyncStatus.synced);
    final reloaded = await repository.loadSession(session.id);
    expect(reloaded!.syncStatus, SyncStatus.synced, reason: 'test setup');
    return session.id;
  }

  Future<SyncStatus> statusOf(String sessionId) async {
    final session = await repository.loadSession(sessionId);
    return session!.syncStatus;
  }

  setUp(() {
    repository = DriftInspectionRepository(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() => repository.close());

  group('a synced session is demoted to pendingUpdate by', () {
    test('saveFinding (a new finding)', () async {
      final sessionId = await syncedSession();
      final now = DateTime.now();
      await repository.saveFinding(
        sessionId,
        Finding(
          id: 'f1',
          sectionId: 'bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('addEvidence', () async {
      final sessionId = await syncedSession();
      final now = DateTime.now();
      await repository.saveFinding(
        sessionId,
        Finding(
          id: 'f1',
          sectionId: 'bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.setSessionSyncStatus(sessionId, SyncStatus.synced);
      await repository.addEvidence(
        sessionId,
        Evidence(id: 'e1', findingId: 'f1', filePath: '/x.jpg', createdAt: now),
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('saveAiSuggestion — the headline gap: every AI result, Accept/'
        'Change/Reject, Reanalyse and manual classification previously '
        'left a synced session looking synced forever', () async {
      final sessionId = await syncedSession();
      final now = DateTime.now();
      await repository.saveAiSuggestion(
        AiSuggestion(
          id: 's1',
          sessionId: sessionId,
          findingId: 'f1',
          providerId: 'ai',
          generatedAt: now,
        ),
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('setFindingAiStatus', () async {
      final sessionId = await syncedSession();
      final now = DateTime.now();
      await repository.saveFinding(
        sessionId,
        Finding(
          id: 'f1',
          sectionId: 'bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.setSessionSyncStatus(sessionId, SyncStatus.synced);
      await repository.setFindingAiStatus(
        sessionId,
        'f1',
        AiFindingStatus.queued,
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('deleteFinding', () async {
      final sessionId = await syncedSession();
      final now = DateTime.now();
      await repository.saveFinding(
        sessionId,
        Finding(
          id: 'f1',
          sectionId: 'bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.setSessionSyncStatus(sessionId, SyncStatus.synced);
      await repository.deleteFinding(sessionId, 'f1');
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('setSessionStatus', () async {
      final sessionId = await syncedSession();
      await repository.setSessionStatus(
        sessionId,
        InspectionStatus.physicalInspectionComplete,
      );
      final reloaded = await repository.loadSession(sessionId);
      expect(reloaded!.status, InspectionStatus.physicalInspectionComplete);
      expect(reloaded.syncStatus, SyncStatus.pendingUpdate);
    });

    test('setAiReviewState', () async {
      final sessionId = await syncedSession();
      await repository.setAiReviewState(sessionId, AiReviewState.completed);
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('saveReportMetadata', () async {
      final sessionId = await syncedSession();
      await repository.saveReportMetadata(
        sessionId,
        const ReportMetadata(title: 'Unit A-1', contactNumber: '0123456789'),
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('saveInspectionNote', () async {
      final sessionId = await syncedSession();
      await repository.saveInspectionNote(sessionId, 'Unit occupied');
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('setCommercialMode', () async {
      final sessionId = await syncedSession();
      await repository.setCommercialMode(sessionId, CommercialMode.housePass);
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('saveReport (generating/regenerating the PDF)', () async {
      final sessionId = await syncedSession();
      await repository.saveReport(
        Report(
          id: 'r1',
          sessionId: sessionId,
          filePath: '/report.pdf',
          fileName: 'report.pdf',
          generatedAt: DateTime.now(),
          sourceUpdatedAt: DateTime.now(),
        ),
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });

    test('saveSectionStatus', () async {
      final sessionId = await syncedSession();
      await repository.saveSectionStatus(
        sessionId,
        'bathroom',
        SectionStatus.completed,
      );
      expect(await statusOf(sessionId), SyncStatus.pendingUpdate);
    });
  });

  group('a NOT-yet-synced session is never promoted by a local write', () {
    for (final status in [
      SyncStatus.localOnly,
      SyncStatus.pendingCreate,
      SyncStatus.pendingDelete,
    ]) {
      test('stays $status after saveFinding', () async {
        final session = await repository.createSession(
          industry: Industry.homeInspection,
          assetTypeId: 'highRise',
          initialSections: [section()],
        );
        await repository.setSessionSyncStatus(session.id, status);
        final now = DateTime.now();
        await repository.saveFinding(
          session.id,
          Finding(
            id: 'f1',
            sectionId: 'bathroom',
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(await statusOf(session.id), status);
      });
    }

    test('pendingUpdate stays pendingUpdate (idempotent demotion)', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [section()],
      );
      await repository.setSessionSyncStatus(
        session.id,
        SyncStatus.pendingUpdate,
      );
      final now = DateTime.now();
      await repository.saveFinding(
        session.id,
        Finding(
          id: 'f1',
          sectionId: 'bathroom',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await statusOf(session.id), SyncStatus.pendingUpdate);
    });
  });

  test(
    'updatedAt still advances on every touch (unchanged behaviour)',
    () async {
      final sessionId = await syncedSession();
      final before = (await repository.loadSession(sessionId))!.updatedAt;
      // Drift's default DateTime storage is whole seconds, not
      // milliseconds — cross a full second so the difference shows up
      // regardless of that rounding.
      await Future<void>.delayed(
        const Duration(seconds: 1, milliseconds: 100),
      );
      await repository.saveInspectionNote(sessionId, 'A note');
      final after = (await repository.loadSession(sessionId))!.updatedAt;
      expect(after.isAfter(before), isTrue);
    },
  );
}
