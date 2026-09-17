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

/// A legacy (pre-camera-first, component-first) finding — has a real
/// [elementId], routing the report builder through its legacy branch.
Finding _legacyFinding({
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

/// A camera-first finding — no [elementId], routing the report builder
/// through the controlled-catalogue branch.
Finding _cameraFirstFinding({
  required String id,
  required String sectionId,
  String? description,
  String? notes,
  List<Evidence> evidence = const [],
  AiFindingStatus aiStatus = AiFindingStatus.completed,
}) {
  final now = DateTime(2026, 1, 1);
  return Finding(
    id: id,
    sectionId: sectionId,
    description: description,
    notes: notes,
    evidence: evidence,
    aiStatus: aiStatus,
    createdAt: now,
    updatedAt: now,
  );
}

AiSuggestion _legacyResolvedSuggestion({
  required String id,
  required String findingId,
  required AiSuggestionStatus status,
  required String finalDefectType,
  required String finalRecommendation,
  String? finalNotes,
}) {
  final now = DateTime(2026, 1, 1);
  return AiSuggestion(
    id: id,
    sessionId: 'session_1',
    findingId: findingId,
    providerId: 'fake-demo-v1',
    generatedAt: now,
    status: status,
    reviewedAt: now,
    legacyFinalElementId: 'floor',
    legacyFinalDefectType: finalDefectType,
    legacyFinalRecommendation: finalRecommendation,
    legacyFinalNotes: finalNotes,
  );
}

/// A resolved, catalogue-based suggestion — [catalogueEntryId] must be
/// a real entry id (the report builder resolves display text fresh
/// from `DefectCatalogue`, never from any AI-provided free text).
AiSuggestion _catalogueResolvedSuggestion({
  required String id,
  required String findingId,
  required AiSuggestionStatus status,
  String? catalogueEntryId,
}) {
  final now = DateTime(2026, 1, 1);
  return AiSuggestion(
    id: id,
    sessionId: 'session_1',
    findingId: findingId,
    providerId: 'deepseek',
    generatedAt: now,
    suggestedCatalogueEntryId: catalogueEntryId,
    finalCatalogueEntryId: catalogueEntryId ?? '',
    status: status,
    reviewedAt: now,
  );
}

InspectionSession _session({
  required List<Section> sections,
  required List<Finding> findings,
  Map<String, SectionStatus> sectionStatuses = const {},
  List<AiSuggestion> aiSuggestions = const [],
  PropertyDetails propertyDetails = PropertyDetails.empty,
  ReportMetadata? reportMetadata,
  String? inspectionNote,
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
    propertyDetails: propertyDetails,
    reportMetadata: reportMetadata,
    inspectionNote: inspectionNote,
  );
}

void main() {
  group('final value precedence — legacy (component-first) findings', () {
    test('an accepted suggestion reports the approved final value', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _legacyFinding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            componentId: 'floor_tile',
            description: 'Cracked tile',
          ),
        ],
        aiSuggestions: [
          _legacyResolvedSuggestion(
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
    });

    test('an edited suggestion reports the inspector-corrected value', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _legacyFinding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            componentId: 'floor_tile',
          ),
        ],
        aiSuggestions: [
          _legacyResolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.edited,
            finalDefectType: 'Inspector-corrected defect',
            finalRecommendation: 'Inspector-corrected recommendation',
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
    });

    test('a finding with no AI suggestion falls back to the inspector\'s '
        'own finding text', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [
          _legacyFinding(
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

  group('final value precedence — camera-first (controlled catalogue) '
      'findings', () {
    test('an accepted suggestion resolves the defect/recommendation from '
        'the catalogue entry, never from free text', () {
      final entry = DefectCatalogue.instance.entries.firstWhere(
        (e) => e.correctiveAction != null,
      );
      final session = _session(
        sections: [_bathroomSection()],
        findings: [_cameraFirstFinding(id: 'f1', sectionId: 'master_bathroom')],
        aiSuggestions: [
          _catalogueResolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.accepted,
            catalogueEntryId: entry.id,
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.elementName, entry.mainElementName);
      expect(finding.componentName, entry.componentName);
      expect(finding.defectType, entry.defectDescription);
      expect(finding.recommendation, entry.correctiveAction);
    });

    test('a rejected/unresolved suggestion renders an explicit '
        '"Unresolved" line rather than blank or crashing', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [_cameraFirstFinding(id: 'f1', sectionId: 'master_bathroom')],
        aiSuggestions: [
          _catalogueResolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.rejected,
            catalogueEntryId: null,
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.elementName, 'Unresolved');
      expect(finding.defectType, contains('Unresolved'));
    });

    test('a finding still pending review never shows an unapproved AI '
        'value', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: [_cameraFirstFinding(id: 'f1', sectionId: 'master_bathroom')],
        aiSuggestions: [
          _catalogueResolvedSuggestion(
            id: 's1',
            findingId: 'f1',
            status: AiSuggestionStatus.pending,
            catalogueEntryId: DefectCatalogue.instance.entries.first.id,
          ),
        ],
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      final finding = model.areas.single.findings.single;
      expect(finding.elementName, 'Pending review');
    });
  });

  group('grouping and completeness', () {
    test('findings are grouped by area', () {
      final session = _session(
        sections: [_bathroomSection(), _kitchenSection()],
        findings: [
          _legacyFinding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Bathroom issue',
          ),
          _legacyFinding(
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

    test('finding numbers are sequential across the whole report, not '
        'reset per area', () {
      final session = _session(
        sections: [_bathroomSection(), _kitchenSection()],
        findings: [
          _legacyFinding(
            id: 'f1',
            sectionId: 'master_bathroom',
            elementId: 'floor',
            description: 'Bathroom issue',
          ),
          _legacyFinding(
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

      final numbers = model.areas
          .expand((a) => a.findings)
          .map((f) => f.number)
          .toList();
      expect(numbers, [1, 2]);
    });

    test('a completed area with zero findings is represented, not omitted', () {
      final session = _session(
        sections: [_bathroomSection(), _kitchenSection()],
        findings: [
          _legacyFinding(
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
          _legacyFinding(
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

  group('property details / report metadata mapping', () {
    test('property details captured at setup flow into the report model', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: const [],
        propertyDetails: PropertyDetails(
          title: 'Residensi Vista',
          address: '1 Jalan Test',
          projectName: 'Vista Development',
          blockTower: 'Block A',
          unitNumber: 'A-12-08',
          clientName: 'Jane Client',
          inspectorName: 'John Inspector',
          inspectionDate: DateTime(2026, 3, 1),
        ),
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
        version: 2,
      );

      expect(model.propertyTitle, 'Residensi Vista');
      expect(model.propertyAddress, '1 Jalan Test');
      expect(model.projectName, 'Vista Development');
      expect(model.blockTower, 'Block A');
      expect(model.unitNumber, 'A-12-08');
      expect(model.clientName, 'Jane Client');
      expect(model.inspectorName, 'John Inspector');
      expect(model.inspectionDate, DateTime(2026, 3, 1));
      expect(model.version, 2);
    });

    test('a session with no property details (legacy/pre-v7) falls back to '
        'the property type label and session creation date, with default '
        'version 1', () {
      final session = _session(sections: [_bathroomSection()], findings: []);

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.propertyTitle, isNull);
      expect(model.propertyTypeLabel, 'High Rise');
      expect(model.inspectionDate, session.createdAt);
      expect(model.version, 1);
    });

    test('confirmed report metadata takes precedence over property '
        'details captured at setup', () {
      final session = _session(
        sections: [_bathroomSection()],
        findings: const [],
        propertyDetails: const PropertyDetails(
          title: 'Original Setup Title',
          clientName: 'Original Client',
        ),
        reportMetadata: const ReportMetadata(
          title: 'Confirmed Report Title',
          clientName: 'Confirmed Client',
          reportDate: null,
        ),
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.propertyTitle, 'Confirmed Report Title');
      expect(model.clientName, 'Confirmed Client');
    });

    test('the whole-inspection note and each area\'s note flow into the '
        'report model', () {
      final bathroomWithNote = _bathroomSection().copyWith(
        note: 'Ponding test started at 10:15 AM.',
      );
      final session = _session(
        sections: [bathroomWithNote],
        findings: const [],
        inspectionNote: 'Unit occupied during inspection.',
      );

      final model = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 1, 2),
      );

      expect(model.inspectionNote, 'Unit occupied during inspection.');
      expect(model.areas.single.note, 'Ponding test started at 10:15 AM.');
    });
  });
}
