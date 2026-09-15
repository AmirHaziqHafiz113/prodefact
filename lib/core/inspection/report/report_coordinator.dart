import 'report_generation_result.dart';

/// Application-layer gate + orchestrator for report generation.
///
/// [generateReport] must refuse to generate — returning a controlled
/// [ReportGenerationResult], never producing a PDF — unless physical
/// inspection is complete *and* AI review is complete (every generated
/// suggestion resolved). See `docs/report.md`.
abstract class ReportCoordinator {
  Future<ReportGenerationResult> generateReport(
    String sessionId, {
    required String propertyTypeLabel,
  });
}
