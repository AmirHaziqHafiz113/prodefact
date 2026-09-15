import 'ai_review.dart';
import 'evidence.dart';

/// A single defect/observation recorded against an element/component
/// within a [Section], saved as a draft during physical inspection.
///
/// [aiSuggestion] is populated later, once the full inspection is
/// complete and AI review runs across all findings.
class Finding {
  const Finding({
    required this.id,
    required this.sectionId,
    required this.elementId,
    required this.componentId,
    this.description,
    this.evidence = const [],
    this.aiSuggestion,
  });

  final String id;
  final String sectionId;
  final String elementId;
  final String componentId;
  final String? description;
  final List<Evidence> evidence;
  final AiSuggestion? aiSuggestion;

  Finding copyWith({
    String? description,
    List<Evidence>? evidence,
    AiSuggestion? aiSuggestion,
  }) {
    return Finding(
      id: id,
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      description: description ?? this.description,
      evidence: evidence ?? this.evidence,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
    );
  }
}
