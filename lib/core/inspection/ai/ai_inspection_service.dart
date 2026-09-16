import 'ai_analysis_request.dart';
import 'ai_analysis_response.dart';

/// Provider-neutral AI backend abstraction.
///
/// Nothing in the app calls an AI provider (OpenAI, Gemini, DeepSeek,
/// etc.) directly, and no provider API key ever lives in Flutter — see
/// `docs/ai_provider_architecture.md`. [classifyFinding] analyzes
/// exactly one finding (its area context, optional note, and photos)
/// and returns one classification against the controlled defect
/// catalogue — this is what makes AI analysis progressive: one finding
/// saved, one independent classification job, rather than a single
/// batch call over an entire completed inspection.
abstract class AiInspectionService {
  Future<AiFindingClassification> classifyFinding(
    AiFindingClassificationRequest request,
  );
}
