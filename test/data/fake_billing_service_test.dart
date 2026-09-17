import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';

AiFindingClassificationRequest _request({String note = 'Cracked tile'}) {
  return AiFindingClassificationRequest(
    sessionId: 'session_1',
    findingId: 'finding_1',
    sectionName: 'Master Bathroom',
    sectionIsPlumbing: true,
    note: note,
  );
}

void main() {
  group('getCommercialConfig', () {
    test('returns a config with all three AI levels and House Pass never '
        'marked production-ready', () async {
      final service = FakeBillingService();
      final config = await service.getCommercialConfig();

      expect(config.aiLevels.map((l) => l.level), [
        AiLevel.fast,
        AiLevel.smart,
        AiLevel.expert,
      ]);
      expect(config.housePass.isProductionReady, isFalse);
    });
  });

  group('estimateFindingAnalysis / analyseFinding (Flex Credits)', () {
    test('an inspection with no House Pass prices under flexCredits', () async {
      final service = FakeBillingService(initialBalanceCredits: 1000);
      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.smart,
      );
      expect(estimate.paymentMode, CommercialMode.flexCredits);
      expect(estimate.eligible, isTrue);
    });

    test('an insufficient balance is ineligible and analyseFinding refuses '
        'to run', () async {
      final service = FakeBillingService(initialBalanceCredits: 10);
      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.expert,
      );
      expect(estimate.eligible, isFalse);
      expect(estimate.reason, EstimateIneligibleReason.insufficientCredits);

      await expectLater(
        () => service.analyseFinding(
          request: _request(),
          aiLevel: AiLevel.expert,
          idempotencyKey: 'idem_1',
        ),
        throwsException,
      );
    });

    test('a successful analysis debits the balance by no more than the '
        'estimated maximum', () async {
      final service = FakeBillingService(initialBalanceCredits: 1000);
      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.smart,
      );

      final result = await service.analyseFinding(
        request: _request(),
        aiLevel: AiLevel.smart,
        idempotencyKey: 'idem_1',
      );

      expect(result.creditsCharged, lessThanOrEqualTo(estimate.maximumCredits));
      expect(result.newBalance, 1000 - result.creditsCharged);
    });
  });

  group('purchaseHousePass / confirmSandboxPayment', () {
    test('a purchased and confirmed House Pass switches the inspection to '
        'housePass pricing, with the included level free', () async {
      final service = FakeBillingService(initialBalanceCredits: 0);
      final intent = await service.purchaseHousePass('session_1');
      final confirmation = await service.confirmSandboxPayment(intent.intentId);
      expect(confirmation.purpose, PaymentPurpose.housePass);
      // House Pass purchase never grants Credits.
      expect(confirmation.creditsAdded, 0);

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.smart, // the included level
      );
      expect(estimate.paymentMode, CommercialMode.housePass);
      expect(estimate.includedInHousePass, isTrue);
      expect(estimate.surchargeCredits, 0);
      expect(estimate.eligible, isTrue); // even with a 0 Credits balance
    });

    test('a House Pass finding above the included level still requires '
        'Credits for the surcharge', () async {
      final service = FakeBillingService(initialBalanceCredits: 0);
      final intent = await service.purchaseHousePass('session_1');
      await service.confirmSandboxPayment(intent.intentId);

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.expert, // above the included "smart" level
      );
      expect(estimate.surchargeCredits, greaterThan(0));
      expect(estimate.eligible, isFalse); // 0 balance can't cover it
    });

    test('the House Pass allowance is finite: after enough included-level '
        'analyses, it falls back to Flex Credits', () async {
      final service = FakeBillingService(initialBalanceCredits: 10_000);
      final intent = await service.purchaseHousePass('session_1');
      await service.confirmSandboxPayment(intent.intentId);

      // Exhaust the fake's small allowance.
      for (var i = 0; i < 5; i++) {
        await service.analyseFinding(
          request: _request(note: 'finding_$i'),
          aiLevel: AiLevel.smart,
          idempotencyKey: 'idem_$i',
        );
      }

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_overflow',
        aiLevel: AiLevel.smart,
      );
      // Falls back to Flex Credits pricing — and since the balance still
      // covers it, this one analysis is still eligible (the allowance
      // being reached never blocks physical inspection or AI outright,
      // only which pricing pays for it).
      expect(estimate.paymentMode, CommercialMode.flexCredits);
      expect(estimate.eligible, isTrue);
    });

    test('once the allowance is reached, an ineligible fallback estimate '
        'is still reported as housePassAllowanceReached — mirroring the '
        'real backend, which reports the House Pass reason whenever a '
        'pass exists but is no longer active, regardless of whether the '
        'fallback balance would also be insufficient', () async {
      // Below Smart's 300-Credit ceiling — every included-tier House
      // Pass analysis below is free (0 charge), so this balance is
      // untouched by the loop and still too low once Flex Credits
      // pricing takes back over.
      final service = FakeBillingService(initialBalanceCredits: 100);
      final intent = await service.purchaseHousePass('session_1');
      await service.confirmSandboxPayment(intent.intentId);

      for (var i = 0; i < 5; i++) {
        await service.analyseFinding(
          request: _request(note: 'finding_$i'),
          aiLevel: AiLevel.smart,
          idempotencyKey: 'idem_$i',
        );
      }

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_overflow',
        aiLevel: AiLevel.smart,
      );
      expect(estimate.paymentMode, CommercialMode.flexCredits);
      expect(estimate.eligible, isFalse);
      expect(
        estimate.reason,
        EstimateIneligibleReason.housePassAllowanceReached,
      );
    });

    test('confirmSandboxPayment on an unknown intentId throws', () async {
      final service = FakeBillingService();
      await expectLater(
        () => service.confirmSandboxPayment('does_not_exist'),
        throwsException,
      );
    });
  });

  group('createTopUpIntent', () {
    test('computes Credits from the configured MYR-per-Credit ratio, and '
        'confirming it credits the wallet', () async {
      final service = FakeBillingService(initialBalanceCredits: 0);
      final intent = await service.createTopUpIntent(30);
      expect(intent.creditsAmount, 3000);

      final confirmation = await service.confirmSandboxPayment(intent.intentId);
      expect(confirmation.purpose, PaymentPurpose.topup);
      expect(confirmation.creditsAdded, 3000);
      expect(confirmation.newBalance, 3000);
    });
  });
}
