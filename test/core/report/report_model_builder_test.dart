import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

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
    elements: [InspectionElement(id: 'wall', name: 'Wall', components: [])],
  );
}

Finding _finding({
  required String id,
  required String sectionId,
  required String elementId,
  String? componentId,
  String? description,
  String? notes,
  List<Evidence> evidence = const [],
}) {
  final now = DateTime(2026, 1, 1);
  return Finding(
    id: id,
    sectionId: sectionId,
    elementId: elementId,
    componentId: componentId,
    description: description,
    notes: notes,
    evidence: evidence,
    createdAt: now,
    updatedAt: now,
  );
}

AiSuggestion _resolvedSuggestion({
  required String id,
  required String findingId,
  required AiSuggestionStatus status,
  required String finalDefectType,
  required String finalRecommendation,
  String? finalNotes,
  String suggestedDefectType = 'AI original defect',
  String suggestedRecommendation = 'AI original recommendation',
}) {
  final now = DateTime(2026, 1, 1);
  return AiSuggestion(
    id: id,
    sessionId: 'session_1',
    findingId: findingId,
    providerId: 'fake-demo-v1',
    generatedAt: now,
    suggestedElementId: 'floor',
    suggestedDefectType: suggestedDefectType,
    suggestedRecommendation: suggestedRecommendation,
    finalElementId: 'floor',
    finalDefectType: finalDefectType,
    finalRecommendation: finalRecommendation,
    finalNotes: finalNotes,
    status: status,
    reviewedAt: now,
  );
}

InspectionSession _session({
  required List<Section> sections,
  required List<Finding> findings,
  Map<String, SectionStatus> sectionStatuses = const {},
  List<AiSuggestion> aiSuggestions = const [],
}) {
  final now = DateTime(2026, 1, 1);
  return InspectionSession(
    id: 'session_1',
    industry: Industry.homeInspection,
    assetTypeId: 'highRise',
    sections: sections,
    sectionStatuses: sectionStatuses,
    findings: findings,
    createdAt: now,
    updatedAt: now,
    aiSuggestions: aiSuggestions,
  );
}

void main() {
  group('final value precedence', () {
    test(
      'an accepted suggestion reports the AI value (final == suggested)',
      () {
        final session = _session(
          sections: [_bathroomSection()],
          findings: [
            _finding(
              id: 'f1',
              sectionId: 'master_bathroom',
              elementId: 'floor',
              componentId: 'floor_tile',
              description: 'Cracked tile',
            ),
          ],
          aiSuggestions: [
            _resolvedSuggestion(
              id: 's1',
              findingId: 'f1',
              status: AiSuggestionStatus.accepted,
              finalDefectType: 'AI original defect',
              finalRecommendation: 'AI original recommendation',
            ),
          ],
        );

        final model = buildReportModel(
          session: session,
          propertyTypeLabel: 'High Rise',
          generatedAt: DateTime(2026, 1, 2),
        );

        final finding = model.areas.single.findings.single;
        expect(finding.defectType, 'AI original defect');
        expect(finding.recommendation, 'AI original recommendation');
      },
    );

    test('an edited suggestion reports the inspector-corrected value, not '
        'the original AI suggestion', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _finding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            componentId: 'floor_tile',
          ),
        ],
        aiSuggestions: [
          _resolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.edited,
            finalDefectType: 'Inspector-corrected defect',
            finalRecommendation: 'Inspector-corrected recommendation',
            suggestedDefectType: 'AI original defect',
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.defectType, 'Inspector-corrected defect');
      expect(finding.defectType, isNot('AI original defect'));
    });

    test('a rejected/corrected suggestion reports the inspector value, not '
        'the original AI suggestion', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _finding(id: 'f1', sectionId: 'master_bathroom', elementId: 'floor'),
        ],
        aiSuggestions: [
          _resolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.rejected,
            finalDefectType: 'No defect — AI was wrong',
            finalRecommendation: 'No action needed',
            suggestedDefectType: 'AI original defect',
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.defectType, 'No defect — AI was wrong');
      expect(finding.defectType, isNot('AI original defect'));
    });

    test('the original AI value is never substituted over the final '
        'inspector value across accept/edit/reject', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _finding(id: 'f1', sectionId: 'master_bathroom', elementId: 'floor'),
        ],
        aiSuggestions: [
          _resolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.edited,
            finalDefectType: 'Corrected',
            finalRecommendation: 'Corrected recommendation',
            suggestedDefectType: 'Original AI defect that must not leak',
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final allText = model.areas
          .expand((a) => a.findings)
          .map((f) => '${f.defectType} ${f.recommendation} ${f.notes}')
          .join(' ');
      expect(allText, isNot(contains('Original AI defect that must not leak')));
    });

    test('a finding with no AI suggestion falls back to the inspector\'s '
        'own finding text', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _finding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Raw inspector description',
            notes: 'Raw inspector notes',
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.defectType, 'Raw inspector description');
      expect(finding.notes, 'Raw inspector notes');
      expect(finding.recommendation, isNull);
    });
  });

  group('grouping and completeness', () {
    test('findings are grouped by area', () {
      final session = _session(
        sections: [_bathroomSection(), _kitchenSection()],
        findings: [
          _finding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Bathroom issue',
          ),
          _finding(
            id: 'f2',
            sectionId: 'kitchen',
            elementId: 'wall',
            description: 'Kitchen issue',
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.areas, hasLength(2));
      final bathroomArea = model.areas.firstWhere(
        (a) => a.name == 'Master Bathroom',
      );
      final kitchenArea = model.areas.firstWhere((a) => a.name == 'Kitchen');
      expect(bathroomArea.findings.single.defectType, 'Bathroom issue');
      expect(kitchenArea.findings.single.defectType, 'Kitchen issue');
    });

    test('a completed area with zero findings is represented, not omitted', () {
      final session = _session(
        sections: [_bathroomSection(), _kitchenSection()],
        findings: [
          _finding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Only the bathroom has a finding',
          ),
        ],
        sectionStatuses: const {
          'master_bathroom': SectionStatus.completed,
          'kitchen': SectionStatus.completed,
        },
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.areas, hasLength(2));
      final kitchenArea = model.areas.firstWhere((a) => a.name == 'Kitchen');
      expect(kitchenArea.findings, isEmpty);
      expect(model.completedAreas, 2);
      expect(model.totalAreas, 2);
    });

    test('excluded areas never appear in the report', () {
      final session = _session(
        sections: [
          _bathroomSection(),
          _kitchenSection().copyWith(isIncluded: false),
        ],
        findings: const [],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.areas, hasLength(1));
      expect(model.areas.single.name, 'Master Bathroom');
    });

    test('evidence metadata is included per finding', () {
      final now = DateTime(2026, 1, 1);
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _finding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Has photos',
            evidence: [
              Evidence(
                id: 'e1',
                findingId: 'f1',
                filePath: '/fake/e1.jpg',
                createdAt: now,
              ),
              Evidence(
                id: 'e2',
                findingId: 'f1',
                filePath: '/fake/e2.jpg',
                createdAt: now,
              ),
            ],
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.evidenceFilePaths, ['/fake/e1.jpg', '/fake/e2.jpg']);
      expect(model.totalEvidence, 2);
    });
  });
}
