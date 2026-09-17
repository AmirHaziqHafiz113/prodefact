import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:prodefact/core/inspection/entities/auth_user.dart';
import 'package:prodefact/core/inspection/entities/evidence.dart';
import 'package:prodefact/core/inspection/report/report_file_store.dart';
import 'package:prodefact/core/inspection/report/report_renderer.dart';
import 'package:prodefact/core/inspection/report/report_share_service.dart';
import 'package:prodefact/core/inspection/repository/inspection_repository.dart';
import 'package:prodefact/core/inspection/services/connectivity_service.dart';
import 'package:prodefact/core/inspection/services/evidence_capture_service.dart';
import 'package:prodefact/core/inspection/services/evidence_file_store.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/data/report/report_providers.dart';

import 'fake_auth_service.dart';
import 'fake_cloud_inspection_repository.dart';
import 'fake_report_services.dart';

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

/// A fake connectivity service so tests never touch `connectivity_plus`'s
/// real platform channel (unavailable/unmocked in the test environment).
/// Defaults to always-online; tests exercising offline/reconnect
/// behavior construct their own instance and push values via [setStatus].
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({
    ConnectivityStatus initial = ConnectivityStatus.online,
  }) : _status = initial;

  ConnectivityStatus _status;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  void setStatus(ConnectivityStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  Future<ConnectivityStatus> checkStatus() async => _status;

  /// Emits the current status immediately on listen (like a real
  /// `StreamProvider`'s first value would settle to), then forwards
  /// subsequent [setStatus] calls — mirrors `FakeAuthService`'s
  /// `authStateChanges()` for the same reason: a `StreamProvider`
  /// watcher should never see a prolonged "loading" (null `.value`)
  /// window for a status this fake already knows synchronously.
  @override
  Stream<ConnectivityStatus> statusChanges() {
    return Stream.multi((controller) {
      controller.add(_status);
      final subscription = _controller.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  void dispose() => unawaited(_controller.close());
}

/// Provider overrides every test that touches persistence-backed
/// providers should pass to `ProviderContainer`/`ProviderScope`, so
/// tests use an in-memory database and a fake image picker instead of
/// real device storage/camera.
List<Override> testOverrides({
  InspectionRepository? repository,
  EvidenceCaptureService? captureService,
  EvidenceFileStore? evidenceFileStore,
  ReportRenderer? reportRenderer,
  ReportFileStore? reportFileStore,
  ReportShareService? reportShareService,
  ConnectivityService? connectivityService,
}) {
  return [
    inspectionRepositoryProvider.overrideWithValue(
      repository ?? createInMemoryRepository(),
    ),
    evidenceCaptureServiceProvider.overrideWithValue(
      captureService ?? FakeEvidenceCaptureService(),
    ),
    connectivityServiceProvider.overrideWithValue(
      connectivityService ?? FakeConnectivityService(),
    ),
    // Evidence/report file "deletion" in tests never touches the real
    // filesystem, device camera/gallery picker, PDF rendering, or the
    // OS share sheet.
    evidenceFileStoreProvider.overrideWithValue(
      evidenceFileStore ?? FakeEvidenceFileStore(),
    ),
    reportRendererProvider.overrideWithValue(
      reportRenderer ?? FakeReportRenderer(),
    ),
    reportFileStoreProvider.overrideWithValue(
      reportFileStore ?? FakeReportFileStore(),
    ),
    reportShareServiceProvider.overrideWithValue(
      reportShareService ?? FakeReportShareService(),
    ),
  ];
}

/// Provider overrides for tests that also exercise auth/sync: a fake,
/// already-"configured" Firebase (`firebaseReadyProvider` true) backed
/// entirely by [FakeAuthService]/[FakeCloudInspectionRepository] — no
/// real Firebase project is ever touched.
List<Override> testOverridesWithSync({
  EvidenceCaptureService? captureService,
  FakeAuthService? authService,
  FakeCloudInspectionRepository? cloudRepository,
  ConnectivityService? connectivityService,
}) {
  return [
    ...testOverrides(
      captureService: captureService,
      connectivityService: connectivityService,
    ),
    firebaseReadyProvider.overrideWithValue(true),
    authServiceProvider.overrideWithValue(authService ?? FakeAuthService()),
    cloudInspectionRepositoryProvider.overrideWithValue(
      cloudRepository ?? FakeCloudInspectionRepository(),
    ),
  ];
}

const testAuthUser = AuthUser(uid: 'test-uid', email: 'inspector@example.com');
