import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/firebase_ai_inspection_service.dart';

const _validEntryId = 'door.door_hinge.03';

AiFindingClassificationRequest _requestWithEvidence() {
  return const AiFindingClassificationRequest(
    sessionId: 'session_1',
    findingId: 'finding_1',
    sectionName: 'Master Bathroom',
    sectionIsPlumbing: true,
    note: 'Cracked tile near the drain',
    evidenceFilePaths: ['/fake/e1.jpg', '/fake/e2.jpg'],
    evidenceIds: ['evidence_1', 'evidence_2'],
  );
}

void main() {
  group('buildClassifyFindingPayload', () {
    test('maps session/finding context into the callable payload shape', () {
      final payload = buildClassifyFindingPayload(_requestWithEvidence());

      expect(payload['inspectionId'], 'session_1');
      expect(payload['findingId'], 'finding_1');
      expect(payload['area'], 'Master Bathroom');
      expect(payload['isPlumbingArea'], isTrue);
      expect(payload['note'], 'Cracked tile near the drain');
      // Opaque evidence ids only — the callable resolves these to
      // actual images itself, server-side.
      expect(payload['evidenceIds'], ['evidence_1', 'evidence_2']);
    });

    test('never includes account/user data (no such field exists to '
        'include in the first place)', () {
      final payload = buildClassifyFindingPayload(_requestWithEvidence());
      expect(payload.containsKey('ownerUid'), isFalse);
      expect(payload.containsKey('email'), isFalse);
      expect(payload.toString(), isNot(contains('@')));
    });

    test('never includes local evidence file paths — only ids', () {
      final payload = buildClassifyFindingPayload(_requestWithEvidence());
      expect(payload.toString(), isNot(contains('/fake/e1.jpg')));
      expect(payload.toString(), isNot(contains('/fake/e2.jpg')));
    });

    test('omits evidenceIds/note entirely when absent', () {
      const request = AiFindingClassificationRequest(
        sessionId: 'session_1',
        findingId: 'finding_1',
        sectionName: 'Master Bathroom',
        sectionIsPlumbing: true,
      );
      final payload = buildClassifyFindingPayload(request);
      expect(payload.containsKey('evidenceIds'), isFalse);
      expect(payload.containsKey('note'), isFalse);
    });
  });

  group('parseClassifyFindingResponse', () {
    test('maps a well-formed response into a typed classification', () {
      final classification = parseClassifyFindingResponse({
        'findingId': 'finding_1',
        'catalogueEntryId': _validEntryId,
        'confidence': 0.85,
        'shortReason': 'Visible crack in the photo',
        'needsReview': false,
      }, _requestWithEvidence());

      expect(classification.findingId, 'finding_1');
      expect(classification.catalogueEntryId, _validEntryId);
      expect(classification.confidence, 0.85);
      expect(classification.shortReason, 'Visible crack in the photo');
      expect(classification.needsReview, isFalse);
    });

    test('a response for the wrong findingId throws rather than being '
        'silently accepted', () {
      expect(
        () => parseClassifyFindingResponse({
          'findingId': 'finding_never_requested',
          'catalogueEntryId': _validEntryId,
        }, _requestWithEvidence()),
        throwsException,
      );
    });

    test('needsReview defaults to true when catalogueEntryId is absent', () {
      final classification = parseClassifyFindingResponse({
        'findingId': 'finding_1',
        'needsReview': true,
      }, _requestWithEvidence());
      expect(classification.catalogueEntryId, isNull);
      expect(classification.needsReview, isTrue);
    });

    test('coerces a non-string shortReason to null rather than throwing', () {
      final classification = parseClassifyFindingResponse({
        'findingId': 'finding_1',
        'catalogueEntryId': _validEntryId,
        'shortReason': 42,
      }, _requestWithEvidence());
      expect(classification.shortReason, isNull);
    });

    test('candidateEntryIds is empty when absent or malformed', () {
      final classification = parseClassifyFindingResponse({
        'findingId': 'finding_1',
        'needsReview': true,
      }, _requestWithEvidence());
      expect(classification.candidateEntryIds, isEmpty);
    });

    test('candidateEntryIds passes through a well-formed list', () {
      final classification = parseClassifyFindingResponse({
        'findingId': 'finding_1',
        'needsReview': true,
        'candidateEntryIds': [_validEntryId, 'door.door_hinge.01'],
      }, _requestWithEvidence());
      expect(classification.candidateEntryIds, [
        _validEntryId,
        'door.door_hinge.01',
      ]);
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
