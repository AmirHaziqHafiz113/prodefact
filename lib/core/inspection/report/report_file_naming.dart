/// Builds the deterministic, sanitized filename for a session's report:
/// `ProDefact_HomeInspection_<sessionId>_<yyyyMMdd>.pdf`.
///
/// Deterministic within a single day for the same session — the same
/// session regenerated twice on the same date produces the same
/// filename (a natural overwrite); a different date produces a new one,
/// whose predecessor the report coordinator deletes to avoid
/// accumulating orphan files (see `docs/report.md`).
String buildReportFileName({
  required String sessionId,
  required DateTime date,
}) {
  final sanitizedId = _sanitize(sessionId);
  final datePart =
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  return 'ProDefact_HomeInspection_${sanitizedId}_$datePart.pdf';
}

String _sanitize(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return cleaned.isEmpty ? 'session' : cleaned;
}
