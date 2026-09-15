import 'dart:io';

import 'package:printing/printing.dart';

import '../../core/inspection/report/report_share_service.dart';

/// Hands the generated PDF to the platform share sheet via
/// `package:printing`'s [Printing.sharePdf] — works on iOS and Android
/// without any platform-specific code. This is the only file that
/// imports `package:printing` for sharing.
class PrintingReportShareService implements ReportShareService {
  @override
  Future<void> shareReport({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Report file is missing, cannot share: $filePath');
    }
    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
