import 'ai_analysis_attempt.dart';
import 'ai_finding_status.dart';
import 'evidence.dart';
import 'finding_status.dart';

/// A single defect/observation recorded against a [Section] ("area"),
/// saved as a draft during physical inspection.
///
/// Camera-first model: the inspector takes a photo, optionally adds a
/// short side note, and saves — that's it. [elementId]/[componentId]
/// (the property's own configured element/component template) are
/// **not** chosen by the inspector up front any more; they're left
/// null for every finding created this way. Classification (which
/// main element, which component, which defect from the controlled
/// catalogue) is instead performed by AI and reviewed by the inspector
/// — see `AiSuggestion.suggestedCatalogueEntryId`/`finalCatalogueEntryId`
/// and `docs/ai_provider_architecture.md`.
///
/// [elementId]/[componentId] are kept, still nullable, purely for
/// backward compatibility with findings created under the old
/// component-first workflow (schema v5 and earlier) — a legacy finding
/// still has them set, still renders correctly, and is never migrated
/// or discarded; see `docs/production_readiness.md` ("Camera-first
/// migration").
///
/// AI review is modeled separately as `AiSuggestion` records
/// referencing this finding's [id] — see `InspectionSession.aiSuggestions`
/// — rather than embedded here, since a finding's suggestion has its own
/// identity, lifecycle, and persistence independent of the finding text
/// itself.
class Finding {
  const Finding({
    required this.id,
    required this.sectionId,
    required this.createdAt,
    required this.updatedAt,
    this.elementId,
    this.componentId,
    this.description,
    this.notes,
    this.status = FindingStatus.draft,
    this.evidence = const [],
    this.aiStatus = AiFindingStatus.notQueued,
    this.aiAttempt,
  });

  final String id;
  final String sectionId;

  /// Legacy-only — see the class doc comment. Always null for a
  /// finding created by the camera-first flow.
  final String? elementId;

  /// Legacy-only — see the class doc comment. Always null for a
  /// finding created by the camera-first flow.
  final String? componentId;

  /// The inspector's optional short side note (e.g. "Water leaking
  /// when turned on"). Free text, never required to save.
  final String? description;

  /// Free-form inspector notes.
  final String? notes;

  final FindingStatus status;

  /// Photos/other evidence attached to this finding.
  final List<Evidence> evidence;

  /// Where this finding stands in the progressive AI pipeline — see
  /// `AiFindingStatus`.
  final AiFindingStatus aiStatus;

  /// The outstanding AI analysis request for this finding, if one may
  /// still be unresolved on the backend — see [AiAnalysisAttempt].
  /// Loaded from storage and written only through the repository's
  /// dedicated attempt methods, never through `saveFinding`, so an
  /// unrelated edit (e.g. the side note) can never erase it.
  final AiAnalysisAttempt? aiAttempt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this finding has at least one photo and is therefore
  /// eligible to be queued for AI classification at all.
  bool get isAiEligible => evidence.isNotEmpty;

  /// The inspector's quick defect note (QA #16), verbatim — never
  /// normalized here, so the original wording is kept for audit and
  /// the report. Shorthand is interpreted by the AI prompt instead.
  String? get defectNote {
    final note = description?.trim().isNotEmpty == true ? description : notes;
    final trimmed = note?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// AI only starts once a quick defect note exists (QA #16): the note
  /// tells AI what the inspector is pointing at. Capturing and saving
  /// the finding never requires one.
  bool get hasDefectNote => defectNote != null;

  Finding copyWith({
    String? description,
    String? notes,
    FindingStatus? status,
    List<Evidence>? evidence,
    AiFindingStatus? aiStatus,
    DateTime? updatedAt,
  }) {
    return Finding(
      id: id,
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      evidence: evidence ?? this.evidence,
      aiStatus: aiStatus ?? this.aiStatus,
      aiAttempt: aiAttempt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
