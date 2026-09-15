import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/default_ai_review_coordinator.dart';
import 'package:prodefact/data/report/default_report_coordinator.dart';

import '../support/fake_report_services.dart';
import '../support/test_repository.dart';

/// A fake AI backend with an artificial delay, so two concurrent
/// `runAnalysis` calls have a real window in which to race each other —
/// a plain synchronous fake wouldn't reliably exercise the race, since
/// the first call could complete before the second even starts.
class _SlowAiInspectionService implements AiInspectionService {
  @override
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return AiAnalysisResponse(
      providerId: 'slow-fake-v1',
      suggestions: request.findings
          .map(
            (finding) => AiFindingSuggestion(
              findingId: finding.findingId,
              defectType: 'Detected defect',
              recommendation: 'Recommended action',
            ),
          )
          .toList(),
    );
  }
}

/// A fake renderer with an artificial delay, for the same reason.
class _SlowReportRenderer extends FakeReportRenderer {
  @override
  Future<Uint8List> render(ReportModel model) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.render(model);
  }
}

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
  test('double-tapping "Start AI Analysis" (two concurrent runAnalysis '
      'calls) never duplicates suggestions', () async {
    final local = createInMemoryRepository();
    addTearDown(local.close);
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        elementId: 'floor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: _SlowAiInspectionService(),
    );

    // Fired concurrently — neither awaited before the other starts,
    // exactly like two taps of the same button in quick succession.
    final results = await Future.wait([
      coordinator.runAnalysis(session.id),
      coordinator.runAnalysis(session.id),
    ]);

    // Exactly one of the two actually ran analysis; the other was
    // rejected by the in-flight guard rather than racing it.
    expect(results.where((r) => r.isSuccess).length, 1);
    expect(
      results.where((r) => r.outcome == AiAnalysisOutcome.alreadyReviewed),
      hasLength(1),
    );

    final reloaded = await local.loadSession(session.id);
    // Exactly one suggestion for the one finding — never duplicated.
    expect(reloaded!.aiSuggestions, hasLength(1));
  });

  test('double-tapping "Generate Report" (two concurrent generateReport '
      'calls) never corrupts report metadata', () async {
    final local = createInMemoryRepository();
    addTearDown(local.close);
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
    await local.saveAiSuggestion(
      AiSuggestion(
        id: 'suggestion_1',
        sessionId: session.id,
        findingId: 'finding_1',
        providerId: 'fake-demo-v1',
        generatedAt: now,
        finalDefectType: 'Cracked tile',
        status: AiSuggestionStatus.accepted,
        reviewedAt: now,
      ),
    );
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    await local.setAiReviewState(session.id, AiReviewState.completed);

    final fileStore = FakeReportFileStore();
    final coordinator = DefaultReportCoordinator(
      localRepository: local,
      renderer: _SlowReportRenderer(),
      fileStore: fileStore,
    );

    final results = await Future.wait([
      coordinator.generateReport(session.id, propertyTypeLabel: 'High Rise'),
      coordinator.generateReport(session.id, propertyTypeLabel: 'High Rise'),
    ]);

    expect(results.where((r) => r.isSuccess).length, 1);
    expect(results.where((r) => !r.isSuccess), hasLength(1));

    // Exactly one report row for this session — the guard prevented
    // two concurrent renders/writes to the same predictable filename.
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.report, isNotNull);
    expect(fileStore.exists(reloaded.report!.filePath), isTrue);
  });
}
