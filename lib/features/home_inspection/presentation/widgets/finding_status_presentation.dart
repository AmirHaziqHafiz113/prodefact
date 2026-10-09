import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';

/// A finding's chip, from the ONE resolution rule ([resolutionOf]) the
/// Area card, Finding Detail and AI Review all share.
(AppStatus status, String label) findingStatusOf(
  Finding finding,
  AiSuggestion? suggestion,
) {
  final resolution = resolutionOf(finding, suggestion);
  return switch (resolution.state) {
    FindingResolutionState.autoAccepted => (
      AppStatus.confirmed,
      'Accepted by AI',
    ),
    FindingResolutionState.confirmedByInspector => (
      AppStatus.confirmed,
      'Confirmed',
    ),
    FindingResolutionState.processing =>
      finding.aiStatus == AiFindingStatus.awaitingApproval &&
              !finding.hasDefectNote
          ? (AppStatus.needsReview, 'Needs a note')
          : aiFindingStatusIsInFlight(finding.aiStatus)
          ? (AppStatus.analysing, 'Analysing')
          : (AppStatus.queued, 'In progress'),
    FindingResolutionState.needsReview => (
      AppStatus.needsReview,
      'Needs your choice',
    ),
    FindingResolutionState.unresolved => (AppStatus.rejected, 'Unresolved'),
    FindingResolutionState.failed => (AppStatus.failed, 'Needs attention'),
  };
}

/// Whether [finding] belongs in the AI Review inbox: the inspector has
/// to do something (choose a defect, settle a rejected or failed result,
/// or add the note AI is waiting for). Confirmed and still-processing
/// findings never clutter it.
bool findingNeedsAttention(Finding finding, AiSuggestion? suggestion) {
  if (!finding.isAiEligible) return false;
  final state = resolutionOf(finding, suggestion).state;
  return switch (state) {
    FindingResolutionState.needsReview ||
    FindingResolutionState.unresolved ||
    FindingResolutionState.failed => true,
    FindingResolutionState.processing =>
      finding.aiStatus == AiFindingStatus.awaitingApproval &&
          !finding.hasDefectNote,
    _ => false,
  };
}

/// [finding]'s current suggestion (the one review decides on), if any.
AiSuggestion? suggestionFor(InspectionSession session, Finding finding) {
  for (final s in activeSuggestionsOf(session)) {
    if (s.findingId == finding.id) return s;
  }
  return null;
}
