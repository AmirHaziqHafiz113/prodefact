import '../entities/ai_finding_status.dart';
import '../entities/ai_review.dart';
import '../entities/finding.dart';
import '../entities/inspection_session.dart';
import '../entities/section.dart';
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

/// Where one suggested area stands in the physical inspection.
///
/// Suggested areas are only a guide: a unit often lacks some of them
/// (no balcony, two bedrooms instead of three). An area therefore only
/// counts toward the inspection once the inspector has actually
/// worked in it — see `docs/ai_provider_architecture.md` ("Three
/// separate progress axes").
enum AreaVisitState {
  /// Suggested but never touched: no findings, never marked in progress
  /// or complete. Never blocks completion and never appears in the
  /// report as "No defects recorded".
  untouched,

  /// The inspector has worked here (a finding exists, an area note was
  /// written, or the area was marked in progress) but has not marked it
  /// complete yet.
  started,

  /// Explicitly marked complete — including an area inspected and
  /// found to have no defects.
  completed,
}

/// The [AreaVisitState] of [section] within [session].
AreaVisitState areaVisitStateOf(InspectionSession session, Section section) {
  final status = session.sectionStatuses[section.id] ?? SectionStatus.notStarted;
  if (status == SectionStatus.completed) return AreaVisitState.completed;
  if (status == SectionStatus.inProgress) return AreaVisitState.started;
  final hasFinding = session.findings.any((f) => f.sectionId == section.id);
  final hasNote = section.note?.trim().isNotEmpty ?? false;
  return hasFinding || hasNote
      ? AreaVisitState.started
      : AreaVisitState.untouched;
}

/// Included areas the inspector actually worked in (started or
/// completed), in their configured order — the areas a report covers.
List<Section> inspectedAreasOf(InspectionSession session) => [
  for (final section in session.sections)
    if (section.isIncluded &&
        areaVisitStateOf(session, section) != AreaVisitState.untouched)
      section,
];

/// Physical inspection progress over the areas the inspector actually
/// chose to inspect — independent of both AI progress values above.
/// Untouched suggested areas are reported separately and never count
/// against completion.
class PhysicalProgress {
  const PhysicalProgress({
    required this.totalAreas,
    required this.completed,
    this.untouchedSuggested = 0,
  });

  /// Areas started or completed.
  final int totalAreas;

  /// Areas marked complete.
  final int completed;

  /// Suggested areas never visited (optional; ignored for completion).
  final int untouchedSuggested;

  int get started => totalAreas - completed;
  double get fraction => totalAreas == 0 ? 0 : completed / totalAreas;
  int get percent => (fraction * 100).round();

  /// The physical site visit can be completed once at least one area has
  /// been inspected. Nothing else is required: not every suggested area,
  /// not AI, not review — see [canCompletePhysicalInspection].
  bool get canComplete => totalAreas > 0;

  static PhysicalProgress of(InspectionSession session) {
    var inspected = 0;
    var completed = 0;
    var untouched = 0;
    for (final section in session.sections.where((s) => s.isIncluded)) {
      switch (areaVisitStateOf(session, section)) {
        case AreaVisitState.untouched:
          untouched++;
        case AreaVisitState.started:
          inspected++;
        case AreaVisitState.completed:
          inspected++;
          completed++;
      }
    }
    return PhysicalProgress(
      totalAreas: inspected,
      completed: completed,
      untouchedSuggested: untouched,
    );
  }
}

/// Whether the physical site inspection can be completed: at least one
/// area inspected. AI processing, inspector review, untouched suggested
/// areas, and report fields never block it — those gate the report
/// instead (see `DefaultReportCoordinator`).
bool canCompletePhysicalInspection(InspectionSession session) =>
    PhysicalProgress.of(session).canComplete;

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
