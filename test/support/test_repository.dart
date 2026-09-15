import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:prodefact/core/inspection/entities/evidence.dart';
import 'package:prodefact/core/inspection/services/evidence_capture_service.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

/// An in-memory-backed [DriftInspectionRepository] for tests — same
/// behavior as production, no real device filesystem involved.
///
/// Each test opens its own independent in-memory `AppDatabase`
/// instance, which is exactly what Drift's "created multiple times"
/// heuristic warns about — harmless here, so it's silenced.
DriftInspectionRepository createInMemoryRepository() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return DriftInspectionRepository(AppDatabase(NativeDatabase.memory()));
}

/// A fake evidence capture service so tests never drive a real device
/// camera/gallery picker. Returns a fixed, fake local path (or null, to
/// simulate the user cancelling the picker) instead of touching
/// `image_picker`/`path_provider`.
class FakeEvidenceCaptureService implements EvidenceCaptureService {
  FakeEvidenceCaptureService({this.cancelNextPick = false});

  bool cancelNextPick;
  int captureCount = 0;

  @override
  Future<CapturedEvidence?> captureImage({
    required String findingId,
    required EvidenceSource source,
  }) async {
    captureCount++;
    if (cancelNextPick) return null;
    return CapturedEvidence(
      filePath: '/fake/evidence/$findingId/$captureCount.jpg',
      source: source,
    );
  }
}

/// Provider overrides every test that touches persistence-backed
/// providers should pass to `ProviderContainer`/`ProviderScope`, so
/// tests use an in-memory database and a fake image picker instead of
/// real device storage/camera.
List<Override> testOverrides({EvidenceCaptureService? captureService}) {
  return [
    inspectionRepositoryProvider.overrideWithValue(createInMemoryRepository()),
    evidenceCaptureServiceProvider.overrideWithValue(
      captureService ?? FakeEvidenceCaptureService(),
    ),
  ];
}
