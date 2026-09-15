/// The final, generated report for a completed [Inspection] (PDF
/// generation itself is out of scope for the foundation phase; this is
/// just the domain placeholder it will eventually populate).
class Report {
  const Report({required this.id, required this.inspectionId, this.filePath});

  final String id;
  final String inspectionId;
  final String? filePath;
}
