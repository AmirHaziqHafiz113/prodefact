import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../local/database_providers.dart';
import 'default_report_coordinator.dart';
import 'local_report_file_store.dart';
import 'pdf_report_renderer.dart';
import 'printing_report_share_service.dart';

final reportRendererProvider = Provider<ReportRenderer>((ref) {
  return PdfReportRenderer();
});

final reportFileStoreProvider = Provider<ReportFileStore>((ref) {
  return LocalReportFileStore();
});

final reportShareServiceProvider = Provider<ReportShareService>((ref) {
  return PrintingReportShareService();
});

final reportCoordinatorProvider = Provider<ReportCoordinator>((ref) {
  return DefaultReportCoordinator(
    localRepository: ref.watch(inspectionRepositoryProvider),
    renderer: ref.watch(reportRendererProvider),
    fileStore: ref.watch(reportFileStoreProvider),
  );
});
