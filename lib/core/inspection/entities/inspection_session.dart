import 'ai_review.dart';
import 'ai_review_state.dart';
import 'finding.dart';
import 'industry.dart';
import 'inspection.dart';
import 'report.dart';
import 'section.dart';
import 'section_status.dart';
import 'sync_status.dart';

/// The full durable state of one inspection: its configured sections,
/// per-section physical-inspection progress, and findings, plus identity
/// and lifecycle metadata.
///
/// This is the aggregate the local repository persists and reloads as a
/// whole — the in-memory Riverpod providers mirror it, writing through
/// on every change so the database stays the single source of truth.
class InspectionSession {
  const InspectionSession({
    required this.id,
    required this.industry,
    required this.assetTypeId,
    required this.sections,
    required this.sectionStatuses,
    required this.findings,
    required this.createdAt,
    required this.updatedAt,
    this.status = InspectionStatus.inProgress,
    this.syncStatus = SyncStatus.localOnly,
    this.ownerUid,
    this.aiReviewState = AiReviewState.notStarted,
    this.aiSuggestions = const [],
    this.report,
  });

  final String id;
  final Industry industry;

  /// Identifies the asset type within [industry] (for Home Inspection,
  /// the property type's name — see `PropertyType`).
  final String assetTypeId;

  final List<Section> sections;
  final Map<String, SectionStatus> sectionStatuses;
  final List<Finding> findings;
  final InspectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  /// The state of the whole-session AI analysis run — see
  /// `docs/ai_review.md`. Gates whether analysis can run and whether
  /// the inspection can proceed to reporting.
  final AiReviewState aiReviewState;

  /// Every AI suggestion generated for this session's findings, each
  /// referencing a `Finding.id`. Populated only after physical
  /// inspection completes and analysis has run.
  final List<AiSuggestion> aiSuggestions;

  /// The most recently generated PDF report for this session, if any —
  /// see `docs/report.md` for the "latest report per inspection" policy.
  final Report? report;

  /// The authenticated user this session belongs to, if any. Null means
  /// a "guest" session created while signed out — see the ownership
  /// policy in `docs/firebase.md`. Cloud sync only ever touches sessions
  /// owned by the currently signed-in user.
  final String? ownerUid;

  /// Whether physical inspection (and beyond) has finished — i.e. this
  /// is no longer an inspection the inspector needs to resume working
  /// physical areas on.
  bool get isComplete => status != InspectionStatus.inProgress;

  InspectionSession copyWith({
    List<Section>? sections,
    Map<String, SectionStatus>? sectionStatuses,
    List<Finding>? findings,
    InspectionStatus? status,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? ownerUid,
    AiReviewState? aiReviewState,
    List<AiSuggestion>? aiSuggestions,
    Report? report,
  }) {
    return InspectionSession(
      id: id,
      industry: industry,
      assetTypeId: assetTypeId,
      sections: sections ?? this.sections,
      sectionStatuses: sectionStatuses ?? this.sectionStatuses,
      findings: findings ?? this.findings,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      ownerUid: ownerUid ?? this.ownerUid,
      aiReviewState: aiReviewState ?? this.aiReviewState,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      report: report ?? this.report,
    );
  }
}

/// A lightweight view of an [InspectionSession] for list/resume screens,
/// without loading every section/finding.
class InspectionSessionSummary {
  const InspectionSessionSummary({
    required this.id,
    required this.industry,
    required this.assetTypeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.localOnly,
    this.ownerUid,
    this.aiEligibleFindingsCount = 0,
    this.aiProcessedFindingsCount = 0,
    this.aiPendingReviewCount = 0,
  });

  final String id;
  final Industry industry;
  final String assetTypeId;
  final InspectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? ownerUid;

  /// Cheap, dashboard-card-sized AI progress counts — see
  /// `AiProcessingProgress`/`AiReviewProgress` for the full-session
  /// equivalents. Computed by the repository alongside the summary
  /// itself so the dashboard never needs to load every session's full
  /// findings/suggestions just to show a progress bar.
  final int aiEligibleFindingsCount;
  final int aiProcessedFindingsCount;
  final int aiPendingReviewCount;

  bool get isComplete => status != InspectionStatus.inProgress;
}
