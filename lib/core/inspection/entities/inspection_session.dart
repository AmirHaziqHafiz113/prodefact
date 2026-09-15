import 'finding.dart';
import 'industry.dart';
import 'inspection.dart';
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
  });

  final String id;
  final Industry industry;
  final String assetTypeId;
  final InspectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComplete => status != InspectionStatus.inProgress;
}
