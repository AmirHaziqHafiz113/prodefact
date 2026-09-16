/// Structured, redacted context for one finding — everything an AI
/// backend needs to suggest a defect/recommendation, and nothing else.
/// No user account data, no unrelated app state.
class AiFindingContext {
  const AiFindingContext({
    required this.findingId,
    required this.sectionId,
    required this.sectionName,
    required this.sectionIsPlumbing,
    required this.elementId,
    required this.elementName,
    this.componentId,
    this.componentName,
    this.description,
    this.notes,
    this.evidenceFilePaths = const [],
    this.evidenceIds = const [],
  });

  final String findingId;
  final String sectionId;
  final String sectionName;
  final bool sectionIsPlumbing;
  final String elementId;
  final String elementName;
  final String? componentId;
  final String? componentName;

  /// The inspector's defect/observation text.
  final String? description;

  /// The inspector's free-form notes.
  final String? notes;

  /// Local file paths for this finding's evidence photos. Never sent
  /// to any backend — the fake implementation only uses the count,
  /// never file contents, and [FirebaseAiInspectionService] sends
  /// [evidenceIds] instead (opaque ids the callable resolves to actual
  /// images itself, server-side, from the caller's own cloud storage —
  /// see `docs/ai_provider_architecture.md`, "Multimodal evidence
  /// resolution"). Kept for the fake/local-only path and for the
  /// evidence *count* the request also carries.
  final List<String> evidenceFilePaths;

  /// This finding's evidence record ids, in the same order as
  /// [evidenceFilePaths] — the only evidence-related data a real
  /// backend actually receives; never a path, a URL, or bytes.
  final List<String> evidenceIds;
}

/// One session's worth of AI analysis input — a batch of findings that
/// still need a suggestion, plus enough session-level context to
/// interpret them (property type, industry).
class AiAnalysisRequest {
  const AiAnalysisRequest({
    required this.sessionId,
    required this.industry,
    required this.assetTypeId,
    required this.findings,
  });

  final String sessionId;
  final String industry;
  final String assetTypeId;
  final List<AiFindingContext> findings;
}
