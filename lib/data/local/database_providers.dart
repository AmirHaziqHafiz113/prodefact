import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import 'database.dart';
import 'drift_inspection_repository.dart';
import 'image_picker_evidence_capture_service.dart';
import 'local_evidence_file_store.dart';

/// The app's on-device database. Tests override this with an in-memory
/// instance instead of touching the real device filesystem.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// The single seam between the app and local persistence — every
/// provider that needs durable storage depends on this interface, never
/// on [AppDatabase] directly.
final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return DriftInspectionRepository(ref.watch(appDatabaseProvider));
});

/// Acquires evidence photos. Tests override this with a fake that
/// returns canned file paths instead of driving a real picker.
final evidenceCaptureServiceProvider = Provider<EvidenceCaptureService>((ref) {
  return ImagePickerEvidenceCaptureService();
});

/// Deletes app-managed evidence files. Tests override this with an
/// in-memory fake instead of touching the real device filesystem.
final evidenceFileStoreProvider = Provider<EvidenceFileStore>((ref) {
  return LocalEvidenceFileStore();
});
