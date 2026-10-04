import '../entities/ai_review.dart';

/// A short, helpful line about the photo itself from the AI's own
/// assessment (the same request that classified it), or null when there
/// is nothing worth saying. Informational only — the inspector decides
/// whether to retake; nothing is ever forced.
String? aiImageQualityNote(AiSuggestion? suggestion) {
  if (suggestion == null) return null;
  if (suggestion.isRelevantInspectionImage == false ||
      suggestion.qualityIssues.contains('unrelated')) {
    return 'Image appears unrelated to the inspection.';
  }
  final issues = suggestion.qualityIssues;
  if (issues.isEmpty && suggestion.imageUsable != false) return null;
  final described = issues.isEmpty
      ? 'Photo was hard to interpret'
      : _issueText[issues.first] ?? 'Photo is unclear';
  return 'Image quality warning: $described. Consider retaking if a '
      'clearer image is available.';
}

const _issueText = {
  'blur': 'Photo is blurry',
  'too_dark': 'Photo is too dark',
  'overexposed': 'Photo is overexposed',
  'subject_too_small': 'The defect looks very small in the photo',
  'obstructed': 'The defect is partly blocked from view',
  'insufficient_context': 'The photo shows too little surrounding context',
  'unclear': 'Photo is unclear',
};
