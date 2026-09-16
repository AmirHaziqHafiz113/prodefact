/// Property/report metadata captured once, during New Inspection setup
/// (the Property Details step, between property type and area
/// configuration — see `docs/home_inspection_product_flow.md`), and
/// carried through to the dashboard card, the AI Review/Report Readiness
/// headers, and the generated PDF's cover page.
///
/// Every field is optional except [title] — an inspector can start an
/// inspection with only a title and fill in the rest later is *not*
/// supported in this pass (there is no post-creation edit screen yet);
/// what's captured at setup time is what the report uses. A session
/// created before this existed (schema v6 and earlier) has
/// [PropertyDetails.empty] — every display site falls back to the
/// property type's label in that case.
class PropertyDetails {
  const PropertyDetails({
    required this.title,
    this.address,
    this.projectName,
    this.blockTower,
    this.unitNumber,
    this.clientName,
    this.inspectorName,
    this.developerName,
    this.contactNumber,
    this.inspectionDate,
  });

  /// A session with no property details captured at all — every pre-v7
  /// session, and the default state of a fresh draft before the
  /// Property Details step is filled in.
  static const empty = PropertyDetails(title: '');

  final String title;
  final String? address;
  final String? projectName;
  final String? blockTower;
  final String? unitNumber;
  final String? clientName;
  final String? inspectorName;
  final String? developerName;
  final String? contactNumber;
  final DateTime? inspectionDate;

  bool get isEmpty => title.isEmpty;

  PropertyDetails copyWith({
    String? title,
    String? address,
    String? projectName,
    String? blockTower,
    String? unitNumber,
    String? clientName,
    String? inspectorName,
    String? developerName,
    String? contactNumber,
    DateTime? inspectionDate,
  }) {
    return PropertyDetails(
      title: title ?? this.title,
      address: address ?? this.address,
      projectName: projectName ?? this.projectName,
      blockTower: blockTower ?? this.blockTower,
      unitNumber: unitNumber ?? this.unitNumber,
      clientName: clientName ?? this.clientName,
      inspectorName: inspectorName ?? this.inspectorName,
      developerName: developerName ?? this.developerName,
      contactNumber: contactNumber ?? this.contactNumber,
      inspectionDate: inspectionDate ?? this.inspectionDate,
    );
  }
}
