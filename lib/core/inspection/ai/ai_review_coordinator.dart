import 'ai_analysis_result.dart';

/// Application-layer gate + orchestrator for post-inspection AI review.
///
/// This is where the AI timing rule is enforced in code (not just by
/// hiding a button): [runAnalysis] must refuse to run — returning a
/// controlled [AiAnalysisResult], never performing analysis — unless
/// the session's physical inspection is already complete. See
/// `docs/ai_review.md`.
abstract class AiReviewCoordinator {
  Future<AiAnalysisResult> runAnalysis(String sessionId);
}
