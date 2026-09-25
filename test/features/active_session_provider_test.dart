import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/entities/ai_finding_status.dart';
import 'package:prodefact/core/inspection/entities/ai_review.dart';
import 'package:prodefact/core/inspection/entities/defect_catalogue.dart';
import 'package:prodefact/core/inspection/entities/evidence.dart';
import 'package:prodefact/core/inspection/entities/report_metadata.dart';
import 'package:prodefact/core/inspection/entities/section_status.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/session_list_providers.dart';

import '../support/test_repository.dart';

void main() {
  group('evidence', () {
    test(
      'evidence can be attached to a finding through the provider',
      () async {
        final container = ProviderContainer(overrides: testOverrides());
        addTearDown(container.dispose);
        await container
            .read(selectedPropertyTypeProvider.notifier)
            .select(PropertyType.highRise);

        final section = container.read(inspectionQueueProvider).first;
        final element = section.elements.first;
        final finding = container
            .read(inspectionFindingsProvider.notifier)
            .addFinding(sectionId: section.id, elementId: element.id);

        await container
            .read(activeSessionProvider.notifier)
            .addEvidence(findingId: finding.id, source: EvidenceSource.camera);

        final updated = container
            .read(inspectionFindingsProvider)
            .firstWhere((f) => f.id == finding.id);
        expect(updated.evidence, hasLength(1));
        expect(updated.evidence.single.source, EvidenceSource.camera);
        expect(updated.evidence.single.filePath, isNotEmpty);
      },
    );

    test('evidence can be removed through the provider', () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final finding = container
          .read(inspectionFindingsProvider.notifier)
          .addFinding(sectionId: section.id, elementId: element.id);
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.gallery,
      );
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.camera,
      );
      final photos = container
          .read(inspectionFindingsProvider)
          .firstWhere((f) => f.id == finding.id)
          .evidence;
      expect(photos, hasLength(2));

      // One photo of several: removed, finding and other photo kept.
      expect(
        notifier.removeEvidence(
          findingId: finding.id,
          evidenceId: photos.first.id,
        ),
        isTrue,
      );
      var updated = container
          .read(inspectionFindingsProvider)
          .firstWhere((f) => f.id == finding.id);
      expect(updated.evidence.single.id, photos.last.id);

      // The last photo stays: remove the finding instead (QA #20).
      expect(
        notifier.removeEvidence(
          findingId: finding.id,
          evidenceId: photos.last.id,
        ),
        isFalse,
      );
      updated = container
          .read(inspectionFindingsProvider)
          .firstWhere((f) => f.id == finding.id);
      expect(updated.evidence, hasLength(1));
    });

    test('cancelling the picker adds no evidence', () async {
      final container = ProviderContainer(
        overrides: testOverrides(
          captureService: FakeEvidenceCaptureService(cancelNextPick: true),
        ),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final finding = container
          .read(inspectionFindingsProvider.notifier)
          .addFinding(sectionId: section.id, elementId: element.id);

      await container
          .read(activeSessionProvider.notifier)
          .addEvidence(findingId: finding.id, source: EvidenceSource.camera);

      final updated = container
          .read(inspectionFindingsProvider)
          .firstWhere((f) => f.id == finding.id);
      expect(updated.evidence, isEmpty);
    });
  });

  group('manual classification (Classify Manually on a failed finding)', () {
    test('classifies a finding with no AI suggestion at all, marks it '
        'completed, and preserves the manual value as final', () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final section = container.read(inspectionQueueProvider).first;
      final photo = await container
          .read(activeSessionProvider.notifier)
          .captureFindingPhoto(source: EvidenceSource.camera);
      final finding = container
          .read(activeSessionProvider.notifier)
          .saveCameraFinding(sectionId: section.id, photo: photo!);

      // No AiSuggestion exists for this finding yet — the situation a
      // `failed` classification attempt (nothing to Change against)
      // leaves it in; "Classify Manually" must still work.
      expect(
        container
            .read(activeSessionProvider)!
            .aiSuggestions
            .where((s) => s.findingId == finding.id),
        isEmpty,
      );

      final entryId = DefectCatalogue.instance.entries.first.id;
      container
          .read(activeSessionProvider.notifier)
          .manuallyClassifyFinding(finding.id, entryId);

      final session = container.read(activeSessionProvider)!;
      final updatedFinding = session.findings.firstWhere(
        (f) => f.id == finding.id,
      );
      expect(updatedFinding.aiStatus, AiFindingStatus.completed);

      final suggestion = session.aiSuggestions.firstWhere(
        (s) => s.findingId == finding.id,
      );
      expect(suggestion.providerId, 'manual');
      expect(suggestion.status, AiSuggestionStatus.edited);
      expect(suggestion.suggestedCatalogueEntryId, isNull);
      expect(suggestion.finalCatalogueEntryId, entryId);
    });

    test('is a no-op if a suggestion already exists for the finding', () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final section = container.read(inspectionQueueProvider).first;
      final photo = await container
          .read(activeSessionProvider.notifier)
          .captureFindingPhoto(source: EvidenceSource.camera);
      final finding = container
          .read(activeSessionProvider.notifier)
          .saveCameraFinding(sectionId: section.id, photo: photo!);

      final entryId = DefectCatalogue.instance.entries.first.id;
      // First manual classification creates the suggestion.
      container
          .read(activeSessionProvider.notifier)
          .manuallyClassifyFinding(finding.id, entryId);
      final firstCount = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .where((s) => s.findingId == finding.id)
          .length;
      expect(firstCount, 1);

      // A second call for the same finding must not duplicate it.
      final otherEntryId = DefectCatalogue.instance.entries[1].id;
      container
          .read(activeSessionProvider.notifier)
          .manuallyClassifyFinding(finding.id, otherEntryId);
      final suggestions = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .where((s) => s.findingId == finding.id)
          .toList();
      expect(suggestions, hasLength(1));
      expect(suggestions.single.finalCatalogueEntryId, entryId);
    });
  });

  group('notes and report metadata', () {
    test('an area note can be set, edited, cleared, and survives a '
        'reload', () async {
      final repository = createInMemoryRepository();
      final container = ProviderContainer(
        overrides: testOverrides(repository: repository),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final sessionId = container.read(activeSessionProvider)!.id;
      final section = container.read(inspectionQueueProvider).first;

      container
          .read(activeSessionProvider.notifier)
          .setAreaNote(section.id, 'Ponding test started at 10:15 AM.');
      expect(
        container
            .read(activeSessionProvider)!
            .sections
            .firstWhere((s) => s.id == section.id)
            .note,
        'Ponding test started at 10:15 AM.',
      );

      // Survives a fresh repository read (durable, not just in-memory).
      final reloaded = await repository.loadSession(sessionId);
      expect(
        reloaded!.sections.firstWhere((s) => s.id == section.id).note,
        'Ponding test started at 10:15 AM.',
      );

      // Blank input clears it rather than storing an empty string.
      container
          .read(activeSessionProvider.notifier)
          .setAreaNote(section.id, '  ');
      expect(
        container
            .read(activeSessionProvider)!
            .sections
            .firstWhere((s) => s.id == section.id)
            .note,
        isNull,
      );
    });

    test('an inspection note can be set and survives a reload', () async {
      final repository = createInMemoryRepository();
      final container = ProviderContainer(
        overrides: testOverrides(repository: repository),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final sessionId = container.read(activeSessionProvider)!.id;

      container
          .read(activeSessionProvider.notifier)
          .setInspectionNote('Unit occupied during inspection.');
      expect(
        container.read(activeSessionProvider)!.inspectionNote,
        'Unit occupied during inspection.',
      );

      final reloaded = await repository.loadSession(sessionId);
      expect(reloaded!.inspectionNote, 'Unit occupied during inspection.');
    });

    test('confirmed report metadata is stored separately from property '
        'details and survives a reload', () async {
      final repository = createInMemoryRepository();
      final container = ProviderContainer(
        overrides: testOverrides(repository: repository),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final session = container.read(activeSessionProvider)!;
      // This session was created without going through Property
      // Details setup, so propertyDetails starts empty.
      expect(session.propertyDetails.isEmpty, isTrue);

      const metadata = ReportMetadata(
        title: 'Residensi Vista',
        clientName: 'Jane Client',
      );
      container
          .read(activeSessionProvider.notifier)
          .setReportMetadata(metadata);

      final updated = container.read(activeSessionProvider)!;
      expect(updated.reportMetadata?.title, 'Residensi Vista');
      // Confirming report metadata never touches the original
      // (still-empty) property details.
      expect(updated.propertyDetails.isEmpty, isTrue);

      final reloaded = await repository.loadSession(session.id);
      expect(reloaded!.reportMetadata?.title, 'Residensi Vista');
      expect(reloaded.reportMetadata?.clientName, 'Jane Client');
      expect(reloaded.propertyDetails.isEmpty, isTrue);
    });
  });

  group('resume', () {
    test('an unfinished inspection can be resumed with a fresh provider '
        'container, as if the app had restarted', () async {
      // Both containers share the same underlying (in-memory) database,
      // the same way two app launches would share the same on-device
      // database file.
      final repository = createInMemoryRepository();

      final firstRunContainer = ProviderContainer(
        overrides: [
          inspectionRepositoryProvider.overrideWithValue(repository),
          evidenceCaptureServiceProvider.overrideWithValue(
            FakeEvidenceCaptureService(),
          ),
        ],
      );
      await firstRunContainer
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final sessionId = firstRunContainer.read(activeSessionProvider)!.id;
      final section = firstRunContainer.read(inspectionQueueProvider).first;
      firstRunContainer
          .read(sectionStatusesProvider.notifier)
          .setStatus(section.id, SectionStatus.inProgress);
      firstRunContainer
          .read(inspectionFindingsProvider.notifier)
          .addFinding(
            sectionId: section.id,
            elementId: section.elements.first.id,
            description: 'Leaking pipe',
          );
      firstRunContainer.dispose();

      final secondRunContainer = ProviderContainer(
        overrides: [
          inspectionRepositoryProvider.overrideWithValue(repository),
          evidenceCaptureServiceProvider.overrideWithValue(
            FakeEvidenceCaptureService(),
          ),
        ],
      );
      addTearDown(secondRunContainer.dispose);

      // Before resuming, this fresh container has no active session.
      expect(secondRunContainer.read(activeSessionProvider), isNull);

      await secondRunContainer
          .read(activeSessionProvider.notifier)
          .resume(sessionId);

      final resumed = secondRunContainer.read(activeSessionProvider);
      expect(resumed, isNotNull);
      expect(resumed!.id, sessionId);
      expect(
        secondRunContainer.read(sectionStatusesProvider)[section.id],
        SectionStatus.inProgress,
      );
      expect(
        secondRunContainer
            .read(inspectionFindingsProvider)
            .map((f) => f.description),
        contains('Leaking pipe'),
      );
    });

    test(
      'listSessions distinguishes the resumed session as unfinished',
      () async {
        final repository = createInMemoryRepository();
        final container = ProviderContainer(
          overrides: [
            inspectionRepositoryProvider.overrideWithValue(repository),
            evidenceCaptureServiceProvider.overrideWithValue(
              FakeEvidenceCaptureService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(selectedPropertyTypeProvider.notifier)
            .select(PropertyType.highRise);

        final summaries = await container.read(sessionSummariesProvider.future);
        expect(summaries, hasLength(1));
        expect(summaries.single.isComplete, isFalse);
      },
    );
  });
}
