import '../entities/ai_finding_status.dart';
import '../entities/ai_review.dart';
import '../entities/finding.dart';
import '../entities/inspection_session.dart';
import '../entities/section_status.dart';

/// Real, count-based AI processing progress for a session — never a
/// fake timer/animation. "Processed" means the finding's AI pipeline
/// reached a terminal state (`completed`, `needsReview`, or `failed`),
/// regardless of whether the inspector has reviewed the result yet —
/// see `AiReviewProgress` for the separate review-completion count.
class AiProcessingProgress {
  const AiProcessingProgress({
    required this.totalEligible,
    required this.processed,
    required this.failed,
    required this.needsReview,
  });

  /// Findings with at least one photo — the only findings AI can ever
  /// act on at all (a finding with no evidence is never queued).
  final int totalEligible;

  /// Findings whose `aiStatus` is a terminal state (completed,
  /// needsReview, or failed) — i.e. no longer notQueued/queued/
  /// uploading/analyzing.
  final int processed;

  final int failed;
  final int needsReview;

  int get inFlight => totalEligible - processed;

  double get fraction => totalEligible == 0 ? 0 : processed / totalEligible;

  int get percent => (fraction * 100).round();

  static AiProcessingProgress of(InspectionSession session) =>
      forFindings(session.findings);

  static AiProcessingProgress forFindings(List<Finding> findings) {
    final eligible = findings.where((f) => f.isAiEligible).toList();
    var processed = 0;
    var failed = 0;
    var needsReview = 0;
    for (final finding in eligible) {
      if (!aiFindingStatusIsInFlight(finding.aiStatus) &&
          finding.aiStatus != AiFindingStatus.notQueued) {
        processed++;
      }
      if (finding.aiStatus == AiFindingStatus.failed) failed++;
      if (finding.aiStatus == AiFindingStatus.needsReview) needsReview++;
    }
    return AiProcessingProgress(
      totalEligible: eligible.length,
      processed: processed,
      failed: failed,
      needsReview: needsReview,
    );
  }
}

/// Real, count-based inspector-review progress: how many AI
/// suggestions have been resolved (accepted/edited/rejected) versus
/// still pending review. Distinct from [AiProcessingProgress] — AI can
/// finish analysing every finding while review is still 0%.
class AiReviewProgress {
  const AiReviewProgress({required this.total, required this.resolved});

  final int total;
  final int resolved;

  int get pending => total - resolved;
  double get fraction => total == 0 ? 0 : resolved / total;
  int get percent => (fraction * 100).round();

  static AiReviewProgress of(InspectionSession session) =>
      forSuggestions(session.aiSuggestions);

  static AiReviewProgress forSuggestions(List<AiSuggestion> suggestions) {
    return AiReviewProgress(
      total: suggestions.length,
      resolved: suggestions.where((s) => s.isResolved).length,
    );
  }
}

/// Physical inspection area-completion progress — independent of both
/// AI progress values above. See `docs/ai_provider_architecture.md`
/// ("Three separate progress axes").
class PhysicalProgress {
  const PhysicalProgress({required this.totalAreas, required this.completed});

  final int totalAreas;
  final int completed;

  double get fraction => totalAreas == 0 ? 0 : completed / totalAreas;
  int get percent => (fraction * 100).round();

  static PhysicalProgress of(InspectionSession session) {
    final included = session.sections.where((s) => s.isIncluded).toList();
    final completed = included
        .where((s) => session.sectionStatuses[s.id] == SectionStatus.completed)
        .length;
    return PhysicalProgress(totalAreas: included.length, completed: completed);
  }
}

/// The single, user-friendly AI state a dashboard/inspection card
/// should show — reconciles processing progress, connectivity, and
/// review progress into one of a small number of plain-language
/// states. See part 4/11 of the camera-first spec.
enum AiCardState {
  /// No AI-eligible findings exist yet (nothing photographed, or
  /// nothing saved yet).
  none,

  /// At least one finding is queued but the app is offline/signed out,
  /// so nothing can actually upload/analyze yet.
  waitingForConnection,

  /// AI is actively working through queued findings.
  analysing,

  /// Every eligible finding has been processed, but at least one
  /// still needs manual review (either a pending suggestion, or a
  /// `needsReview` finding with no final classification yet).
  needsReview,

  /// Every eligible finding is processed and every suggestion is
  /// resolved (accepted/edited/rejected).
  complete,

  /// At least one finding's classification attempt failed and nothing
  /// else is currently in flight — retry is available.
  failed,
}

/// Computes the single card-level [AiCardState] plus the counts a
/// card needs to render "12 of 19 findings analysed · 63%" — pure and
/// synchronous so it's trivially unit-testable without a fake clock or
/// timer (there is no timer: this is a real, recomputed-on-demand
/// count, never an animated/estimated percentage).
class AiCardSummary {
  const AiCardSummary({
    required this.state,
    required this.processing,
    required this.review,
  });

  final AiCardState state;
  final AiProcessingProgress processing;
  final AiReviewProgress review;

  static AiCardSummary of(InspectionSession session, {required bool isOnline}) {
    final processing = AiProcessingProgress.of(session);
    final review = AiReviewProgress.of(session);

    final AiCardState state;
    if (processing.totalEligible == 0) {
      state = AiCardState.none;
    } else if (processing.inFlight > 0) {
      state = isOnline
          ? AiCardState.analysing
          : AiCardState.waitingForConnection;
    } else if (review.pending > 0 || processing.needsReview > 0) {
      state = AiCardState.needsReview;
    } else if (processing.failed > 0) {
      state = AiCardState.failed;
    } else {
      state = AiCardState.complete;
    }

    return AiCardSummary(state: state, processing: processing, review: review);
  }
}
