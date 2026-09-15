import '../entities/report.dart';

/// Outcome of one [ReportCoordinator.generateReport] call.
enum ReportGenerationOutcome {
  /// The report was generated and persisted successfully.
  success,

  /// The report gate: physical inspection isn't complete yet. No
  /// report was generated, and no report metadata was touched.
  physicalInspectionIncomplete,

  /// The report gate: AI review isn't complete — either analysis
  /// hasn't finished, or at least one suggestion is still pending
  /// review. No report was generated.
  aiReviewIncomplete,

  /// The session id doesn't exist locally.
  sessionNotFound,

  /// Rendering or saving the PDF failed. Physical inspection and AI
  /// review data are completely untouched — see the retry/regeneration
  /// policy in `docs/report.md`.
  failure,
}

class ReportGenerationResult {
  const ReportGenerationResult._(this.outcome, this.report, this.message);

  const ReportGenerationResult.success(Report report)
    : this._(ReportGenerationOutcome.success, report, null);
  const ReportGenerationResult.physicalInspectionIncomplete()
    : this._(ReportGenerationOutcome.physicalInspectionIncomplete, null, null);
  const ReportGenerationResult.aiReviewIncomplete()
    : this._(ReportGenerationOutcome.aiReviewIncomplete, null, null);
  const ReportGenerationResult.sessionNotFound()
    : this._(ReportGenerationOutcome.sessionNotFound, null, null);
  const ReportGenerationResult.failure(String message)
    : this._(ReportGenerationOutcome.failure, null, message);

  final ReportGenerationOutcome outcome;
  final Report? report;
  final String? message;

  bool get isSuccess => outcome == ReportGenerationOutcome.success;
}
