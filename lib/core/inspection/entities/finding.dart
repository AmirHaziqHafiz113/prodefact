import 'ai_review.dart';
import 'evidence.dart';
import 'finding_status.dart';

/// A single defect/observation recorded against an element (and,
/// optionally, a specific component) within a [Section], saved as a
/// draft during physical inspection.
///
/// [aiSuggestion] is populated later, once the full inspection is
/// complete and AI review runs across all findings.
class Finding {
  const Finding({
    required this.id,
    required this.sectionId,
    required this.elementId,
    this.componentId,
    this.description,
    this.notes,
    this.status = FindingStatus.draft,
    this.evidence = const [],
    this.aiSuggestion,
  });

  final String id;
  final String sectionId;
  final String elementId;

  /// The specific component this finding is about, if the inspector
  /// narrowed it down beyond the element level.
  final String? componentId;

  /// Short defect/observation text.
  final String? description;

  /// Free-form inspector notes.
  final String? notes;

  final FindingStatus status;

  /// Photos/other evidence attached to this finding. Empty for now —
  /// capture is implemented in a later phase.
  final List<Evidence> evidence;

  final AiSuggestion? aiSuggestion;

  Finding copyWith({
    String? description,
    String? notes,
    FindingStatus? status,
    List<Evidence>? evidence,
    AiSuggestion? aiSuggestion,
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
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
    );
  }
}
