import '../ai/ai_analysis_request.dart';
import '../entities/ai_level.dart';
import 'analyse_finding_result.dart';
import 'analysis_estimate.dart';
import 'commercial_config.dart';
import 'payment_intent.dart';

/// Provider-neutral commercial/billing backend abstraction — the
/// Flutter-side counterpart to `AiInspectionService`. Nothing in the
/// app computes a price, grants Credits, or activates a House Pass
/// itself; every one of those is backend-authoritative (see
/// docs/commercial_model.md). No implementation of this interface may
/// ever fabricate a successful payment outside a debug/test sandbox
/// build — see `confirmSandboxPayment`.
abstract class BillingService {
  /// The customer-safe pricing/AI-level/House Pass configuration that
  /// powers Wallet/Top Up/Choose AI Plan.
  Future<CommercialConfig> getCommercialConfig();

  /// The price-check step before the inspector ever sees an "Analyse"
  /// button they can tap. Never runs AI, never reserves anything.
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  });

  /// The priced AI classification. [idempotencyKey] must be the same
  /// value on any retry of the *same* approval tap (never regenerated),
  /// and a fresh value for a genuine, inspector-initiated "Retry" — see
  /// docs/commercial_model.md ("The estimate -> approval -> reservation
  /// -> settlement protocol").
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  });

  /// Creates a `pending` Top Up payment intent for [amountMyr] — grants
  /// no Credits by itself.
  Future<TopUpIntent> createTopUpIntent(double amountMyr);

  /// Creates a `pending` House Pass purchase intent for [inspectionId]
  /// — activates nothing by itself.
  Future<HousePassPurchaseIntent> purchaseHousePass(String inspectionId);

  /// Confirms a pending intent via the sandbox payment path. Callers
  /// must only ever reach this from a debug/test build's own UI gate —
  /// this method itself still refuses server-side (`failed-precondition`)
  /// if the deployed backend isn't running with `PAYMENTS_MODE=sandbox`.
  Future<SandboxPaymentConfirmation> confirmSandboxPayment(String intentId);
}
