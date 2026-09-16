/// Where one [AiSuggestion] stands in the inspector's review.
///
/// `pending` suggestions are what gate report readiness — see
/// `InspectionSession.aiReviewState` and `docs/ai_review.md`.
///
/// `rejected` doubles as "mark unresolved": the inspector disagreed
/// with the AI (or there was nothing to agree/disagree with — a
/// `needsReview` case) and did not provide a replacement classification
/// either. It is still a *resolved*, reviewed state (unlike `pending`)
/// — the report renders it as an explicit "Unresolved — pending manual
/// classification" line rather than blocking generation or silently
/// dropping the finding. The inspector can still return later and
/// pick a catalogue entry via Change, which moves it to `edited`.
enum AiSuggestionStatus { pending, accepted, edited, rejected }

/// AI's advisory classification for a [Finding] against the controlled
/// defect catalogue (`DefectCatalogue`), generated progressively as
/// soon as the finding is saved — never gated on the rest of the
/// physical inspection being complete. See
/// `docs/ai_provider_architecture.md` ("Progressive per-finding AI
/// pipeline", "Controlled defect catalogue").
///
/// The original AI output (`suggested*`) is immutable once generated and
/// is never overwritten by inspector review — the inspector's
/// accepted/edited/corrected values live separately in the `final*`
/// fields. Both are preserved together for later audit/evaluation.
class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.sessionId,
    required this.findingId,
    required this.providerId,
    required this.generatedAt,
    this.suggestedCatalogueEntryId,
    this.suggestedConfidence,
    this.suggestedShortReason,
    this.suggestedCandidateEntryIds = const [],
    this.finalCatalogueEntryId,
    this.status = AiSuggestionStatus.pending,
    this.reviewedAt,
    this.legacyFinalElementId,
    this.legacyFinalComponentId,
    this.legacyFinalDefectType,
    this.legacyFinalRecommendation,
    this.legacyFinalNotes,
  });

  final String id;
  final String sessionId;
  final String findingId;

  /// Identifies which AI backend/model produced this suggestion (e.g.
  /// `deepseek`, `fake-demo-v2`). Never a provider SDK type — just an
  /// identifying string for evaluation/debugging.
  final String providerId;

  final DateTime generatedAt;

  // ---- original AI output — never mutated after generation ----

  /// The catalogue entry id AI selected, or null if it could not
  /// confidently classify (`needsReview`) — see
  /// `DefectCatalogue.isValidEntryId`. Always either null or a
  /// genuinely valid catalogue id: the backend rejects/discards a
  /// hallucinated id before this is ever constructed, never trusting
  /// AI-provided text for the main element/component/defect/corrective
  /// action, which are always resolved from the catalogue by id.
  final String? suggestedCatalogueEntryId;

  /// 0.0-1.0, if the provider reported one.
  final double? suggestedConfidence;

  /// A short, plain-language reason (not a technical diagnostic
  /// paragraph) — see `docs/ai_provider_architecture.md` ("Simplified
  /// AI language").
  final String? suggestedShortReason;

  /// Ranked alternative catalogue entries, when AI found more than one
  /// plausible match — every id here is independently validated
  /// against the catalogue the same way `suggestedCatalogueEntryId` is.
  final List<String> suggestedCandidateEntryIds;

  // ---- inspector-reviewed / final value ----

  /// The catalogue entry the inspector approved (Accept: same as
  /// `suggestedCatalogueEntryId`) or picked themselves (Change) —
  /// null/empty while still pending. An empty string (rather than
  /// null) after Reject/mark-unresolved deliberately marks "reviewed,
  /// but no entry chosen" — see `hasFinalEntry`; this mirrors the
  /// established convention elsewhere in this class of using an empty
  /// string as an explicit "cleared" value so `copyWith`'s `??`
  /// pattern can distinguish "leave unchanged" (omit the parameter)
  /// from "clear it" (pass `''`).
  final String? finalCatalogueEntryId;

  final AiSuggestionStatus status;
  final DateTime? reviewedAt;

  bool get isResolved => status != AiSuggestionStatus.pending;

  /// Whether [finalCatalogueEntryId] is a real, chosen entry (as
  /// opposed to null/empty).
  bool get hasFinalEntry =>
      finalCatalogueEntryId != null && finalCatalogueEntryId!.isNotEmpty;

  /// Whether AI found no confident match at all — the inspector must
  /// classify this one manually (via the searchable catalogue picker)
  /// rather than having anything to Accept.
  bool get needsReview => suggestedCatalogueEntryId == null;

  // ---- legacy (pre-v6, free-text, component-first) fields ----
  //
  // Populated only when decoding a suggestion row created under the
  // old whole-session batch workflow (before the controlled defect
  // catalogue existed) — never written by any current code path, kept
  // solely so a legacy inspection's report/history still shows the
  // inspector's actual approved AI review text instead of silently
  // losing it. See `docs/production_readiness.md` ("Camera-first
  // migration").
  final String? legacyFinalElementId;
  final String? legacyFinalComponentId;
  final String? legacyFinalDefectType;
  final String? legacyFinalRecommendation;
  final String? legacyFinalNotes;

  AiSuggestion copyWith({
    String? finalCatalogueEntryId,
    AiSuggestionStatus? status,
    DateTime? reviewedAt,
  }) {
    return AiSuggestion(
      id: id,
      sessionId: sessionId,
      findingId: findingId,
      providerId: providerId,
      generatedAt: generatedAt,
      suggestedCatalogueEntryId: suggestedCatalogueEntryId,
      suggestedConfidence: suggestedConfidence,
      suggestedShortReason: suggestedShortReason,
      suggestedCandidateEntryIds: suggestedCandidateEntryIds,
      finalCatalogueEntryId:
          finalCatalogueEntryId ?? this.finalCatalogueEntryId,
      status: status ?? this.status,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      legacyFinalElementId: legacyFinalElementId,
      legacyFinalComponentId: legacyFinalComponentId,
      legacyFinalDefectType: legacyFinalDefectType,
      legacyFinalRecommendation: legacyFinalRecommendation,
      legacyFinalNotes: legacyFinalNotes,
    );
  }
}
