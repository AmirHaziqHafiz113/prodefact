import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/firebase_billing_service.dart';

const _validEntryId = 'door.door_hinge.03';

AiFindingClassificationRequest _requestWithEvidence() {
  return const AiFindingClassificationRequest(
    sessionId: 'session_1',
    findingId: 'finding_1',
    sectionName: 'Master Bathroom',
    sectionIsPlumbing: true,
    note: 'Cracked tile near the drain',
    evidenceFilePaths: ['/fake/e1.jpg'],
    evidenceIds: ['evidence_1'],
  );
}

Map<String, dynamic> _commercialConfigResponse() {
  return {
    'creditsPerMyr': 100,
    'lowBalanceThresholdCredits': 500,
    'topUpPackages': [
      {'myr': 10, 'credits': 1000},
      {'myr': 30, 'credits': 3000},
    ],
    'aiLevels': [
      {
        'id': 'fast',
        'label': 'Fast',
        'description': 'Lowest cost.',
        'maximumCredits': 150,
      },
      {
        'id': 'smart',
        'label': 'Smart',
        'description': 'Recommended.',
        'maximumCredits': 300,
      },
    ],
    'housePass': {
      'enabled': true,
      'priceMyr': 30,
      'includedAiLevel': 'smart',
      'allowanceFindings': 200,
      'isProductionReady': false,
    },
  };
}

void main() {
  group('buildAnalyseFindingPayload', () {
    test('maps request/level/idempotencyKey into the callable payload '
        'shape', () {
      final payload = buildAnalyseFindingPayload(
        request: _requestWithEvidence(),
        aiLevel: AiLevel.expert,
        idempotencyKey: 'idem_1',
      );

      expect(payload['inspectionId'], 'session_1');
      expect(payload['findingId'], 'finding_1');
      expect(payload['area'], 'Master Bathroom');
      expect(payload['isPlumbingArea'], isTrue);
      expect(payload['note'], 'Cracked tile near the drain');
      expect(payload['evidenceIds'], ['evidence_1']);
      expect(payload['aiLevel'], 'expert');
      expect(payload['idempotencyKey'], 'idem_1');
    });

    test('never sends a raw model/provider id — only the customer-facing '
        'level name', () {
      final payload = buildAnalyseFindingPayload(
        request: _requestWithEvidence(),
        aiLevel: AiLevel.smart,
        idempotencyKey: 'idem_1',
      );
      expect(payload.toString(), isNot(contains('gpt')));
      expect(payload.toString(), isNot(contains('deepseek')));
    });

    test('omits evidenceIds/note entirely when absent', () {
      const request = AiFindingClassificationRequest(
        sessionId: 'session_1',
        findingId: 'finding_1',
        sectionName: 'Master Bathroom',
        sectionIsPlumbing: true,
      );
      final payload = buildAnalyseFindingPayload(
        request: request,
        aiLevel: AiLevel.fast,
        idempotencyKey: 'idem_1',
      );
      expect(payload.containsKey('evidenceIds'), isFalse);
      expect(payload.containsKey('note'), isFalse);
    });
  });

  group('parseCommercialConfig', () {
    test('maps a well-formed response into a typed config', () {
      final config = parseCommercialConfig(_commercialConfigResponse());

      expect(config.creditsPerMyr, 100);
      expect(config.lowBalanceThresholdCredits, 500);
      expect(config.topUpPackages, hasLength(2));
      expect(config.topUpPackages.first.myr, 10);
      expect(config.topUpPackages.first.credits, 1000);
      expect(config.aiLevels, hasLength(2));
      expect(config.aiLevels.first.level, AiLevel.fast);
      expect(config.housePass.includedAiLevel, AiLevel.smart);
      expect(config.housePass.isProductionReady, isFalse);
    });

    test('never exposes a provider/model name — the response has no such '
        'field to expose in the first place', () {
      final raw = _commercialConfigResponse();
      expect(raw.toString(), isNot(contains('gpt')));
      expect(raw.toString(), isNot(contains('openai')));
      expect(raw.toString(), isNot(contains('deepseek')));
    });
  });

  group('parseAnalysisEstimate', () {
    test('maps an eligible Flex Credits estimate', () {
      final estimate = parseAnalysisEstimate({
        'aiLevel': 'smart',
        'estimatedCredits': 120,
        'maximumCredits': 300,
        'currentBalance': 5000,
        'paymentMode': 'flexCredits',
        'includedInHousePass': false,
        'surchargeCredits': 0,
        'eligible': true,
      });

      expect(estimate.aiLevel, AiLevel.smart);
      expect(estimate.maximumCredits, 300);
      expect(estimate.paymentMode, CommercialMode.flexCredits);
      expect(estimate.eligible, isTrue);
      expect(estimate.reason, isNull);
    });

    test('maps a recognized ineligible reason', () {
      final estimate = parseAnalysisEstimate({
        'aiLevel': 'smart',
        'estimatedCredits': 300,
        'maximumCredits': 300,
        'currentBalance': 0,
        'paymentMode': 'flexCredits',
        'includedInHousePass': false,
        'surchargeCredits': 0,
        'eligible': false,
        'reason': 'insufficientCredits',
      });
      expect(estimate.reason, EstimateIneligibleReason.insufficientCredits);
    });

    test('an unrecognized reason string maps to unknown, never invented', () {
      final estimate = parseAnalysisEstimate({
        'aiLevel': 'smart',
        'estimatedCredits': 300,
        'maximumCredits': 300,
        'currentBalance': 0,
        'paymentMode': 'flexCredits',
        'includedInHousePass': false,
        'surchargeCredits': 0,
        'eligible': false,
        'reason': 'someFutureReasonThisBuildDoesNotKnow',
      });
      expect(estimate.reason, EstimateIneligibleReason.unknown);
    });
  });

  group('parseAnalyseFindingResult', () {
    test('maps a well-formed response into a typed result', () {
      final result = parseAnalyseFindingResult({
        'aiLevel': 'smart',
        'creditsCharged': 85,
        'newBalance': 4915,
        'paymentMode': 'flexCredits',
        'classification': {
          'findingId': 'finding_1',
          'catalogueEntryId': _validEntryId,
          'confidence': 0.8,
          'needsReview': false,
        },
      }, 'finding_1');

      expect(result.aiLevel, AiLevel.smart);
      expect(result.creditsCharged, 85);
      expect(result.newBalance, 4915);
      expect(result.classification.catalogueEntryId, _validEntryId);
    });

    test('a classification for the wrong findingId throws rather than '
        'being silently accepted', () {
      expect(
        () => parseAnalyseFindingResult({
          'aiLevel': 'smart',
          'creditsCharged': 85,
          'newBalance': 4915,
          'paymentMode': 'flexCredits',
          'classification': {
            'findingId': 'finding_never_requested',
            'needsReview': true,
          },
        }, 'finding_1'),
        throwsException,
      );
    });
  });

  group('parseTopUpIntent / parseHousePassPurchaseIntent', () {
    test('maps a top-up intent response', () {
      final intent = parseTopUpIntent({
        'intentId': 'intent_1',
        'amountMyr': 30,
        'creditsAmount': 3000,
      });
      expect(intent.intentId, 'intent_1');
      expect(intent.amountMyr, 30);
      expect(intent.creditsAmount, 3000);
    });

    test('maps a House Pass purchase intent response', () {
      final intent = parseHousePassPurchaseIntent({
        'intentId': 'intent_2',
        'priceMyr': 30,
      });
      expect(intent.intentId, 'intent_2');
      expect(intent.priceMyr, 30);
    });
  });

  group('parseSandboxPaymentConfirmation', () {
    test('maps a top-up confirmation', () {
      final confirmation = parseSandboxPaymentConfirmation({
        'purpose': 'topup',
        'newBalance': 3000,
        'creditsAdded': 3000,
      });
      expect(confirmation.purpose, PaymentPurpose.topup);
      expect(confirmation.creditsAdded, 3000);
    });

    test('maps a House Pass confirmation, which never adds Credits', () {
      final confirmation = parseSandboxPaymentConfirmation({
        'purpose': 'housePass',
        'newBalance': 0,
        'creditsAdded': 0,
      });
      expect(confirmation.purpose, PaymentPurpose.housePass);
      expect(confirmation.creditsAdded, 0);
    });
  });

  group('friendlyMessageForBillingFunctionsError', () {
    test('maps failed-precondition to an availability message', () {
      expect(
        friendlyMessageForBillingFunctionsError('failed-precondition'),
        contains('not available'),
      );
    });

    test('maps permission-denied to an ownership message', () {
      expect(
        friendlyMessageForBillingFunctionsError('permission-denied'),
        contains('does not belong to you'),
      );
    });

    test('maps already-exists to a duplicate-purchase message', () {
      expect(
        friendlyMessageForBillingFunctionsError('already-exists'),
        contains('already exists'),
      );
    });

    test('never echoes a raw backend error code as-is for an unknown '
        'code', () {
      final message = friendlyMessageForBillingFunctionsError(
        'some-internal-code',
      );
      expect(message, isNot(contains('some-internal-code')));
    });
  });

  test('FirebaseFunctionsException carries a code the mapping switches on '
      '(sanity check that the real exception type is compatible)', () {
    final exception = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'test',
    );
    expect(
      friendlyMessageForBillingFunctionsError(exception.code),
      contains('not available'),
    );
  });
}
