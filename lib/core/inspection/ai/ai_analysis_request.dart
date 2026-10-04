/// Structured, redacted context for one finding — everything an AI
/// backend needs to classify it against the controlled defect
/// catalogue, and nothing else. No user account data, no unrelated
/// app state, and (per finding) exactly what a human inspector would
/// have available: the area, whether it's a plumbing area, an
/// quick defect note, and the photos themselves.
class AiFindingClassificationRequest {
  const AiFindingClassificationRequest({
    required this.sessionId,
    required this.findingId,
    required this.sectionName,
    required this.sectionIsPlumbing,
    this.note,
    this.evidenceFilePaths = const [],
    this.evidenceIds = const [],
    this.reanalysisAttempt = 0,
  });

  final String sessionId;
  final String findingId;
  final String sectionName;
  final bool sectionIsPlumbing;

  /// The inspector's quick defect note, verbatim (e.g. "Water leaking when
  /// turned on").
  final String? note;

  /// Local file paths for this finding's evidence photos. Never sent
  /// to any backend — the fake implementation only uses the count,
  /// never file contents, and [FirebaseAiInspectionService] sends
  /// [evidenceIds] instead (opaque ids the callable resolves to actual
  /// images itself, server-side, from the caller's own cloud storage —
  /// see `docs/ai_provider_architecture.md`).
  final List<String> evidenceFilePaths;

  /// This finding's evidence record ids — the only evidence-related
  /// data a real backend actually receives; never a path, a URL, or
  /// bytes.
  final List<String> evidenceIds;

  /// Which explicit inspector "Reanalyse" this is (0 = first analysis).
  /// Sent for analytics/logging only — billing is per request key.
  final int reanalysisAttempt;
}
