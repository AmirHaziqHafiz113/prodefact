import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';
import '../support/uncertain_ai_billing_service.dart';

/// Lets any fire-and-forget AI classification queued by
/// `saveCameraFinding` actually run before assertions.
Future<void> _pumpAiQueue() => Future<void>.delayed(Duration.zero);

// Every test below enables Auto Analyse right after starting the
// inspection (`notifier.setAutoAnalyseEnabled(true)`) so `saveCameraFinding`
// queues AI immediately, exactly like this suite's pre-commercial-pass
// behavior — this file is about AI *review* (accept/change/reject), not
// the separate estimate/approval gate, which has its own dedicated
// coverage in `ai_gating_regression_test.dart`.

void main() {
  test(
    'AI review overview: one suggestion is generated and, as a valid '
    'catalogue match, is accepted automatically',
    () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: queue.first.id,
        photo: photo!,
        note: 'Cracked tile',
      );
      await _pumpAiQueue();

      final session = container.read(activeSessionProvider)!;
      expect(session.aiSuggestions, hasLength(1));
      expect(session.aiSuggestions.single.status, AiSuggestionStatus.accepted);
      expect(session.aiSuggestions.single.isAutoAccepted, isTrue);
    },
  );

  test('accept preserves the original suggestion and sets the final '
      'result to match it', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    // "Master Bathroom" deterministically resolves to a confident
    // match in the fake AI (a plumbing/sanitary-fitting area name).
    final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: bathroom.id,
      photo: photo!,
      note: 'Leaking water tap',
    );
    await _pumpAiQueue();

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    expect(suggestion.suggestedCatalogueEntryId, isNotNull);
    final originalEntryId = suggestion.suggestedCatalogueEntryId;

    notifier.acceptSuggestion(suggestion.id);

    final updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.accepted);
    expect(updated.suggestedCatalogueEntryId, originalEntryId); // untouched
    expect(updated.finalCatalogueEntryId, originalEntryId);
    expect(updated.reviewedAt, isNotNull);
  });

  test('change preserves the original suggestion and stores the '
      "inspector's picked catalogue entry separately", () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: bathroom.id,
      photo: photo!,
      note: 'Leaking water tap',
    );
    await _pumpAiQueue();

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final originalEntryId = suggestion.suggestedCatalogueEntryId;
    final correctedEntry = DefectCatalogue.instance.entries.firstWhere(
      (e) => e.id != originalEntryId,
    );

    notifier.changeSuggestion(suggestion.id, correctedEntry.id);

    final updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.edited);
    expect(
      updated.suggestedCatalogueEntryId,
      originalEntryId,
    ); // never overwritten
    expect(updated.finalCatalogueEntryId, correctedEntry.id);
  });

  test(
    'reject/mark unresolved preserves the original suggestion and '
    "leaves no final classification, rather than losing the finding",
    () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: bathroom.id,
        photo: photo!,
        note: 'Leaking water tap',
      );
      await _pumpAiQueue();

      final suggestion = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      final originalEntryId = suggestion.suggestedCatalogueEntryId;

      notifier.rejectSuggestion(suggestion.id);

      final updated = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      expect(updated.status, AiSuggestionStatus.rejected);
      expect(updated.suggestedCatalogueEntryId, originalEntryId);
      expect(updated.hasFinalEntry, isFalse);
      expect(updated.isResolved, isTrue);
    },
  );

  test(
    'review resolves via changeSuggestion after an initial reject',
    () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: bathroom.id,
        photo: photo!,
        note: 'Leaking water tap',
      );
      await _pumpAiQueue();

      final suggestion = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      notifier.rejectSuggestion(suggestion.id);
      expect(
        container
            .read(activeSessionProvider)!
            .aiSuggestions
            .single
            .hasFinalEntry,
        isFalse,
      );

      final entry = DefectCatalogue.instance.entries.first;
      notifier.changeSuggestion(suggestion.id, entry.id);

      final updated = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      expect(updated.status, AiSuggestionStatus.edited);
      expect(updated.finalCatalogueEntryId, entry.id);
    },
  );

  test('pending review count decreases as suggestions are resolved, and '
      'review cannot complete while any remain pending', () async {
    // Two Smart analyses (up to 300 Credits each) need more than the
    // fake's 500-Credit default. This previously passed only because both
    // balance checks ran before either charge landed, letting the fake's
    // balance go negative; analysis now starts after each finding's
    // durable save, so the runs no longer overlap that way.
    final container = ProviderContainer(
      overrides: testOverrides(
        billingService: UncertainAiBillingService(initialBalanceCredits: 5000),
      ),
    );
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

    final photoA = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final findingA = notifier.saveCameraFinding(
      sectionId: bathroom.id,
      photo: photoA!,
      note: 'Finding A',
    );
    final photoB = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: bathroom.id,
      photo: photoB!,
      note: 'Finding B',
    );
    await _pumpAiQueue();

    var session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions, hasLength(2));
    expect(session.aiSuggestions.where((s) => !s.isResolved).length, 2);
    expect(session.status, isNot(InspectionStatus.aiReviewComplete));

    final suggestionA = session.aiSuggestions.firstWhere(
      (s) => s.findingId == findingA.id,
    );
    notifier.acceptSuggestion(suggestionA.id);

    session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions.where((s) => !s.isResolved).length, 1);
    // Still one pending — review must not be considered complete yet.
    expect(session.status, isNot(InspectionStatus.aiReviewComplete));

    final suggestionB = session.aiSuggestions.firstWhere(
      (s) => s.findingId != findingA.id,
    );
    notifier.acceptSuggestion(suggestionB.id);

    session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions.every((s) => s.isResolved), isTrue);
    expect(session.aiReviewState, AiReviewState.completed);
    expect(session.status, InspectionStatus.aiReviewComplete);
  });

  test('AI suggestions and review state survive a repository reload', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final bathroom = queue.firstWhere((s) => s.name.contains('Bathroom'));

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: bathroom.id,
      photo: photo!,
      note: 'Leaking water tap',
    );
    await _pumpAiQueue();

    final sessionId = container.read(activeSessionProvider)!.id;
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final originalEntryId = suggestion.suggestedCatalogueEntryId;
    final correctedEntry = DefectCatalogue.instance.entries.firstWhere(
      (e) => e.id != originalEntryId,
    );
    notifier.changeSuggestion(suggestion.id, correctedEntry.id);

    // Simulate resuming after an app restart: a fresh notifier state,
    // reloaded straight from the (same in-memory) repository.
    notifier.clear();
    expect(container.read(activeSessionProvider), isNull);
    await notifier.resume(sessionId);

    final reloaded = container.read(activeSessionProvider)!;
    expect(reloaded.aiSuggestions, hasLength(1));
    final reloadedSuggestion = reloaded.aiSuggestions.single;
    expect(reloadedSuggestion.status, AiSuggestionStatus.edited);
    expect(reloadedSuggestion.finalCatalogueEntryId, correctedEntry.id);
    expect(
      reloadedSuggestion.suggestedCatalogueEntryId,
      isNot(correctedEntry.id),
    );
  });
}
