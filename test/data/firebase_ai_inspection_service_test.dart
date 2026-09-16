import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/firebase_ai_inspection_service.dart';

AiAnalysisRequest _requestWithOneFinding() {
  return const AiAnalysisRequest(
    sessionId: 'session_1',
    industry: 'homeInspection',
    assetTypeId: 'highRise',
    findings: [
      AiFindingContext(
        findingId: 'finding_1',
        sectionId: 'master_bathroom',
        sectionName: 'Master Bathroom',
        sectionIsPlumbing: true,
        elementId: 'floor',
        elementName: 'Floor',
        componentId: 'floor_tile',
        componentName: 'Floor tile',
        description: 'Cracked tile',
        notes: 'Near the drain',
        evidenceFilePaths: ['/fake/e1.jpg', '/fake/e2.jpg'],
        evidenceIds: ['evidence_1', 'evidence_2'],
      ),
    ],
  );
}

void main() {
  group('buildAnalyzeInspectionPayload', () {
    test('maps session/finding context into the callable payload shape', () {
      final payload = buildAnalyzeInspectionPayload(_requestWithOneFinding());

      expect(payload['inspectionId'], 'session_1');
      expect(payload['propertyType'], 'highRise');
      final findings = payload['findings'] as List;
      expect(findings, hasLength(1));
      final finding = findings.single as Map;
      expect(finding['findingId'], 'finding_1');
      expect(finding['area'], 'Master Bathroom');
      expect(finding['isPlumbingArea'], isTrue);
      expect(finding['element'], 'Floor');
      expect(finding['component'], 'Floor tile');
      expect(finding['description'], 'Cracked tile');
      expect(finding['notes'], 'Near the drain');
      // Evidence *count* only — never file paths/bytes.
      expect(finding['evidenceCount'], 2);
      expect(finding.containsKey('evidenceFilePaths'), isFalse);
      // Opaque evidence ids only — the callable resolves these to
      // actual images itself, server-side.
      expect(finding['evidenceIds'], ['evidence_1', 'evidence_2']);
    });

    test('never includes account/user data (no such field exists to '
        'include in the first place)', () {
      final payload = buildAnalyzeInspectionPayload(_requestWithOneFinding());
      expect(payload.containsKey('ownerUid'), isFalse);
      expect(payload.containsKey('email'), isFalse);
      expect(payload.toString(), isNot(contains('@')));
    });

    test('never includes local evidence file paths — only ids', () {
      final payload = buildAnalyzeInspectionPayload(_requestWithOneFinding());
      expect(payload.toString(), isNot(contains('/fake/e1.jpg')));
      expect(payload.toString(), isNot(contains('/fake/e2.jpg')));
    });

    test('omits evidenceIds entirely for a finding with no evidence', () {
      const request = AiAnalysisRequest(
        sessionId: 'session_1',
        industry: 'homeInspection',
        assetTypeId: 'highRise',
        findings: [
          AiFindingContext(
            findingId: 'finding_1',
            sectionId: 'master_bathroom',
            sectionName: 'Master Bathroom',
            sectionIsPlumbing: true,
            elementId: 'floor',
            elementName: 'Floor',
          ),
        ],
      );
      final payload = buildAnalyzeInspectionPayload(request);
      final finding = (payload['findings'] as List).single as Map;
      expect(finding.containsKey('evidenceIds'), isFalse);
    });
  });

  group('parseAnalyzeInspectionResponse', () {
    test('maps a well-formed response into typed suggestions, pinning '
        'element/component to the original finding', () {
      final response = parseAnalyzeInspectionResponse({
        'suggestions': [
          {
            'findingId': 'finding_1',
            'suggestedElement': 'Floor',
            'defectType': 'Cracked tile',
            'recommendation': 'Replace the tile',
            'notes': 'Check grout too',
          },
        ],
      }, _requestWithOneFinding());

      final suggestion = response.suggestions.single;
      expect(suggestion.findingId, 'finding_1');
      expect(suggestion.elementId, 'floor');
      expect(suggestion.componentId, 'floor_tile');
      expect(suggestion.defectType, 'Cracked tile');
      expect(suggestion.recommendation, 'Replace the tile');
      expect(suggestion.notes, 'Check grout too');
    });

    test('drops a suggestion referencing a findingId not in the request', () {
      final response = parseAnalyzeInspectionResponse({
        'suggestions': [
          {'findingId': 'finding_never_requested', 'defectType': 'x'},
        ],
      }, _requestWithOneFinding());
      expect(response.suggestions, isEmpty);
    });

    test('drops a malformed suggestion entry instead of throwing', () {
      final response = parseAnalyzeInspectionResponse({
        'suggestions': [
          'not a map',
          {'findingId': 123},
          {'noFindingIdField': true},
        ],
      }, _requestWithOneFinding());
      expect(response.suggestions, isEmpty);
    });

    test('throws when the response has no suggestions array at all '
        '(malformed provider output)', () {
      expect(
        () => parseAnalyzeInspectionResponse({
          'unexpected': 'shape',
        }, _requestWithOneFinding()),
        throwsException,
      );
    });

    test('coerces a non-string field to null rather than throwing', () {
      final response = parseAnalyzeInspectionResponse({
        'suggestions': [
          {'findingId': 'finding_1', 'defectType': 42},
        ],
      }, _requestWithOneFinding());
      expect(response.suggestions.single.defectType, isNull);
    });
  });

  group('friendlyMessageForFunctionsError', () {
    test('maps unauthenticated to a sign-in message', () {
      expect(
        friendlyMessageForFunctionsError('unauthenticated'),
        contains('Sign in'),
      );
    });

    test('maps deadline-exceeded to a timeout message', () {
      expect(
        friendlyMessageForFunctionsError('deadline-exceeded'),
        contains('timed out'),
      );
    });

    test('maps resource-exhausted to a rate-limit message', () {
      expect(
        friendlyMessageForFunctionsError('resource-exhausted'),
        contains('rate-limited'),
      );
    });

    test('maps unavailable to a connectivity message', () {
      expect(
        friendlyMessageForFunctionsError('unavailable'),
        contains('unavailable'),
      );
    });

    test('never echoes a raw provider/backend error code as-is for an '
        'unknown code', () {
      final message = friendlyMessageForFunctionsError('some-internal-code');
      expect(message, isNot(contains('some-internal-code')));
    });
  });

  test('FirebaseFunctionsException carries a code the mapping switches on '
      '(sanity check that the real exception type is compatible)', () {
    final exception = FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'test',
    );
    expect(
      friendlyMessageForFunctionsError(exception.code),
      contains('Sign in'),
    );
  });
}
