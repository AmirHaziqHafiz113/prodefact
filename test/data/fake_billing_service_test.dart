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

  group('estimateFindingAnalysis / analyseFinding (Pay as you go)', () {
    test('an inspection with no House Pass prices under flexCredits', () async {
      final service = FakeBillingService(initialBalanceTokens: 10000000);
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
      final service = FakeBillingService(initialBalanceTokens: 100000);
      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.expert,
      );
      expect(estimate.eligible, isFalse);
      expect(estimate.reason, EstimateIneligibleReason.insufficientTokens);

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
      final service = FakeBillingService(initialBalanceTokens: 10000000);
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

      expect(result.tokensCharged, lessThanOrEqualTo(estimate.maximumTokens));
      expect(result.newBalance, 10000000 - result.tokensCharged);
    });
  });

  group('purchaseHousePass / confirmSandboxPayment', () {
    test('a purchased and confirmed House Pass switches the inspection to '
        'housePass pricing, with the included level free', () async {
      final service = FakeBillingService(initialBalanceTokens: 0);
      final intent = await service.purchaseHousePass('session_1');
      final confirmation = await service.confirmSandboxPayment(intent.intentId);
      expect(confirmation.purpose, PaymentPurpose.housePass);
      // House Pass purchase never grants Tokens.
      expect(confirmation.tokensAdded, 0);

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.smart, // the included level
      );
      expect(estimate.paymentMode, CommercialMode.housePass);
      expect(estimate.includedInHousePass, isTrue);
      expect(estimate.surchargeTokens, 0);
      expect(estimate.eligible, isTrue); // even with a 0 Tokens balance
    });

    test('a House Pass finding above the included level still requires '
        'Tokens for the surcharge', () async {
      final service = FakeBillingService(initialBalanceTokens: 0);
      final intent = await service.purchaseHousePass('session_1');
      await service.confirmSandboxPayment(intent.intentId);

      final estimate = await service.estimateFindingAnalysis(
        inspectionId: 'session_1',
        findingId: 'finding_1',
        aiLevel: AiLevel.expert, // above the included "smart" level
      );
      expect(estimate.surchargeTokens, greaterThan(0));
      expect(estimate.eligible, isFalse); // 0 balance can't cover it
    });

    test('the House Pass allowance is finite: after enough included-level '
        'analyses, it falls back to Pay as you go', () async {
      final service = FakeBillingService(initialBalanceTokens: 100000000);
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
      // Falls back to Pay as you go pricing — and since the balance still
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
      // Below Smart's 300-Token ceiling — every included-tier House
      // Pass analysis below is free (0 charge), so this balance is
      // untouched by the loop and still too low once Pay as you go
      // pricing takes back over.
      final service = FakeBillingService(initialBalanceTokens: 1000000);
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
    test('computes Tokens from the configured MYR-per-Token ratio, and '
        'confirming it Tokens the wallet', () async {
      final service = FakeBillingService(initialBalanceTokens: 0);
      final intent = await service.createTopUpIntent(30);
      expect(intent.tokensAmount, 30000000);

      final confirmation = await service.confirmSandboxPayment(intent.intentId);
      expect(confirmation.purpose, PaymentPurpose.topup);
      expect(confirmation.tokensAdded, 30000000);
      expect(confirmation.newBalance, 30000000);
    });
  });

  group('WalletActivityService (loadBalance / loadRecentTransactions)', () {
    test(
      'loadBalance matches the balance used for pricing decisions',
      () async {
        final service = FakeBillingService(initialBalanceTokens: 7770000);
        expect(await service.loadBalance('any-uid'), 7770000);
      },
    );

    test(
      'a fresh service already has a "Starting balance" ledger entry',
      () async {
        final service = FakeBillingService(initialBalanceTokens: 5000000);
        final transactions = await service.loadRecentTransactions('any-uid');
        expect(transactions, hasLength(1));
        expect(transactions.single.type, WalletTransactionType.topup);
        expect(transactions.single.amountTokens, 5000000);
      },
    );

    test(
      'a successful analysis appends a usage entry, most-recent-first',
      () async {
        final service = FakeBillingService(initialBalanceTokens: 10000000);
        await service.analyseFinding(
          request: _request(),
          aiLevel: AiLevel.smart,
          idempotencyKey: 'idem_1',
        );

        final transactions = await service.loadRecentTransactions('any-uid');
        expect(transactions.first.type, WalletTransactionType.usage);
        expect(transactions.first.direction, LedgerDirection.debit);
        expect(transactions.length, 2); // starting balance + this usage
      },
    );

    test('a confirmed top-up appends a topup entry', () async {
      final service = FakeBillingService(initialBalanceTokens: 0);
      final intent = await service.createTopUpIntent(10);
      await service.confirmSandboxPayment(intent.intentId);

      final transactions = await service.loadRecentTransactions('any-uid');
      expect(transactions.first.type, WalletTransactionType.topup);
      expect(transactions.first.amountTokens, 10000000);
    });

    test('loadRecentTransactions respects the limit', () async {
      final service = FakeBillingService(initialBalanceTokens: 100000000);
      for (var i = 0; i < 5; i++) {
        await service.analyseFinding(
          request: _request(note: 'finding_$i'),
          aiLevel: AiLevel.fast,
          idempotencyKey: 'idem_$i',
        );
      }
      final transactions = await service.loadRecentTransactions(
        'any-uid',
        limit: 2,
      );
      expect(transactions, hasLength(2));
    });
  });
}
