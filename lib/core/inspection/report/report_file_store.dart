import 'dart:typed_data';

/// Writes/deletes report PDF files in app-managed local storage. Never
/// stores raw bytes in Drift — only the path this returns is persisted.
abstract class ReportFileStore {
  /// Writes [bytes] under [fileName] in the app's reports directory and
  /// returns the resulting local file path.
  Future<String> saveReportFile({
    required String fileName,
    required Uint8List bytes,
  });

  /// Deletes the file at [filePath] if it exists. Never throws for a
  /// missing file — deleting an already-gone file is a no-op, not an
  /// error (see the regeneration policy in `docs/report.md`).
  Future<void> deleteReportFile(String filePath);

  /// Reads the file at [filePath], or null if it's missing/unreadable.
  Future<Uint8List?> readReportFile(String filePath);
}
