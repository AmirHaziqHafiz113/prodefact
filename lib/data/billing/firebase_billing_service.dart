import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/inspection/inspection_domain.dart';
import '../../core/logging/app_logger.dart';

/// Region every billing callable is deployed to — must match
/// `functions/src/index.ts` and `firebase.json`.
const _kFunctionsRegion = 'asia-southeast1';

const _kDefaultCallableTimeout = Duration(seconds: 30);

/// `analyseFinding` runs with `timeoutSeconds: 180` on the backend
/// (`functions/src/index.ts`) — a real Smart/Expert vision call on a
/// cold instance can legitimately take longer than the 30s every other
/// billing callable uses. Giving up at 30s previously reported
/// "failed" for requests the backend then finished and charged. The
/// wait is never visible to the inspector: analysis runs in the
/// background. Must stay below `AiAnalysisAttempt.replaySafeAfter`.
const kAnalyseFindingCallableTimeout = Duration(seconds: 200);

/// Production [BillingService]: calls the six commercial-layer
/// callables in `functions/src/billing/` — see
/// docs/commercial_model.md. This is the only file that imports
/// `cloud_functions` for billing concerns — no Firebase SDK type leaks
/// past it. Request/response mapping is factored into top-level,
/// side-effect-free functions below so it can be unit-tested without a
/// live callable — see `test/data/firebase_billing_service_test.dart`.
class FirebaseBillingService implements BillingService {
  FirebaseBillingService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _kFunctionsRegion);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic>? payload, {
    Duration timeout = _kDefaultCallableTimeout,
    bool classifyAnalysisOutcome = false,
  }) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    try {
      final result = await callable.call<Map<String, dynamic>>(payload);
      return result.data;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      AppLogger.error(
        'Billing callable "$name" failed (${error.code})',
        error,
        stackTrace,
      );
      final message = friendlyMessageForBillingFunctionsError(error.code);
      if (classifyAnalysisOutcome) {
        throw AnalyseFindingException(
          message,
          outcomeUnknown: analyseFindingOutcomeUnknownForCode(error.code),
        );
      }
      throw Exception(message);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Billing callable "$name" failed unexpectedly',
        error,
        stackTrace,
      );
      const message =
          'Could not reach the wallet service. Check your connection and '
          'try again.';
      if (classifyAnalysisOutcome) {
        // No backend response at all: the request may or may not have
        // been processed.
        throw const AnalyseFindingException(message, outcomeUnknown: true);
      }
      throw Exception(message);
    }
  }

  @override
  Future<CommercialConfig> getCommercialConfig() async {
    final raw = await _call('getCommercialConfig', null);
    return parseCommercialConfig(raw);
  }

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) async {
    final raw = await _call('estimateFindingAnalysis', {
      'inspectionId': inspectionId,
      'findingId': findingId,
      'aiLevel': aiLevel.name,
    });
    return parseAnalysisEstimate(raw);
  }

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final raw = await _call(
      'analyseFinding',
      buildAnalyseFindingPayload(
        request: request,
        aiLevel: aiLevel,
        idempotencyKey: idempotencyKey,
      ),
      timeout: kAnalyseFindingCallableTimeout,
      classifyAnalysisOutcome: true,
    );
    return parseAnalyseFindingResult(raw, request.findingId);
  }

  @override
  Future<TopUpIntent> createTopUpIntent(double amountMyr) async {
    final raw = await _call('createTopUpIntent', {
      'amountMyr': amountMyr,
      'idempotencyKey': _newIdempotencyKey('topup'),
    });
    return parseTopUpIntent(raw);
  }

  @override
  Future<HousePassPurchaseIntent> purchaseHousePass(String inspectionId) async {
    final raw = await _call('purchaseHousePass', {
      'inspectionId': inspectionId,
      'idempotencyKey': _newIdempotencyKey('house_pass'),
    });
    return parseHousePassPurchaseIntent(raw);
  }

  @override
  Future<SandboxPaymentConfirmation> confirmSandboxPayment(
    String intentId,
  ) async {
    final raw = await _call('confirmSandboxPayment', {'intentId': intentId});
    return parseSandboxPaymentConfirmation(raw);
  }
}

/// A fresh, client-generated idempotency key for a one-shot request
/// (Top Up / House Pass purchase) where each button tap should create
/// its own intent — unlike `analyseFinding`'s idempotencyKey, which the
/// *caller* of [FirebaseBillingService.analyseFinding] controls so a
/// retry of the same approval can reuse it.
String _newIdempotencyKey(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

@visibleForTesting
Map<String, dynamic> buildAnalyseFindingPayload({
  required AiFindingClassificationRequest request,
  required AiLevel aiLevel,
  required String idempotencyKey,
}) {
  return {
    'inspectionId': request.sessionId,
    'findingId': request.findingId,
    'area': request.sectionName,
    'isPlumbingArea': request.sectionIsPlumbing,
    if (request.note != null && request.note!.isNotEmpty) 'note': request.note,
    if (request.evidenceIds.isNotEmpty) 'evidenceIds': request.evidenceIds,
    'aiLevel': aiLevel.name,
    'idempotencyKey': idempotencyKey,
  };
}

@visibleForTesting
CommercialConfig parseCommercialConfig(Map<String, dynamic> raw) {
  final topUpPackages = (raw['topUpPackages'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(
        (p) => TopUpPackage(
          myr: (p['myr'] as num).toDouble(),
          credits: (p['credits'] as num).toInt(),
        ),
      )
      .toList();

  final aiLevels = (raw['aiLevels'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(
        (l) => AiLevelInfo(
          level: AiLevel.values.byName(l['id'] as String),
          label: l['label'] as String,
          description: l['description'] as String,
          maximumCredits: (l['maximumCredits'] as num).toInt(),
        ),
      )
      .toList();

  final housePassRaw = raw['housePass'] as Map<String, dynamic>;
  return CommercialConfig(
    creditsPerMyr: (raw['creditsPerMyr'] as num).toInt(),
    lowBalanceThresholdCredits: (raw['lowBalanceThresholdCredits'] as num)
        .toInt(),
    topUpPackages: topUpPackages,
    aiLevels: aiLevels,
    housePass: HousePassInfo(
      enabled: housePassRaw['enabled'] == true,
      priceMyr: (housePassRaw['priceMyr'] as num).toDouble(),
      includedAiLevel: AiLevel.values.byName(
        housePassRaw['includedAiLevel'] as String,
      ),
      allowanceFindings: (housePassRaw['allowanceFindings'] as num).toInt(),
      isProductionReady: housePassRaw['isProductionReady'] == true,
    ),
  );
}

@visibleForTesting
AnalysisEstimate parseAnalysisEstimate(Map<String, dynamic> raw) {
  return AnalysisEstimate(
    aiLevel: AiLevel.values.byName(raw['aiLevel'] as String),
    estimatedCredits: (raw['estimatedCredits'] as num).toInt(),
    maximumCredits: (raw['maximumCredits'] as num).toInt(),
    currentBalance: (raw['currentBalance'] as num).toInt(),
    paymentMode: CommercialMode.values.byName(raw['paymentMode'] as String),
    includedInHousePass: raw['includedInHousePass'] == true,
    surchargeCredits: (raw['surchargeCredits'] as num).toInt(),
    eligible: raw['eligible'] == true,
    reason: _parseIneligibleReason(raw['reason']),
  );
}

EstimateIneligibleReason? _parseIneligibleReason(Object? raw) {
  if (raw == null) return null;
  return switch (raw) {
    'insufficientCredits' => EstimateIneligibleReason.insufficientCredits,
    'housePassAllowanceReached' =>
      EstimateIneligibleReason.housePassAllowanceReached,
    'housePassNotActive' => EstimateIneligibleReason.housePassNotActive,
    _ => EstimateIneligibleReason.unknown,
  };
}

@visibleForTesting
AnalyseFindingResult parseAnalyseFindingResult(
  Map<String, dynamic> raw,
  String expectedFindingId,
) {
  final classificationRaw = raw['classification'] as Map<String, dynamic>;
  final findingId = classificationRaw['findingId'];
  if (findingId != expectedFindingId) {
    throw Exception('AI response did not match the requested finding.');
  }

  final needsReview = classificationRaw['needsReview'] == true;
  final catalogueEntryId = _asStringOrNull(
    classificationRaw['catalogueEntryId'],
  );
  final rawCandidates = classificationRaw['candidateEntryIds'];

  return AnalyseFindingResult(
    aiLevel: AiLevel.values.byName(raw['aiLevel'] as String),
    creditsCharged: (raw['creditsCharged'] as num).toInt(),
    newBalance: (raw['newBalance'] as num).toInt(),
    paymentMode: CommercialMode.values.byName(raw['paymentMode'] as String),
    classification: AiFindingClassification(
      findingId: expectedFindingId,
      needsReview: needsReview || catalogueEntryId == null,
      catalogueEntryId: catalogueEntryId,
      confidence: (classificationRaw['confidence'] as num?)?.toDouble(),
      shortReason: _asStringOrNull(classificationRaw['shortReason']),
      candidateEntryIds: rawCandidates is List
          ? rawCandidates.whereType<String>().toList()
          : const [],
    ),
  );
}

@visibleForTesting
TopUpIntent parseTopUpIntent(Map<String, dynamic> raw) {
  return TopUpIntent(
    intentId: raw['intentId'] as String,
    amountMyr: (raw['amountMyr'] as num).toDouble(),
    creditsAmount: (raw['creditsAmount'] as num).toInt(),
  );
}

@visibleForTesting
HousePassPurchaseIntent parseHousePassPurchaseIntent(Map<String, dynamic> raw) {
  return HousePassPurchaseIntent(
    intentId: raw['intentId'] as String,
    priceMyr: (raw['priceMyr'] as num).toDouble(),
  );
}

@visibleForTesting
SandboxPaymentConfirmation parseSandboxPaymentConfirmation(
  Map<String, dynamic> raw,
) {
  return SandboxPaymentConfirmation(
    purpose: raw['purpose'] == 'housePass'
        ? PaymentPurpose.housePass
        : PaymentPurpose.topup,
    newBalance: (raw['newBalance'] as num).toInt(),
    creditsAdded: (raw['creditsAdded'] as num).toInt(),
  );
}

String? _asStringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A user-facing message for a [FirebaseFunctionsException.code] from a
/// billing callable — never the raw backend error detail. Extends the
/// AI callable's code set (`friendlyMessageForFunctionsError` in
/// `firebase_ai_inspection_service.dart`) with the additional codes
/// billing callables use.
@visibleForTesting
String friendlyMessageForBillingFunctionsError(String code) {
  switch (code) {
    case 'unauthenticated':
      return 'Sign in to use this.';
    case 'deadline-exceeded':
      return 'That took too long. Please try again.';
    case 'resource-exhausted':
      return 'Too many requests right now. Please try again shortly.';
    case 'unavailable':
      return 'Unavailable right now. Check your connection and try again.';
    case 'invalid-argument':
      return 'That request could not be completed (invalid data).';
    case 'permission-denied':
      return 'That does not belong to you.';
    case 'failed-precondition':
      return 'This is not available right now.';
    case 'not-found':
      return 'That could not be found.';
    case 'already-exists':
      return 'This already exists.';
    case 'aborted':
      return 'Payment could not be confirmed.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
