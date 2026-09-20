/// Property/report metadata captured during New Inspection setup (the
/// Basic Details step, between property type and area configuration —
/// see `docs/home_inspection_product_flow.md`), and carried through to
/// the dashboard card, the AI Review/Report Readiness headers, and the
/// generated PDF's cover page.
///
/// Only [unitNumber] is required to start an inspection (see
/// `NewInspectionDraftNotifier.startInspection`, the QA/QC
/// simplification pass) — every other field, including [title], may be
/// left blank at setup time and completed later. A session created
/// before this existed (schema v6 and earlier) has
/// [PropertyDetails.empty] — every display site falls back to the
/// property type's label in that case.
class PropertyDetails {
  const PropertyDetails({
    this.title = '',
    this.address,
    this.projectDeveloperName,
    @Deprecated(
      'Use projectDeveloperName. Kept only to read data saved before '
      'the QA/QC simplification pass merged this with developerName — '
      'see PropertyDetails.resolvedProjectDeveloperName.',
    )
    this.projectName,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    @Deprecated(
      'Use projectDeveloperName. Kept only to read data saved before '
      'the QA/QC simplification pass merged this with projectName — '
      'see PropertyDetails.resolvedProjectDeveloperName.',
    )
    this.developerName,
    this.contactNumber,
    this.inspectionDate,
  });

  /// A session with no property details captured at all — every pre-v7
  /// session, and the default state of a fresh draft before the Basic
  /// Details step is filled in.
  static const empty = PropertyDetails();

  final String title;
  final String? address;

  /// The single "Project / Developer Name" field going forward —
  /// merges what used to be two separate fields ([projectName] and
  /// [developerName]) after QA/QC feedback found the split confusing.
  /// Prefer this field when writing; read [resolvedProjectDeveloperName]
  /// rather than this field directly, so a pre-merge inspection's data
  /// is never silently dropped.
  final String? projectDeveloperName;

  @Deprecated(
    'Use projectDeveloperName/resolvedProjectDeveloperName. Retained '
    'only for inspections saved before the merge.',
  )
  final String? projectName;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;

  @Deprecated(
    'Use projectDeveloperName/resolvedProjectDeveloperName. Retained '
    'only for inspections saved before the merge.',
  )
  final String? developerName;

  /// The client's or their agent's contact number — deferred at setup,
  /// but required before final report generation (see
  /// `ReportCoordinator`/`ReportGenerationOutcome.missingContactNumber`).
  final String? contactNumber;

  /// The inspection's date **and time** — defaults to the moment the
  /// inspector started setup, editable via both a date and a time
  /// picker. A pre-upgrade inspection that only ever had a date keeps
  /// whatever time-of-day was stored then (typically midnight); this
  /// is still a single `DateTime`, so nothing else needs to change to
  /// read it.
  final DateTime? inspectionDate;

  /// Whether *nothing at all* was ever captured — not just a blank
  /// [title] (no longer the sole required field; see the QA/QC
  /// simplification pass). A record with, say, only [unitNumber] set
  /// is real, non-empty data and must never be treated as if setup
  /// never happened (see `buildReportModel`, which uses this to decide
  /// whether to derive report metadata from these details at all).
  bool get isEmpty =>
      title.isEmpty &&
      (address == null || address!.isEmpty) &&
      resolvedProjectDeveloperName == null &&
      (blockTower == null || blockTower!.isEmpty) &&
      (unitNumber == null || unitNumber!.isEmpty) &&
      (clientName == null || clientName!.isEmpty) &&
      (inspectorName == null || inspectorName!.isEmpty) &&
      (contactNumber == null || contactNumber!.isEmpty) &&
      inspectionDate == null;

  /// Resolves the one project/developer name to show, preferring the
  /// new combined [projectDeveloperName] but falling back to the
  /// legacy split [projectName]/[developerName] for an inspection saved
  /// before the merge — combining both if a legacy record genuinely had
  /// both, so neither is silently lost. Null if nothing was ever
  /// captured either way.
  String? get resolvedProjectDeveloperName {
    final combined = projectDeveloperName?.trim();
    if (combined != null && combined.isNotEmpty) return combined;
    // ignore: deprecated_member_use_from_same_package
    final legacyParts = [projectName, developerName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet() // a legacy record where both fields held the same value
        // (e.g. an inspector who typed the project name into both)
        // should read as one name, not a redundant "X / X".
        .toList();
    if (legacyParts.isEmpty) return null;
    return legacyParts.join(' / ');
  }

  PropertyDetails copyWith({
    String? title,
    String? address,
    String? projectDeveloperName,
    String? blockTower,
    String? unitNumber,
    String? clientName,
    String? inspectorName,
    String? contactNumber,
    DateTime? inspectionDate,
  }) {
    return PropertyDetails(
      title: title ?? this.title,
      address: address ?? this.address,
      projectDeveloperName: projectDeveloperName ?? this.projectDeveloperName,
      // ignore: deprecated_member_use_from_same_package
      projectName: projectName,
      blockTower: blockTower ?? this.blockTower,
      unitNumber: unitNumber ?? this.unitNumber,
      clientName: clientName ?? this.clientName,
      inspectorName: inspectorName ?? this.inspectorName,
      // ignore: deprecated_member_use_from_same_package
      developerName: developerName,
      contactNumber: contactNumber ?? this.contactNumber,
      inspectionDate: inspectionDate ?? this.inspectionDate,
    );
  }
}
