import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/firebase_billing_service.dart';

AiFindingClassificationRequest _request({
  int attempt = 0,
  PreviousAttemptContext? previous,
}) => AiFindingClassificationRequest(
  sessionId: 's',
  findingId: 'f',
  sectionName: 'Balcony',
  sectionIsPlumbing: false,
  note: 'por peint',
  reanalysisAttempt: attempt,
  previousAttempt: previous,
);

void main() {
  test('the first request carries no previousAttempt, and never the '
      'image or any path', () {
    final payload = buildAnalyseFindingPayload(
      request: _request(
        previous: const PreviousAttemptContext(needsReviewReason: 'x'),
      ),
      aiLevel: AiLevel.smart,
      idempotencyKey: 'k',
    );
    expect(payload.containsKey('previousAttempt'), isFalse);
    expect(payload['note'], 'por peint', reason: 'the note is verbatim');
  });

  test('a Reanalyse sends only the controlled facts about the earlier '
      'attempt', () {
    final payload = buildAnalyseFindingPayload(
      request: _request(
        attempt: 2,
        previous: const PreviousAttemptContext(
          needsReviewReason: 'component_mismatch',
          detectedComponent: 'Door Frame',
        ),
      ),
      aiLevel: AiLevel.smart,
      idempotencyKey: 'k2',
    );
    expect(payload['reanalysisAttempt'], 2);
    expect(payload['previousAttempt'], {
      'needsReviewReason': 'component_mismatch',
      'detectedComponent': 'Door Frame',
    });
  });
}
