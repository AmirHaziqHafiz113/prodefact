import '../../core/inspection/inspection_domain.dart';

/// Orchestrates report generation for a session: enforces the report
/// gate, builds the typed [ReportModel], renders it, saves the PDF to
/// local storage, and persists report metadata — all through the same
/// [InspectionRepository] every other write in the app goes through.
///
/// See `docs/report.md` for the full gate rules and the "latest report
/// per inspection" regeneration policy this implements.
class DefaultReportCoordinator implements ReportCoordinator {
  DefaultReportCoordinator({
    required InspectionRepository localRepository,
    required ReportRenderer renderer,
    required ReportFileStore fileStore,
  }) : _local = localRepository,
       _renderer = renderer,
       _fileStore = fileStore;

  final InspectionRepository _local;
  final ReportRenderer _renderer;
  final ReportFileStore _fileStore;

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<ReportGenerationResult> generateReport(
    String sessionId, {
    required String propertyTypeLabel,
  }) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const ReportGenerationResult.sessionNotFound();

    // ---- the report gate: enforced here, not just by hiding a button ----
    if (session.status == InspectionStatus.inProgress) {
      return const ReportGenerationResult.physicalInspectionIncomplete();
    }
    final aiReviewIncomplete =
        session.aiReviewState != AiReviewState.completed ||
        session.aiSuggestions.any((s) => !s.isResolved);
    if (aiReviewIncomplete) {
      return const ReportGenerationResult.aiReviewIncomplete();
    }

    final now = DateTime.now();
    final model = buildReportModel(
      session: session,
      propertyTypeLabel: propertyTypeLabel,
      generatedAt: now,
    );
    final fileName = buildReportFileName(sessionId: sessionId, date: now);

    try {
      final bytes = await _renderer.render(model);
      final filePath = await _fileStore.saveReportFile(
        fileName: fileName,
        bytes: bytes,
      );

      // Regeneration policy: replace the previous file if this run
      // produced a different path (e.g. a different day) — "latest
      // report per inspection" means we never accumulate orphan PDFs.
      final previousPath = session.report?.filePath;
      if (previousPath != null && previousPath != filePath) {
        await _fileStore.deleteReportFile(previousPath);
      }

      final report = Report(
        id: _newId('report'),
        sessionId: sessionId,
        filePath: filePath,
        fileName: fileName,
        generatedAt: now,
        sourceUpdatedAt: session.updatedAt,
      );
      await _local.saveReport(report);
      return ReportGenerationResult.success(report);
    } catch (error) {
      // Physical inspection / AI review data is completely untouched —
      // only the render/save attempt failed.
      return ReportGenerationResult.failure(error.toString());
    }
  }
}
