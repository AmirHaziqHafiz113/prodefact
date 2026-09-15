import 'dart:io';

import '../../core/inspection/services/evidence_file_store.dart';
import '../../core/logging/app_logger.dart';

/// Deletes evidence files from the app's own documents directory. A
/// missing file, a permission error, or any other I/O failure is caught
/// and logged rather than thrown — cleanup is always best-effort and
/// must never prevent the database write it accompanies (finding/
/// evidence/session deletion) from completing.
class LocalEvidenceFileStore implements EvidenceFileStore {
  @override
  Future<void> deleteEvidenceFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Could not delete an evidence file during cleanup',
        error,
        stackTrace,
      );
    }
  }
}
