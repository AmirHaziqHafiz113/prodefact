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

  /// Guards against two concurrent `generateReport` calls for the same
  /// session racing to render/write the same (date-based, therefore
  /// often identical) filename — without this, a double-tap of
  /// "Generate Report"/"Regenerate" could interleave two writes to the
  /// same path. Per-coordinator-instance, which is sufficient since the
  /// app only ever holds one via `reportCoordinatorProvider` — see
  /// `docs/production_readiness.md` ("Concurrency").
  final Set<String> _inFlight = {};

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<ReportGenerationResult> generateReport(
    String sessionId, {
    required String propertyTypeLabel,
  }) async {
    if (!_inFlight.add(sessionId)) {
      return const ReportGenerationResult.failure(
        'A report is already being generated for this inspection.',
      );
    }
    try {
      return await _generateReport(
        sessionId,
        propertyTypeLabel: propertyTypeLabel,
      );
    } finally {
      _inFlight.remove(sessionId);
    }
  }

  Future<ReportGenerationResult> _generateReport(
    String sessionId, {
    required String propertyTypeLabel,
  }) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const ReportGenerationResult.sessionNotFound();

    // ---- the report gate: enforced here, not just by hiding a button ----
    //
    // Physical inspection progress, AI processing progress, and
    // inspector review progress are three independent axes (see
    // `AiProcessingProgress`/`AiReviewProgress`/`PhysicalProgress`) —
    // all three must be settled before a report can be generated:
    if (session.status == InspectionStatus.inProgress) {
      return const ReportGenerationResult.physicalInspectionIncomplete();
    }
    final processing = AiProcessingProgress.of(session);
    final review = AiReviewProgress.of(session);
    // `processing.inFlight` catches a finding still queued/uploading/
    // analyzing (including one that was never even queued at all);
    // `review.pending` catches one that finished processing but has an
    // unreviewed (or needs-review, still-unresolved) suggestion.
    final aiReviewIncomplete = processing.inFlight > 0 || review.pending > 0;
    if (aiReviewIncomplete) {
      return const ReportGenerationResult.aiReviewIncomplete();
    }

    final now = DateTime.now();
    // A regenerated report is a new version, never a silent overwrite —
    // surfaced to the inspector as "v2", "v3", etc. See
    // `docs/home_inspection_product_flow.md` ("Report versioning").
    final version = (session.report?.version ?? 0) + 1;
    final model = buildReportModel(
      session: session,
      propertyTypeLabel: propertyTypeLabel,
      generatedAt: now,
      version: version,
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
        version: version,
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
