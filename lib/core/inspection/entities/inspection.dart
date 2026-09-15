enum InspectionStatus {
  /// Areas are being configured and the inspector is walking through the
  /// physical inspection, saving findings as drafts.
  inProgress,

  /// All applicable sections are finished; AI review can now run.
  physicalInspectionComplete,

  /// AI review has been completed and accepted/edited/rejected by the
  /// inspector for every finding.
  aiReviewComplete,

  /// The final report has been generated.
  reported,
}

/// The root aggregate for one inspection job, generic across industries.
class Inspection {
  const Inspection({
    required this.id,
    required this.assetTypeId,
    required this.sectionIds,
    this.status = InspectionStatus.inProgress,
  });

  final String id;
  final String assetTypeId;
  final List<String> sectionIds;
  final InspectionStatus status;

  Inspection copyWith({List<String>? sectionIds, InspectionStatus? status}) {
    return Inspection(
      id: id,
      assetTypeId: assetTypeId,
      sectionIds: sectionIds ?? this.sectionIds,
      status: status ?? this.status,
    );
  }
}
