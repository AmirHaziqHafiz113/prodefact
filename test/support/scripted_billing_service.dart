import 'dart:async';
import 'dart:collection';

import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';

/// One `analyseFinding` call as the backend received it.
class RecordedAnalysisCall {
  const RecordedAnalysisCall(this.idempotencyKey, this.aiLevel);

  final String idempotencyKey;
  final AiLevel aiLevel;
}

/// What the scripted backend does for the next *new* (not replayed)
/// idempotency key.
enum ScriptedAnalysisStep {
  /// Runs and charges normally, and the client receives the result.
  succeed,

  /// Runs and charges normally, but the response never reaches the
  /// client (e.g. the app was killed or the connection dropped
  /// mid-call). The job is stored, so a replay returns it.
  succeedButLoseResponse,

  /// The request never reached the backend: nothing is stored or
  /// charged, and the client sees an unknown-outcome error.
  neverArrive,

  /// The backend rejects it definitively without charging.
  rejectDefinitively,
}

/// A [BillingService] double that behaves like the real `analyseFinding`
/// backend for idempotency purposes: completed jobs are stored by
/// idempotency key, and a replay of a stored key returns the stored
/// outcome without charging or running the provider again — see
/// `functions/src/billing/handle_analyse_finding.ts`.
///
/// Charging and classification are delegated to a well-funded
/// [FakeBillingService], so [providerRuns] counts exactly how many
/// times real work (and a real charge) happened.
class ScriptedBillingService implements BillingService {
  ScriptedBillingService({List<ScriptedAnalysisStep> steps = const []})
    : _steps = Queue.of(steps);

  final FakeBillingService _inner = FakeBillingService(
    initialBalanceCredits: 100000,
  );
  final Queue<ScriptedAnalysisStep> _steps;
  final Map<String, AnalyseFindingResult> _jobs = {};

  /// Every `analyseFinding` call received, in order, replays included.
  final List<RecordedAnalysisCall> calls = [];

  /// How many calls actually ran the provider and charged.
  int providerRuns = 0;

  /// When set, every call waits for this to complete before answering —
  /// lets a test observe state while a request is still in flight.
  Completer<void>? gate;

  /// Pre-populates a completed job, as if an earlier invocation of
  /// [idempotencyKey] finished on the backend after the app lost track
  /// of it.
  Future<void> completeJobOnBackend({
    required AiFindingClassificationRequest request,
    required String idempotencyKey,
  }) async {
    providerRuns++;
    _jobs[idempotencyKey] = await _inner.analyseFinding(
      request: request,
      aiLevel: AiLevel.smart,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    calls.add(RecordedAnalysisCall(idempotencyKey, aiLevel));
    final pending = gate;
    if (pending != null) await pending.future;

    final stored = _jobs[idempotencyKey];
    if (stored != null) return stored;

    final step = _steps.isEmpty
        ? ScriptedAnalysisStep.succeed
        : _steps.removeFirst();
    switch (step) {
      case ScriptedAnalysisStep.neverArrive:
        throw const AnalyseFindingException(
          'Could not reach the wallet service.',
          outcomeUnknown: true,
        );
      case ScriptedAnalysisStep.rejectDefinitively:
        throw const AnalyseFindingException(
          'AI analysis failed. You have not been charged.',
          outcomeUnknown: false,
        );
      case ScriptedAnalysisStep.succeed:
      case ScriptedAnalysisStep.succeedButLoseResponse:
        providerRuns++;
        final result = await _inner.analyseFinding(
          request: request,
          aiLevel: aiLevel,
          idempotencyKey: idempotencyKey,
        );
        _jobs[idempotencyKey] = result;
        if (step == ScriptedAnalysisStep.succeedButLoseResponse) {
          throw const AnalyseFindingException(
            'The request timed out.',
            outcomeUnknown: true,
          );
        }
        return result;
    }
  }

  @override
  Future<CommercialConfig> getCommercialConfig() =>
      _inner.getCommercialConfig();

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) => _inner.estimateFindingAnalysis(
    inspectionId: inspectionId,
    findingId: findingId,
    aiLevel: aiLevel,
  );

  @override
  Future<TopUpIntent> createTopUpIntent(double amountMyr) =>
      _inner.createTopUpIntent(amountMyr);

  @override
  Future<HousePassPurchaseIntent> purchaseHousePass(String inspectionId) =>
      _inner.purchaseHousePass(inspectionId);

  @override
  Future<SandboxPaymentConfirmation> confirmSandboxPayment(String intentId) =>
      _inner.confirmSandboxPayment(intentId);
}
