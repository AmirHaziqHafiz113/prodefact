import 'dart:typed_data';

import 'package:prodefact/core/inspection/inspection_domain.dart';

/// In-memory [ReportRenderer] fake — no `package:pdf` rendering
/// involved. Returns fixed bytes (or throws, if configured) so
/// coordinator-level tests can focus on orchestration/gating logic
/// without depending on real PDF rendering.
class FakeReportRenderer implements ReportRenderer {
  int renderCalls = 0;
  Object? failNextRenderWith;
  ReportModel? lastModel;

  @override
  Future<Uint8List> render(ReportModel model) async {
    renderCalls++;
    lastModel = model;
    final failure = failNextRenderWith;
    if (failure != null) {
      failNextRenderWith = null;
      throw failure;
    }
    return Uint8List.fromList([1, 2, 3, 4]);
  }
}

/// In-memory [ReportFileStore] fake — no real filesystem access.
class FakeReportFileStore implements ReportFileStore {
  final Map<String, Uint8List> _files = {};
  final List<String> deletedPaths = [];
  Object? failNextSaveWith;

  @override
  Future<String> saveReportFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final failure = failNextSaveWith;
    if (failure != null) {
      failNextSaveWith = null;
      throw failure;
    }
    final path = '/fake/reports/$fileName';
    _files[path] = bytes;
    return path;
  }

  @override
  Future<void> deleteReportFile(String filePath) async {
    _files.remove(filePath);
    deletedPaths.add(filePath);
  }

  @override
  Future<Uint8List?> readReportFile(String filePath) async {
    return _files[filePath];
  }

  bool exists(String filePath) => _files.containsKey(filePath);
}

/// Records share requests instead of driving a real OS share sheet.
class FakeReportShareService implements ReportShareService {
  final List<({String filePath, String fileName})> shareCalls = [];

  @override
  Future<void> shareReport({
    required String filePath,
    required String fileName,
  }) async {
    shareCalls.add((filePath: filePath, fileName: fileName));
  }
}
