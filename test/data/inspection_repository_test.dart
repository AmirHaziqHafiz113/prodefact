import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:path/path.dart' as p;

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

Section _kitchenSection() {
  return const Section(
    id: 'kitchen',
    name: 'Kitchen',
    isPlumbing: true,
    elements: [
      InspectionElement(
        id: 'wall',
        name: 'Wall',
        components: [Component(id: 'wall_tile', name: 'Wall tile')],
      ),
    ],
  );
}

void main() {
  late DriftInspectionRepository repository;

  setUp(() {
    repository = DriftInspectionRepository(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() => repository.close());

  group('createSession', () {
    test('creates a session locally with the given sections', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection(), _kitchenSection()],
      );

      expect(session.id, isNotEmpty);
      expect(session.assetTypeId, 'highRise');
      expect(session.sections.map((s) => s.name), [
        'Master Bathroom',
        'Kitchen',
      ]);
      expect(session.status, InspectionStatus.inProgress);
    });

    test('the session id remains stable across a reload', () async {
      final created = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );

      final reloaded = await repository.loadSession(created.id);

      expect(reloaded, isNotNull);
      expect(reloaded!.id, created.id);
    });
  });

  group('sections', () {
    test('configured area changes persist (include/exclude, rename)', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection(), _kitchenSection()],
      );

      final updatedSections = [
        _bathroomSection().copyWith(isIncluded: false),
        _kitchenSection().copyWith(name: 'Main Kitchen'),
      ];
      await repository.saveSections(session.id, updatedSections);

      final reloaded = await repository.loadSession(session.id);
      final bathroom = reloaded!.sections.firstWhere(
        (s) => s.id == 'master_bathroom',
      );
      final kitchen = reloaded.sections.firstWhere((s) => s.id == 'kitchen');

      expect(bathroom.isIncluded, isFalse);
      expect(kitchen.name, 'Main Kitchen');
      // Elements/components round-trip through the JSON template too.
      expect(bathroom.elements.single.components.single.name, 'Floor tile');
    });

    test('section status persists', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );

      await repository.saveSectionStatus(
        session.id,
        'master_bathroom',
        SectionStatus.completed,
      );

      final reloaded = await repository.loadSession(session.id);
      expect(
        reloaded!.sectionStatuses['master_bathroom'],
        SectionStatus.completed,
      );
    });
  });

  group('findings', () {
    test('findings persist', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      final now = DateTime.now();
      final finding = Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        componentId: 'floor_tile',
        description: 'Cracked tile',
        notes: 'Near the drain',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveFinding(session.id, finding);

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.findings, hasLength(1));
      final saved = reloaded.findings.single;
      expect(saved.sectionId, 'master_bathroom');
      expect(saved.elementId, 'floor');
      expect(saved.componentId, 'floor_tile');
      expect(saved.description, 'Cracked tile');
      expect(saved.notes, 'Near the drain');
    });

    test('finding edits persist', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      final now = DateTime.now();
      final finding = Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        description: 'Original',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveFinding(session.id, finding);

      await repository.saveFinding(
        session.id,
        finding.copyWith(description: 'Edited', updatedAt: DateTime.now()),
      );

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.findings, hasLength(1));
      expect(reloaded.findings.single.description, 'Edited');
    });

    test('finding deletion persists', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      final now = DateTime.now();
      final finding = Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveFinding(session.id, finding);

      await repository.deleteFinding(session.id, finding.id);

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.findings, isEmpty);
    });
  });

  group('evidence', () {
    late InspectionSession session;
    late Finding finding;

    setUp(() async {
      session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      final now = DateTime.now();
      finding = Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveFinding(session.id, finding);
    });

    test('evidence can be attached to a finding, with full metadata', () async {
      final now = DateTime.now();
      final evidence = Evidence(
        id: 'evidence_1',
        findingId: finding.id,
        filePath: '/fake/evidence/finding_1/1.jpg',
        createdAt: now,
        source: EvidenceSource.camera,
        caption: 'Close-up of the crack',
      );

      await repository.addEvidence(session.id, evidence);

      final reloaded = await repository.loadSession(session.id);
      final savedFinding = reloaded!.findings.single;
      expect(savedFinding.evidence, hasLength(1));
      final savedEvidence = savedFinding.evidence.single;
      expect(savedEvidence.id, 'evidence_1');
      expect(savedEvidence.findingId, finding.id);
      expect(savedEvidence.filePath, '/fake/evidence/finding_1/1.jpg');
      expect(savedEvidence.source, EvidenceSource.camera);
      expect(savedEvidence.mediaType, EvidenceMediaType.photo);
      expect(savedEvidence.caption, 'Close-up of the crack');
      expect(savedEvidence.syncStatus, SyncStatus.localOnly);
    });

    test('evidence can be removed', () async {
      final evidence = Evidence(
        id: 'evidence_1',
        findingId: finding.id,
        filePath: '/fake/evidence/finding_1/1.jpg',
        createdAt: DateTime.now(),
      );
      await repository.addEvidence(session.id, evidence);

      await repository.removeEvidence(session.id, evidence.id);

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.findings.single.evidence, isEmpty);
    });

    test('deleting a finding also removes its evidence', () async {
      final evidence = Evidence(
        id: 'evidence_1',
        findingId: finding.id,
        filePath: '/fake/evidence/finding_1/1.jpg',
        createdAt: DateTime.now(),
      );
      await repository.addEvidence(session.id, evidence);

      await repository.deleteFinding(session.id, finding.id);

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.findings, isEmpty);
    });
  });

  group('session lifecycle', () {
    test('inspection completion state persists', () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );

      await repository.setSessionStatus(
        session.id,
        InspectionStatus.physicalInspectionComplete,
      );

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.status, InspectionStatus.physicalInspectionComplete);
    });

    test(
      'unfinished vs completed sessions can be identified in the list',
      () async {
        final unfinished = await repository.createSession(
          industry: Industry.homeInspection,
          assetTypeId: 'highRise',
          initialSections: [_bathroomSection()],
        );
        final completed = await repository.createSession(
          industry: Industry.homeInspection,
          assetTypeId: 'landed',
          initialSections: [_kitchenSection()],
        );
        await repository.setSessionStatus(
          completed.id,
          InspectionStatus.physicalInspectionComplete,
        );

        final summaries = await repository.listSessions();
        final unfinishedSummary = summaries.firstWhere(
          (s) => s.id == unfinished.id,
        );
        final completedSummary = summaries.firstWhere(
          (s) => s.id == completed.id,
        );

        expect(unfinishedSummary.isComplete, isFalse);
        expect(completedSummary.isComplete, isTrue);
      },
    );
  });

  group(
    'reload across a fresh repository instance (simulated app restart)',
    () {
      test(
        'reopening the database file restores the same inspection state',
        () async {
          // Two AppDatabase instances briefly point at the same file here
          // by design (to simulate a restart) — silence Drift's
          // multi-instance heuristic for this single test.
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
          addTearDown(
            () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'prodefact_repo_test',
          );
          final dbFile = File(p.join(tempDir.path, 'test.sqlite'));
          addTearDown(() => tempDir.delete(recursive: true));

          final firstRepository = DriftInspectionRepository(
            AppDatabase(NativeDatabase(dbFile)),
          );
          final session = await firstRepository.createSession(
            industry: Industry.homeInspection,
            assetTypeId: 'highRise',
            initialSections: [_bathroomSection()],
          );
          final now = DateTime.now();
          await firstRepository.saveFinding(
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
          await firstRepository.saveSectionStatus(
            session.id,
            'master_bathroom',
            SectionStatus.inProgress,
          );
          await firstRepository.close();

          // Simulate an app restart: a brand new repository instance opens
          // the same underlying database file from scratch.
          final secondRepository = DriftInspectionRepository(
            AppDatabase(NativeDatabase(dbFile)),
          );
          addTearDown(secondRepository.close);

          final reloaded = await secondRepository.loadSession(session.id);

          expect(reloaded, isNotNull);
          expect(reloaded!.id, session.id);
          expect(reloaded.sections.single.name, 'Master Bathroom');
          expect(
            reloaded.sectionStatuses['master_bathroom'],
            SectionStatus.inProgress,
          );
          expect(reloaded.findings.single.description, 'Cracked tile');
        },
      );
    },
  );
}
