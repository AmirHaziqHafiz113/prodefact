import '../entities/ai_level.dart';
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
///
/// Since the commercial pass, this call always runs through the priced
/// `analyseFinding` protocol — see docs/commercial_model.md ("The
/// estimate -> approval -> reservation -> settlement protocol") — and
/// is itself only ever reached *after* that approval has already
/// happened (see `ActiveInspectionSession.approveAndRunAnalysis`),
/// never merely from saving a finding.
abstract class AiClassificationCoordinator {
  /// [reanalyse]: the inspector explicitly asked for a NEW analysis of
  /// a finding that already has a result (or failed) — run it even
  /// though the finding is completed/needs review, under a new request
  /// key, keeping the previous result in the suggestion's history.
  Future<AiClassificationResult> classifyFinding(
    String sessionId,
    String findingId, {
    AiLevel? aiLevel,
    bool reanalyse = false,
  });
}
