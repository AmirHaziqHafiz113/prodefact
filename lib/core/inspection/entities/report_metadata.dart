import 'property_details.dart';

/// The report's cover-page metadata as the inspector confirmed it,
/// reviewed/edited on the Report Details step right before generating —
/// separate from [PropertyDetails] (the original New Inspection setup
/// data) so editing what appears on a report can never corrupt the
/// inspection's own setup record. Defaults to a copy of
/// [PropertyDetails] plus today's date until the inspector explicitly
/// confirms/edits it (see [ReportMetadata.fromPropertyDetails]).
///
/// This is also where a setup field deferred at Basic Details (e.g. the
/// Client / Agent Contact Number — see QA/QC simplification pass) gets
/// completed before finalization: see `ReportGenerationOutcome.
/// missingContactNumber`, which reads [contactNumber] resolved exactly
/// the way this class already resolves every other field.
class ReportMetadata {
  const ReportMetadata({
    required this.title,
    this.projectDeveloperName,
    this.address,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    this.contactNumber,
    this.inspectionDate,
    this.reportDate,
    this.coverPhotoPath,
  });

  final String title;
  final String? projectDeveloperName;
  final String? address;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;

  /// The client's or their agent's contact number — required before a
  /// report can be generated (see `ReportCoordinator`), even though
  /// it's deferrable at Basic Details.
  final String? contactNumber;
  final DateTime? inspectionDate;
  final DateTime? reportDate;

  /// Optional "Residence / Unit Photo" shown on page 1 of the report: a
  /// local file path to a representative photo of the unit. Never a
  /// finding photo, never required.
  final String? coverPhotoPath;

  /// The default a Report Details screen should show before the
  /// inspector has ever confirmed/edited this session's report
  /// metadata — a copy of [PropertyDetails], plus today as the initial
  /// report date.
  factory ReportMetadata.fromPropertyDetails(
    PropertyDetails details, {
    DateTime? reportDate,
  }) {
    return ReportMetadata(
      title: details.title,
      projectDeveloperName: details.resolvedProjectDeveloperName,
      address: details.address,
      blockTower: details.blockTower,
      unitNumber: details.unitNumber,
      clientName: details.clientName,
      inspectorName: details.inspectorName,
      contactNumber: details.contactNumber,
      inspectionDate: details.inspectionDate,
      reportDate: reportDate ?? DateTime.now(),
    );
  }

  ReportMetadata copyWith({
    String? title,
    String? projectDeveloperName,
    String? address,
    String? blockTower,
    String? unitNumber,
    String? clientName,
    String? inspectorName,
    String? contactNumber,
    DateTime? inspectionDate,
    DateTime? reportDate,
    String? coverPhotoPath,
    bool clearCoverPhoto = false,
  }) {
    return ReportMetadata(
      coverPhotoPath: clearCoverPhoto
          ? null
          : (coverPhotoPath ?? this.coverPhotoPath),
      title: title ?? this.title,
      projectDeveloperName: projectDeveloperName ?? this.projectDeveloperName,
      address: address ?? this.address,
      blockTower: blockTower ?? this.blockTower,
      unitNumber: unitNumber ?? this.unitNumber,
      clientName: clientName ?? this.clientName,
      inspectorName: inspectorName ?? this.inspectorName,
      contactNumber: contactNumber ?? this.contactNumber,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      reportDate: reportDate ?? this.reportDate,
    );
  }
}
