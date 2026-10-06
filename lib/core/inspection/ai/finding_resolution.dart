import '../entities/ai_finding_status.dart';
import '../entities/ai_review.dart';
import '../entities/finding.dart';

/// The traffic-light colour of a finding card.
enum FindingTone {
  /// A valid result is in place (AI auto-accepted, or the inspector chose
  /// or confirmed it) — report-ready.
  green,

  /// Still being worked on, or needs the inspector to pick a defect.
  orange,

  /// Failed, or unresolved after a rejection — never report-ready.
  red,
}

enum FindingResolutionState {
  /// Queued / uploading / analysing / waiting for its note.
  processing,
  autoAccepted,
  confirmedByInspector,

  /// AI answered but wasn't sure enough: the inspector must choose.
  needsReview,

  /// The inspector rejected the result and chose nothing else.
  unresolved,

  /// The AI request failed, or finished with nothing usable.
  failed,
}

class FindingResolution {
  const FindingResolution(this.state);

  final FindingResolutionState state;

  FindingTone get tone => switch (state) {
    FindingResolutionState.autoAccepted ||
    FindingResolutionState.confirmedByInspector => FindingTone.green,
    FindingResolutionState.processing ||
    FindingResolutionState.needsReview => FindingTone.orange,
    FindingResolutionState.unresolved ||
    FindingResolutionState.failed => FindingTone.red,
  };

  /// Report-ready: has a valid final classification.
  bool get isResolved => tone == FindingTone.green;

  /// Whether the inspector may pick a defect by hand right now (never
  /// while a request is actually running, so a late answer cannot
  /// overwrite their choice).
  static bool canPickManually(Finding finding) =>
      finding.aiStatus != AiFindingStatus.uploading &&
      finding.aiStatus != AiFindingStatus.analyzing;
}

/// The ONE place a finding's colour/state is derived — from the finding's
/// pipeline status and its (current) suggestion — so the Area card, AI
/// Review and report readiness can never disagree.
FindingResolution resolutionOf(Finding finding, AiSuggestion? suggestion) {
  // A running (re)analysis outranks whatever result is currently shown.
  if (aiFindingStatusIsInFlight(finding.aiStatus)) {
    return const FindingResolution(FindingResolutionState.processing);
  }
  if (suggestion != null) {
    if (suggestion.isRejected) {
      return const FindingResolution(FindingResolutionState.unresolved);
    }
    if (!suggestion.isResolved) {
      return const FindingResolution(FindingResolutionState.needsReview);
    }
    return FindingResolution(
      suggestion.isAutoAccepted
          ? FindingResolutionState.autoAccepted
          : FindingResolutionState.confirmedByInspector,
    );
  }
  return switch (finding.aiStatus) {
    AiFindingStatus.notQueued || AiFindingStatus.awaitingApproval =>
      const FindingResolution(FindingResolutionState.processing),
    _ => const FindingResolution(FindingResolutionState.failed),
  };
}
