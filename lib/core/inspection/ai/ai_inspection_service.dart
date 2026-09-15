import 'ai_analysis_request.dart';
import 'ai_analysis_response.dart';

/// Provider-neutral AI backend abstraction.
///
/// Nothing in the app calls an AI provider (OpenAI, Gemini, DeepSeek,
/// etc.) directly, and no provider API key ever lives in Flutter — see
/// `docs/ai_review.md` for the production backend-gateway design this
/// is meant to sit in front of. For now, [analyze] is satisfied by a
/// deterministic fake/demo implementation with no network access.
abstract class AiInspectionService {
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request);
}
