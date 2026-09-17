import '../../core/inspection/inspection_domain.dart';
import '../ai/fake_ai_inspection_service.dart';

/// Deterministic, offline demo/fake [BillingService].
///
/// This is **not a real payment/wallet backend** — it never makes a
/// network call, never talks to Firestore, and its balance/House Pass
/// state exists only in memory for the lifetime of this instance. It
/// exists so the commercial layer can be developed, demoed, and tested
/// in local-only mode — exactly like [FakeAiInspectionService] stands
/// in for the real AI backend. See docs/commercial_model.md for the
/// production design this simulates.
///
/// Starts with a small, deliberately non-generous balance (enough for
/// a couple of analyses) so the low-balance/insufficient-Credits UI
/// stays reachable in local-only/demo mode too, not just online.
class FakeBillingService implements BillingService {
  FakeBillingService({int initialBalanceCredits = 500})
    : _balanceCredits = initialBalanceCredits;

  int _balanceCredits;
  final Map<String, _FakeHousePass> _housePassByInspection = {};
  final Map<String, _FakePendingIntent> _pendingIntents = {};
  final FakeAiInspectionService _aiService = FakeAiInspectionService();

  static const Map<AiLevel, int> _maxCreditsByLevel = {
    AiLevel.fast: 150,
    AiLevel.smart: 300,
    AiLevel.expert: 600,
  };
  static const _housePassIncludedLevel = AiLevel.smart;
  static const _housePassAllowanceFindings = 5;
  static const _housePassPriceMyr = 30.0;
  static const _creditsPerMyr = 100;

  @override
  Future<CommercialConfig> getCommercialConfig() async {
    return CommercialConfig(
      creditsPerMyr: _creditsPerMyr,
      lowBalanceThresholdCredits: 200,
      topUpPackages: const [
        TopUpPackage(myr: 10, credits: 1000),
        TopUpPackage(myr: 30, credits: 3000),
        TopUpPackage(myr: 50, credits: 5000),
        TopUpPackage(myr: 100, credits: 10000),
      ],
      aiLevels: [
        AiLevelInfo(
          level: AiLevel.fast,
          label: 'Fast',
          description: 'Lowest cost — good for obvious defects.',
          maximumCredits: _maxCreditsByLevel[AiLevel.fast]!,
        ),
        AiLevelInfo(
          level: AiLevel.smart,
          label: 'Smart',
          description: 'Recommended — best balance of cost and accuracy.',
          maximumCredits: _maxCreditsByLevel[AiLevel.smart]!,
        ),
        AiLevelInfo(
          level: AiLevel.expert,
          label: 'Expert',
          description: 'Best for difficult or unclear findings.',
          maximumCredits: _maxCreditsByLevel[AiLevel.expert]!,
        ),
      ],
      housePass: const HousePassInfo(
        enabled: true,
        priceMyr: _housePassPriceMyr,
        includedAiLevel: _housePassIncludedLevel,
        allowanceFindings: _housePassAllowanceFindings,
        // Never true here — this is a fake, never a real commercial
        // decision. Mirrors the backend's own `environment: "test"`
        // default (see docs/commercial_model.md).
        isProductionReady: false,
      ),
    );
  }

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) async {
    final maxCredits = _maxCreditsByLevel[aiLevel]!;
    final pass = _housePassByInspection[inspectionId];

    if (pass == null || !pass.hasRemainingAllowance) {
      final eligible = _balanceCredits >= maxCredits;
      return AnalysisEstimate(
        aiLevel: aiLevel,
        estimatedCredits: maxCredits,
        maximumCredits: maxCredits,
        currentBalance: _balanceCredits,
        paymentMode: CommercialMode.flexCredits,
        includedInHousePass: false,
        surchargeCredits: 0,
        eligible: eligible,
        reason: eligible
            ? null
            : (pass != null
                  ? EstimateIneligibleReason.housePassAllowanceReached
                  : EstimateIneligibleReason.insufficientCredits),
      );
    }

    final surcharge = _rank(aiLevel) <= _rank(_housePassIncludedLevel)
        ? 0
        : maxCredits;
    final eligible = surcharge == 0 || _balanceCredits >= surcharge;
    return AnalysisEstimate(
      aiLevel: aiLevel,
      estimatedCredits: surcharge,
      maximumCredits: surcharge,
      currentBalance: _balanceCredits,
      paymentMode: CommercialMode.housePass,
      includedInHousePass: surcharge == 0,
      surchargeCredits: surcharge,
      eligible: eligible,
      reason: eligible ? null : EstimateIneligibleReason.insufficientCredits,
    );
  }

  static int _rank(AiLevel level) => switch (level) {
    AiLevel.fast => 0,
    AiLevel.smart => 1,
    AiLevel.expert => 2,
  };

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final estimate = await estimateFindingAnalysis(
      inspectionId: request.sessionId,
      findingId: request.findingId,
      aiLevel: aiLevel,
    );
    if (!estimate.eligible) {
      throw Exception(
        estimate.reason == EstimateIneligibleReason.insufficientCredits
            ? "You don't have enough Credits for this analysis."
            : "This House Pass can't be used for this analysis right now.",
      );
    }

    final classification = await _aiService.classifyFinding(request);

    final maxCharge = estimate.paymentMode == CommercialMode.housePass
        ? estimate.surchargeCredits
        : estimate.maximumCredits;
    // A simulated usage-based settlement: an inconclusive (needsReview)
    // finding "used" less of the reserved maximum than a confidently
    // classified one — the same shape as the real backend's real-usage
    // settlement, just approximated instead of measured.
    final actualCharge = classification.needsReview
        ? (maxCharge * 0.5).round()
        : maxCharge;
    _balanceCredits -= actualCharge;

    if (estimate.paymentMode == CommercialMode.housePass) {
      _housePassByInspection[request.sessionId]?.recordUsage();
    }

    return AnalyseFindingResult(
      aiLevel: aiLevel,
      creditsCharged: actualCharge,
      newBalance: _balanceCredits,
      paymentMode: estimate.paymentMode,
      classification: classification,
    );
  }

  @override
  Future<TopUpIntent> createTopUpIntent(double amountMyr) async {
    final intentId = 'fake_topup_${DateTime.now().microsecondsSinceEpoch}';
    final credits = (amountMyr * _creditsPerMyr).round();
    _pendingIntents[intentId] = _FakePendingIntent(
      purpose: PaymentPurpose.topup,
      amountMyr: amountMyr,
      creditsAmount: credits,
    );
    return TopUpIntent(
      intentId: intentId,
      amountMyr: amountMyr,
      creditsAmount: credits,
    );
  }

  @override
  Future<HousePassPurchaseIntent> purchaseHousePass(String inspectionId) async {
    final intentId = 'fake_house_pass_${DateTime.now().microsecondsSinceEpoch}';
    _pendingIntents[intentId] = _FakePendingIntent(
      purpose: PaymentPurpose.housePass,
      amountMyr: _housePassPriceMyr,
      inspectionId: inspectionId,
    );
    return HousePassPurchaseIntent(
      intentId: intentId,
      priceMyr: _housePassPriceMyr,
    );
  }

  @override
  Future<SandboxPaymentConfirmation> confirmSandboxPayment(
    String intentId,
  ) async {
    final intent = _pendingIntents.remove(intentId);
    if (intent == null) throw Exception('That could not be found.');

    if (intent.purpose == PaymentPurpose.topup) {
      _balanceCredits += intent.creditsAmount!;
      return SandboxPaymentConfirmation(
        purpose: PaymentPurpose.topup,
        newBalance: _balanceCredits,
        creditsAdded: intent.creditsAmount!,
      );
    }
    _housePassByInspection[intent.inspectionId!] = _FakeHousePass(
      allowanceLimit: _housePassAllowanceFindings,
    );
    return SandboxPaymentConfirmation(
      purpose: PaymentPurpose.housePass,
      newBalance: _balanceCredits,
      creditsAdded: 0,
    );
  }
}

class _FakeHousePass {
  _FakeHousePass({required this.allowanceLimit});

  final int allowanceLimit;
  int allowanceUsed = 0;

  bool get hasRemainingAllowance => allowanceUsed < allowanceLimit;

  void recordUsage() => allowanceUsed++;
}

class _FakePendingIntent {
  _FakePendingIntent({
    required this.purpose,
    required this.amountMyr,
    this.creditsAmount,
    this.inspectionId,
  });

  final PaymentPurpose purpose;
  final double amountMyr;
  final int? creditsAmount;
  final String? inspectionId;
}
