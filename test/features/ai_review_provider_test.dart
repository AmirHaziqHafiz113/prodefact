import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

Future<ProviderContainer> _readyForReviewContainer() async {
  final container = ProviderContainer(overrides: testOverrides());
  await container
      .read(selectedPropertyTypeProvider.notifier)
      .select(PropertyType.highRise);

  final notifier = container.read(activeSessionProvider.notifier);
  final queue = container.read(inspectionQueueProvider);
  final statusNotifier = container.read(sectionStatusesProvider.notifier);
  for (final section in queue) {
    statusNotifier.setStatus(section.id, SectionStatus.completed);
  }

  final section = queue.first;
  notifier.addFinding(
    sectionId: section.id,
    elementId: section.elements.first.id,
    description: 'Cracked tile',
  );

  await notifier.markPhysicalInspectionComplete();
  final result = await notifier.startAiAnalysis();
  expect(result.isSuccess, isTrue);

  return container;
}

void main() {
  test(
    'AI review overview: one suggestion is generated and starts pending',
    () async {
      final container = await _readyForReviewContainer();
      addTearDown(container.dispose);

      final session = container.read(activeSessionProvider)!;
      expect(session.aiSuggestions, hasLength(1));
      expect(session.aiSuggestions.single.status, AiSuggestionStatus.pending);
      expect(session.aiReviewState, AiReviewState.readyForReview);
    },
  );

  test('accept preserves the original suggestion and sets the final '
      'result to match it', () async {
    final container = await _readyForReviewContainer();
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final originalDefect = suggestion.suggestedDefectType;

    notifier.acceptSuggestion(suggestion.id);

    final updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.accepted);
    expect(updated.suggestedDefectType, originalDefect); // untouched
    expect(updated.finalDefectType, originalDefect);
    expect(updated.reviewedAt, isNotNull);
  });

  test('edit preserves the original suggestion and stores the corrected '
      'result separately', () async {
    final container = await _readyForReviewContainer();
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final originalDefect = suggestion.suggestedDefectType;

    notifier.editSuggestion(
      suggestion.id,
      elementId: suggestion.suggestedElementId,
      componentId: suggestion.suggestedComponentId,
      defectType: 'Corrected defect type',
      recommendation: 'Corrected recommendation',
      notes: 'Edited notes',
    );

    final updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.edited);
    expect(updated.suggestedDefectType, originalDefect); // never overwritten
    expect(updated.finalDefectType, 'Corrected defect type');
    expect(updated.finalRecommendation, 'Corrected recommendation');
    expect(updated.finalNotes, 'Edited notes');
  });

  test('reject/correct preserves the original suggestion and stores the '
      "inspector's own correction rather than losing the finding", () async {
    final container = await _readyForReviewContainer();
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final originalDefect = suggestion.suggestedDefectType;
    final originalRecommendation = suggestion.suggestedRecommendation;

    notifier.rejectSuggestion(
      suggestion.id,
      elementId: suggestion.suggestedElementId,
      componentId: null,
      defectType: 'Inspector says: no defect present',
      recommendation: 'No action needed',
      notes: null,
    );

    final updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.rejected);
    expect(updated.suggestedDefectType, originalDefect);
    expect(updated.suggestedRecommendation, originalRecommendation);
    expect(updated.finalDefectType, 'Inspector says: no defect present');
    expect(updated.finalRecommendation, 'No action needed');
    // Cleared fields are stored as empty (not left equal to the old
    // value) — consistent with how finding text edits behave elsewhere.
    expect(updated.finalComponentId, isEmpty);
  });

  test('pending review count decreases as suggestions are resolved, and '
      'review cannot complete while any remain pending', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    final section = queue.first;
    final findingA = notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Finding A',
    );
    notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Finding B',
    );
    await notifier.markPhysicalInspectionComplete();
    await notifier.startAiAnalysis();

    var session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions, hasLength(2));
    expect(session.aiSuggestions.where((s) => !s.isResolved).length, 2);
    expect(session.aiReviewState, isNot(AiReviewState.completed));

    final suggestionA = session.aiSuggestions.firstWhere(
      (s) => s.findingId == findingA.id,
    );
    notifier.acceptSuggestion(suggestionA.id);

    session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions.where((s) => !s.isResolved).length, 1);
    // Still one pending — review must not be considered complete yet.
    expect(session.aiReviewState, isNot(AiReviewState.completed));
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
    final container = await _readyForReviewContainer();
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);
    final sessionId = container.read(activeSessionProvider)!.id;
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    notifier.editSuggestion(
      suggestion.id,
      elementId: suggestion.suggestedElementId,
      componentId: suggestion.suggestedComponentId,
      defectType: 'Corrected defect',
      recommendation: 'Corrected recommendation',
      notes: 'note',
    );

    // Simulate resuming after an app restart: a fresh notifier state,
    // reloaded straight from the (same in-memory) repository.
    notifier.clear();
    expect(container.read(activeSessionProvider), isNull);
    await notifier.resume(sessionId);

    final reloaded = container.read(activeSessionProvider)!;
    expect(reloaded.aiSuggestions, hasLength(1));
    final reloadedSuggestion = reloaded.aiSuggestions.single;
    expect(reloadedSuggestion.status, AiSuggestionStatus.edited);
    expect(reloadedSuggestion.finalDefectType, 'Corrected defect');
    expect(reloadedSuggestion.suggestedDefectType, isNot('Corrected defect'));
  });
}
