import 'ai_analysis_result.dart';

/// Application-layer orchestrator for one finding's progressive AI
/// classification.
///
/// Unlike the old whole-session batch flow, this is **not** gated on
/// physical inspection completion — [classifyFinding] runs as soon as
/// it's called (immediately after a finding is saved with at least one
/// photo), so AI can work through Section A's findings while the
/// inspector is already physically inspecting Section B. It never
/// runs merely because a photo was captured or a note is being
/// edited — only an explicit, already-saved finding is ever passed in.
/// See `docs/ai_provider_architecture.md` ("Progressive per-finding AI
/// pipeline").
abstract class AiClassificationCoordinator {
  Future<AiClassificationResult> classifyFinding(
    String sessionId,
    String findingId,
  );
}
