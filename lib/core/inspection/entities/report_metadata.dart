import 'property_details.dart';

/// The report's cover-page metadata as the inspector confirmed it,
/// reviewed/edited on the Report Details step right before generating —
/// separate from [PropertyDetails] (the original New Inspection setup
/// data) so editing what appears on a report can never corrupt the
/// inspection's own setup record. Defaults to a copy of
/// [PropertyDetails] plus today's date until the inspector explicitly
/// confirms/edits it (see [ReportMetadata.fromPropertyDetails]).
class ReportMetadata {
  const ReportMetadata({
    required this.title,
    this.projectName,
    this.address,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    this.inspectionDate,
    this.reportDate,
  });

  final String title;
  final String? projectName;
  final String? address;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;
  final DateTime? inspectionDate;
  final DateTime? reportDate;

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
      projectName: details.projectName,
      address: details.address,
      blockTower: details.blockTower,
      unitNumber: details.unitNumber,
      clientName: details.clientName,
      inspectorName: details.inspectorName,
      inspectionDate: details.inspectionDate,
      reportDate: reportDate ?? DateTime.now(),
    );
  }

  ReportMetadata copyWith({
    String? title,
    String? projectName,
    String? address,
    String? blockTower,
    String? unitNumber,
    String? clientName,
    String? inspectorName,
    DateTime? inspectionDate,
    DateTime? reportDate,
  }) {
    return ReportMetadata(
      title: title ?? this.title,
      projectName: projectName ?? this.projectName,
      address: address ?? this.address,
      blockTower: blockTower ?? this.blockTower,
      unitNumber: unitNumber ?? this.unitNumber,
      clientName: clientName ?? this.clientName,
      inspectorName: inspectorName ?? this.inspectorName,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      reportDate: reportDate ?? this.reportDate,
    );
  }
}
