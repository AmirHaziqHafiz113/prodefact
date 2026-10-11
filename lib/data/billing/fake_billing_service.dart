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
/// a couple of analyses) so the low-balance/insufficient-Tokens UI
/// stays reachable in local-only/demo mode too, not just online.
///
/// Also implements [WalletActivityService] — in local-only mode
/// there's no Firestore to read a ledger from, so this same instance
/// (see `billing_providers.dart`) is the one source of truth for both
/// the mutating (`BillingService`) and read-only (`WalletActivityService`)
/// surfaces, exactly mirroring how the real backend's ledger and
/// callables both describe the same underlying wallet.
class FakeBillingService
    implements BillingService, WalletActivityService, HousePassStatusService {
  FakeBillingService({int initialBalanceTokens = 5000000})
    : _balanceTokens = initialBalanceTokens {
    if (initialBalanceTokens > 0) {
      _record(
        type: WalletTransactionType.topup,
        direction: LedgerDirection.credit,
        amountTokens: initialBalanceTokens,
        description: 'Starting balance',
      );
    }
  }

  int _balanceTokens;
  final Map<String, _FakeHousePass> _housePassByInspection = {};
  final Map<String, _FakePendingIntent> _pendingIntents = {};
  final FakeAiInspectionService _aiService = FakeAiInspectionService();
  final List<WalletTransactionSummary> _ledger = [];
  int _ledgerSequence = 0;

  /// Completed analyses by idempotency key — mirrors the backend's
  /// `aiJobs` store, so replaying the same key in local-only/demo mode
  /// returns the original result instead of charging again.
  final Map<String, AnalyseFindingResult> _completedAnalyses = {};

  void _record({
    required WalletTransactionType type,
    required LedgerDirection direction,
    required int amountTokens,
    required String description,
  }) {
    _ledgerSequence++;
    _ledger.insert(
      0,
      WalletTransactionSummary(
        id: 'fake_ledger_$_ledgerSequence',
        type: type,
        direction: direction,
        amountTokens: amountTokens,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<int> loadBalance(String uid) async => _balanceTokens;

  final List<UsageRecordSummary> _usageRecords = [];

  @override
  Future<List<UsageRecordSummary>> loadUsageRecords(
    String uid, {
    int limit = 100,
  }) async => _usageRecords.take(limit).toList();

  @override
  Future<List<WalletTransactionSummary>> loadRecentTransactions(
    String uid, {
    int limit = 30,
  }) async => _ledger.take(limit).toList();

  @override
  Future<HousePassSummary> loadHousePassStatus(
    String uid,
    String inspectionId,
  ) async {
    final pass = _housePassByInspection[inspectionId];
    if (pass != null) {
      return HousePassSummary(
        status: pass.hasRemainingAllowance
            ? HousePassLifecycleStatus.active
            : HousePassLifecycleStatus.allowanceReached,
        priceMyr: _housePassPriceMyr,
        includedAiLevel: _housePassIncludedLevel,
        allowanceUsed: pass.allowanceUsed,
        allowanceLimit: pass.allowanceLimit,
        isProductionReady: false,
      );
    }

    final pendingEntry = _pendingIntents.entries.where(
      (e) =>
          e.value.purpose == PaymentPurpose.housePass &&
          e.value.inspectionId == inspectionId,
    );
    if (pendingEntry.isNotEmpty) {
      return HousePassSummary(
        status: HousePassLifecycleStatus.paymentPending,
        priceMyr: _housePassPriceMyr,
        pendingIntentId: pendingEntry.first.key,
      );
    }

    return const HousePassSummary(
      status: HousePassLifecycleStatus.purchaseRequired,
      priceMyr: _housePassPriceMyr,
    );
  }

  static const Map<AiLevel, int> _maxTokensByLevel = {
    AiLevel.fast: 1500000,
    AiLevel.smart: 3000000,
    AiLevel.expert: 6000000,
  };
  static const _housePassIncludedLevel = AiLevel.smart;
  static const _housePassAllowanceFindings = 5;
  static const _housePassPriceMyr = 30.0;
  static const _tokensPerMyr = 1000000;

  @override
  Future<CommercialConfig> getCommercialConfig() async {
    return CommercialConfig(
      tokensPerMyr: _tokensPerMyr,
      lowBalanceThresholdTokens: 2000000,
      topUpPackages: const [
        TopUpPackage(myr: 10, tokens: 10000000),
        TopUpPackage(myr: 30, tokens: 30000000),
        TopUpPackage(myr: 50, tokens: 50000000),
        TopUpPackage(myr: 100, tokens: 100000000),
      ],
      aiLevels: [
        AiLevelInfo(
          level: AiLevel.fast,
          label: 'Fast',
          description: 'Lowest cost — good for obvious defects.',
          maximumTokens: _maxTokensByLevel[AiLevel.fast]!,
        ),
        AiLevelInfo(
          level: AiLevel.smart,
          label: 'Smart',
          description: 'Recommended — best balance of cost and accuracy.',
          maximumTokens: _maxTokensByLevel[AiLevel.smart]!,
        ),
        AiLevelInfo(
          level: AiLevel.expert,
          label: 'Expert',
          description: 'Best for difficult or unclear findings.',
          maximumTokens: _maxTokensByLevel[AiLevel.expert]!,
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
    final maxTokens = _maxTokensByLevel[aiLevel]!;
    final pass = _housePassByInspection[inspectionId];

    if (pass == null || !pass.hasRemainingAllowance) {
      final eligible = _balanceTokens >= maxTokens;
      return AnalysisEstimate(
        aiLevel: aiLevel,
        estimatedTokens: maxTokens,
        maximumTokens: maxTokens,
        currentBalance: _balanceTokens,
        paymentMode: CommercialMode.flexCredits,
        includedInHousePass: false,
        surchargeTokens: 0,
        eligible: eligible,
        reason: eligible
            ? null
            : (pass != null
                  ? EstimateIneligibleReason.housePassAllowanceReached
                  : EstimateIneligibleReason.insufficientTokens),
      );
    }

    final surcharge = _rank(aiLevel) <= _rank(_housePassIncludedLevel)
        ? 0
        : maxTokens;
    final eligible = surcharge == 0 || _balanceTokens >= surcharge;
    return AnalysisEstimate(
      aiLevel: aiLevel,
      estimatedTokens: surcharge,
      maximumTokens: surcharge,
      currentBalance: _balanceTokens,
      paymentMode: CommercialMode.housePass,
      includedInHousePass: surcharge == 0,
      surchargeTokens: surcharge,
      eligible: eligible,
      reason: eligible ? null : EstimateIneligibleReason.insufficientTokens,
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
    final replayed = _completedAnalyses[idempotencyKey];
    if (replayed != null) {
      return AnalyseFindingResult(
        aiLevel: replayed.aiLevel,
        tokensCharged: replayed.tokensCharged,
        newBalance: _balanceTokens,
        paymentMode: replayed.paymentMode,
        classification: replayed.classification,
      );
    }
    final estimate = await estimateFindingAnalysis(
      inspectionId: request.sessionId,
      findingId: request.findingId,
      aiLevel: aiLevel,
    );
    if (!estimate.eligible) {
      throw Exception(
        estimate.reason == EstimateIneligibleReason.insufficientTokens
            ? "You don't have enough Tokens for this analysis."
            : "This House Pass can't be used for this analysis right now.",
      );
    }

    final classification = await _aiService.classifyFinding(request);

    final maxCharge = estimate.paymentMode == CommercialMode.housePass
        ? estimate.surchargeTokens
        : estimate.maximumTokens;
    // A simulated usage-based settlement: an inconclusive (needsReview)
    // finding "used" less of the reserved maximum than a confidently
    // classified one — the same shape as the real backend's real-usage
    // settlement, just approximated instead of measured.
    final actualCharge = classification.needsReview
        ? (maxCharge * 0.5).round()
        : maxCharge;
    _balanceTokens -= actualCharge;
    if (actualCharge > 0) {
      _record(
        type: WalletTransactionType.usage,
        direction: LedgerDirection.debit,
        amountTokens: actualCharge,
        description: 'AI analysis (${aiLevel.name})',
      );
    }

    // A simulated cost record, split like a real one (mostly AI, a
    // little storage/processing/other) and always summing to the charge.
    final storage = actualCharge ~/ 10;
    final processing = actualCharge ~/ 10;
    final other = actualCharge ~/ 20;
    _usageRecords.insert(
      0,
      UsageRecordSummary(
        id: idempotencyKey,
        operationType: 'aiAnalysis',
        tokensCharged: actualCharge,
        aiAnalysisTokens: actualCharge - storage - processing - other,
        storageTokens: storage,
        processingTokens: processing,
        otherTokens: other,
        createdAt: DateTime.now(),
        inspectionId: request.sessionId,
        findingId: request.findingId,
      ),
    );

    if (estimate.paymentMode == CommercialMode.housePass) {
      _housePassByInspection[request.sessionId]?.recordUsage();
    }

    final result = AnalyseFindingResult(
      aiLevel: aiLevel,
      tokensCharged: actualCharge,
      newBalance: _balanceTokens,
      paymentMode: estimate.paymentMode,
      classification: classification,
    );
    _completedAnalyses[idempotencyKey] = result;
    return result;
  }

  @override
  Future<TopUpIntent> createTopUpIntent(double amountMyr) async {
    final intentId = 'fake_topup_${DateTime.now().microsecondsSinceEpoch}';
    final tokens = (amountMyr * _tokensPerMyr).round();
    _pendingIntents[intentId] = _FakePendingIntent(
      purpose: PaymentPurpose.topup,
      amountMyr: amountMyr,
      tokensAmount: tokens,
    );
    return TopUpIntent(
      intentId: intentId,
      amountMyr: amountMyr,
      tokensAmount: tokens,
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
      _balanceTokens += intent.tokensAmount!;
      _record(
        type: WalletTransactionType.topup,
        direction: LedgerDirection.credit,
        amountTokens: intent.tokensAmount!,
        description: 'Top up — RM${intent.amountMyr.toStringAsFixed(0)}',
      );
      return SandboxPaymentConfirmation(
        purpose: PaymentPurpose.topup,
        newBalance: _balanceTokens,
        tokensAdded: intent.tokensAmount!,
      );
    }
    _housePassByInspection[intent.inspectionId!] = _FakeHousePass(
      allowanceLimit: _housePassAllowanceFindings,
    );
    _record(
      type: WalletTransactionType.housePassPurchase,
      direction: LedgerDirection.credit,
      amountTokens: 0,
      description:
          'House Pass purchase — RM${intent.amountMyr.toStringAsFixed(0)}',
    );
    return SandboxPaymentConfirmation(
      purpose: PaymentPurpose.housePass,
      newBalance: _balanceTokens,
      tokensAdded: 0,
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
    this.tokensAmount,
    this.inspectionId,
  });

  final PaymentPurpose purpose;
  final double amountMyr;
  final int? tokensAmount;
  final String? inspectionId;
}
