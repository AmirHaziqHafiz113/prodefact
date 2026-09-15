import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/sync/default_sync_coordinator.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/test_repository.dart';

Section _bathroomSection() {
  return const Section(
    id: 'master_bathroom',
    name: 'Master Bathroom',
    isPlumbing: true,
    elements: [
      InspectionElement(
        id: 'floor',
        name: 'Floor',
        components: [Component(id: 'floor_tile', name: 'Floor tile')],
      ),
    ],
  );
}

void main() {
  late FakeAuthService auth;
  late FakeCloudInspectionRepository cloud;
  late DriftInspectionRepository local;
  late DefaultSyncCoordinator coordinator;

  setUp(() {
    auth = FakeAuthService(initialUser: testAuthUser);
    cloud = FakeCloudInspectionRepository();
    local = createInMemoryRepository();
    coordinator = DefaultSyncCoordinator(
      localRepository: local,
      cloudRepository: cloud,
      authService: auth,
    );
  });

  tearDown(() {
    auth.dispose();
    local.close();
  });

  test('unauthenticated user cannot run protected sync', () async {
    await auth.signOut();
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );

    final result = await coordinator.syncSession(session.id);

    expect(result.outcome, SyncOutcome.unauthenticated);
    expect(cloud.pushSessionCalls, 0);
    expect(cloud.pushSectionsCalls, 0);
    expect(cloud.pushFindingCalls, 0);
  });

  test('a new session syncs, with stable ids preserved', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );

    final result = await coordinator.syncSession(session.id);

    expect(result.isSuccess, isTrue);
    expect(cloud.pushedSessions.containsKey(session.id), isTrue);
    expect(cloud.pushedSessions[session.id]!.id, session.id);
  });

  test('sections sync, matching local configuration', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );

    await coordinator.syncSession(session.id);

    final pushed = cloud.pushedSections[session.id];
    expect(pushed, isNotNull);
    expect(pushed!.single.id, 'master_bathroom');
    expect(pushed.single.isPlumbing, isTrue);
  });

  test('findings sync, matching local data and references', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final now = DateTime.now();
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        componentId: 'floor_tile',
        description: 'Cracked tile',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await coordinator.syncSession(session.id);

    final pushed = cloud.pushedFindings['finding_1'];
    expect(pushed, isNotNull);
    expect(pushed!.sectionId, 'master_bathroom');
    expect(pushed.elementId, 'floor');
    expect(pushed.componentId, 'floor_tile');
    expect(pushed.description, 'Cracked tile');
  });

  test('evidence metadata and files sync via the upload abstraction', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final now = DateTime.now();
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await local.addEvidence(
      session.id,
      Evidence(
        id: 'evidence_1',
        findingId: 'finding_1',
        filePath: '/fake/local/evidence_1.jpg',
        createdAt: now,
      ),
    );

    final result = await coordinator.syncSession(session.id);

    expect(result.isSuccess, isTrue);
    expect(cloud.uploadEvidenceCalls, 1);
    expect(cloud.uploadedFiles.containsKey('evidence_1'), isTrue);
    final pushedMetadata = cloud.pushedEvidenceMetadata['evidence_1'];
    expect(pushedMetadata, isNotNull);
    expect(pushedMetadata!.storagePath, cloud.uploadedFiles['evidence_1']);
    expect(pushedMetadata.syncStatus, SyncStatus.synced);

    // The local record is updated too — evidence sync state and the
    // *local* file path (never overwritten/deleted) both hold.
    final reloaded = await local.loadSession(session.id);
    final localEvidence = reloaded!.findings.single.evidence.single;
    expect(localEvidence.syncStatus, SyncStatus.synced);
    expect(localEvidence.storagePath, cloud.uploadedFiles['evidence_1']);
    expect(localEvidence.filePath, '/fake/local/evidence_1.jpg');
  });

  test('successful sync marks the local session as synced', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );

    await coordinator.syncSession(session.id);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.syncStatus, SyncStatus.synced);
    expect(reloaded.ownerUid, testAuthUser.uid);
  });

  test('failed sync preserves local data and marks it pending', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final now = DateTime.now();
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        description: 'Cracked tile',
        createdAt: now,
        updatedAt: now,
      ),
    );

    cloud.failNextCallWith = Exception('simulated network failure');
    final result = await coordinator.syncSession(session.id);

    expect(result.outcome, SyncOutcome.failure);
    expect(result.message, contains('simulated network failure'));

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.syncStatus, SyncStatus.pendingUpdate);
    // Local data itself is completely untouched by the failure.
    expect(reloaded.findings, hasLength(1));
    expect(reloaded.findings.single.description, 'Cracked tile');
  });

  test('a failed sync can be retried and then succeeds', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );

    cloud.failNextCallWith = Exception('temporary outage');
    final firstAttempt = await coordinator.syncSession(session.id);
    expect(firstAttempt.isSuccess, isFalse);

    final secondAttempt = await coordinator.syncSession(session.id);
    expect(secondAttempt.isSuccess, isTrue);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.syncStatus, SyncStatus.synced);
  });

  test('repeated sync does not create duplicate logical records', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final now = DateTime.now();
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await coordinator.syncSession(session.id);
    await coordinator.syncSession(session.id);
    await coordinator.syncSession(session.id);

    // Called three times, but keyed maps mean at most one logical
    // record per id — no duplication.
    expect(cloud.pushSessionCalls, 3);
    expect(cloud.pushedSessions, hasLength(1));
    expect(cloud.pushedFindings, hasLength(1));
  });

  test('a session already owned by a different user is never synced', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
      ownerUid: 'someone-else',
    );

    final result = await coordinator.syncSession(session.id);

    expect(result.outcome, SyncOutcome.unauthenticated);
    expect(cloud.pushSessionCalls, 0);
  });

  test('a missing session id reports sessionNotFound', () async {
    final result = await coordinator.syncSession('does-not-exist');
    expect(result.outcome, SyncOutcome.sessionNotFound);
  });
}
