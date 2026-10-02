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

  /// The report gate: the Client / Agent Contact Number was left blank
  /// at setup (allowed — see the QA/QC simplification pass) and still
  /// hasn't been completed. Required before finalization, unlike every
  /// other deferrable Basic Details field. No report was generated.
  missingContactNumber,

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
  /// [message] says exactly what is outstanding (see
  /// `ReportReadiness.summary`).
  const ReportGenerationResult.aiReviewIncomplete([String? message])
    : this._(ReportGenerationOutcome.aiReviewIncomplete, null, message);
  const ReportGenerationResult.missingContactNumber()
    : this._(ReportGenerationOutcome.missingContactNumber, null, null);
  const ReportGenerationResult.sessionNotFound()
    : this._(ReportGenerationOutcome.sessionNotFound, null, null);
  const ReportGenerationResult.failure(String message)
    : this._(ReportGenerationOutcome.failure, null, message);

  final ReportGenerationOutcome outcome;
  final Report? report;
  final String? message;

  bool get isSuccess => outcome == ReportGenerationOutcome.success;
}
