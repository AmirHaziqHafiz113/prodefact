import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/inspection/report/report_file_store.dart';

/// Writes generated report PDFs under `<appDocs>/reports/` — a sibling
/// of the evidence directory Phase 4 established, following the same
/// "app-managed local storage, never raw bytes in Drift" pattern.
class LocalReportFileStore implements ReportFileStore {
  @override
  Future<String> saveReportFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await _reportsDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> deleteReportFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Uint8List?> readReportFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _reportsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(documentsDir.path, 'reports'));
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }
}
