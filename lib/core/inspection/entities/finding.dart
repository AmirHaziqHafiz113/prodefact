import 'evidence.dart';
import 'finding_status.dart';

/// A single defect/observation recorded against an element (and,
/// optionally, a specific component) within a [Section], saved as a
/// draft during physical inspection.
///
/// AI review (Phase 6) is modeled separately as `AiSuggestion` records
/// referencing this finding's [id] — see `InspectionSession.aiSuggestions`
/// — rather than embedded here, since a finding's suggestion has its own
/// identity, lifecycle, and persistence independent of the finding text
/// itself.
class Finding {
  const Finding({
    required this.id,
    required this.sectionId,
    required this.elementId,
    required this.createdAt,
    required this.updatedAt,
    this.componentId,
    this.description,
    this.notes,
    this.status = FindingStatus.draft,
    this.evidence = const [],
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

  /// Photos/other evidence attached to this finding.
  final List<Evidence> evidence;

  final DateTime createdAt;
  final DateTime updatedAt;

  Finding copyWith({
    String? description,
    String? notes,
    FindingStatus? status,
    List<Evidence>? evidence,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
