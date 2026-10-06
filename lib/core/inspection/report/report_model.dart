/// One finding as it should appear in the printed report — already
/// resolved to the inspector's **final** values (see
/// `docs/report.md#final-value-precedence`). Never the raw AI
/// suggestion when the inspector edited or rejected/corrected it.
class ReportFinding {
  const ReportFinding({
    required this.number,
    required this.elementName,
    this.componentName,
    this.defectType,
    this.recommendation,
    this.notes,
    this.evidenceFilePaths = const [],
  });

  /// Sequential position across the *whole* report (not reset per
  /// area) — the "No" column in the reference report format.
  final int number;

  final String elementName;
  final String? componentName;
  final String? defectType;
  final String? recommendation;
  final String? notes;
  final List<String> evidenceFilePaths;
}

/// One inspection area's worth of report content. [findings] is
/// deliberately allowed to be empty — a completed area with nothing
/// wrong is represented explicitly ("No defects recorded"), never
/// silently omitted.
class ReportAreaSection {
  const ReportAreaSection({
    required this.name,
    required this.isPlumbing,
    this.findings = const [],
    this.note,
  });

  final String name;
  final bool isPlumbing;
  final List<ReportFinding> findings;

  /// The area's contextual note (`Section.note`), if any — rendered
  /// under this area's heading, distinct from any finding.
  final String? note;
}

/// A fully resolved, print-ready representation of one inspection —
/// the typed model a [ReportRenderer] turns into PDF bytes. Nothing in
/// this file (or anything it depends on) knows about PDF, or any other
/// output format — see `docs/report.md`.
class ReportModel {
  const ReportModel({
    required this.sessionId,
    required this.propertyTypeLabel,
    required this.inspectionDate,
    required this.generatedAt,
    required this.totalAreas,
    required this.completedAreas,
    required this.totalFindings,
    required this.totalEvidence,
    required this.areas,
    this.version = 1,
    this.propertyTitle,
    this.propertyAddress,
    this.projectDeveloperName,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    this.contactNumber,
    this.reportDate,
    this.inspectionNote,
    this.coverPhotoPath,
  });

  /// The optional Residence / Unit Photo for page 1 (local file path).
  final String? coverPhotoPath;

  final String sessionId;
  final String propertyTypeLabel;
  final DateTime inspectionDate;
  final DateTime generatedAt;
  final int totalAreas;
  final int completedAreas;
  final int totalFindings;
  final int totalEvidence;
  final List<ReportAreaSection> areas;

  /// This report's version number — see `Report.version`.
  final int version;

  // ---- property/report metadata (from the inspector-confirmed
  // `ReportMetadata`, falling back to `PropertyDetails`) — all null for
  // a session with neither captured (schema v6 and earlier); the
  // renderer falls back to [propertyTypeLabel] in that case.
  final String? propertyTitle;
  final String? propertyAddress;
  final String? projectDeveloperName;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;

  /// The client's or their agent's contact number — required before
  /// generation reaches this model at all (see
  /// `ReportGenerationOutcome.missingContactNumber`), so always present
  /// here even though it's optional at setup time.
  final String? contactNumber;

  /// The confirmed report date (distinct from [generatedAt], the actual
  /// render timestamp) — see `ReportMetadata.reportDate`.
  final DateTime? reportDate;

  /// The whole-inspection contextual note (`InspectionSession.
  /// inspectionNote`), if any — rendered in the report's summary/
  /// information section.
  final String? inspectionNote;
}
