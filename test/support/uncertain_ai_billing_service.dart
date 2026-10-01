import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';

/// A [FakeBillingService] whose AI always answers with a low-confidence
/// guess flagged `needsReview` — the case that is never auto-accepted,
/// so a suggestion stays pending until the inspector resolves it.
class UncertainAiBillingService extends FakeBillingService {
  UncertainAiBillingService({super.initialBalanceCredits});

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final result = await super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
    final c = result.classification;
    return AnalyseFindingResult(
      aiLevel: result.aiLevel,
      creditsCharged: result.creditsCharged,
      newBalance: result.newBalance,
      paymentMode: result.paymentMode,
      classification: AiFindingClassification(
        findingId: c.findingId,
        needsReview: true,
        catalogueEntryId: c.catalogueEntryId,
        confidence: 0.4,
        shortReason: 'Low confidence — please confirm.',
        candidateEntryIds: c.candidateEntryIds,
      ),
    );
  }
}
