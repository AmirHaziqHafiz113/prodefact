import 'sync_status.dart';

/// Metadata for the generated PDF report of one inspection session.
///
/// Only the file *reference* lives here — never raw PDF bytes (those
/// live in app-managed local storage at [filePath]). There is at most
/// one [Report] per session: generating a fresh report replaces this
/// row (and its previous file) rather than accumulating history — see
/// the "latest report per inspection" policy in `docs/report.md`.
class Report {
  const Report({
    required this.id,
    required this.sessionId,
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.sourceUpdatedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  final String id;
  final String sessionId;

  /// Local path to the generated PDF file.
  final String filePath;

  final String fileName;
  final DateTime generatedAt;

  /// A snapshot of `InspectionSession.updatedAt` as of when this report
  /// was generated — compared against the session's *current*
  /// `updatedAt` to detect staleness (see [isStaleRelativeTo]) without
  /// needing a separate mutable status column.
  final DateTime sourceUpdatedAt;

  final SyncStatus syncStatus;

  /// Whether the inspection has changed since this report was
  /// generated — i.e. this report should be regenerated before being
  /// treated as current.
  bool isStaleRelativeTo(DateTime currentSessionUpdatedAt) =>
      currentSessionUpdatedAt.isAfter(sourceUpdatedAt);
}
