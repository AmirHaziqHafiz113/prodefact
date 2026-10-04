import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:prodefact/core/inspection/areas/area_candidate_service.dart';
import 'package:prodefact/core/inspection/billing/billing_service.dart';
import 'package:prodefact/core/inspection/billing/house_pass_status_service.dart';
import 'package:prodefact/core/inspection/billing/wallet_activity_service.dart';
import 'package:prodefact/core/inspection/entities/auth_user.dart';
import 'package:prodefact/core/inspection/entities/evidence.dart';
import 'package:prodefact/core/inspection/report/report_file_store.dart';
import 'package:prodefact/core/inspection/report/report_renderer.dart';
import 'package:prodefact/core/inspection/report/report_share_service.dart';
import 'package:prodefact/core/inspection/repository/inspection_repository.dart';
import 'package:prodefact/core/inspection/services/connectivity_service.dart';
import 'package:prodefact/core/inspection/services/evidence_capture_service.dart';
import 'package:prodefact/core/inspection/services/evidence_file_store.dart';
import 'package:prodefact/core/inspection/services/image_quality_service.dart';
import 'package:prodefact/data/areas/area_candidate_providers.dart';
import 'package:prodefact/data/billing/billing_providers.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/quality/basic_image_quality_service.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/data/report/report_providers.dart';

import 'fake_area_candidate_service.dart';
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

  /// How many photos the next gallery multi-pick returns (the
  /// inspector's selection), capped at the requested maximum.
  int galleryPickCount = 1;

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

  @override
  Future<List<CapturedEvidence>> captureImages({
    required String findingId,
    required EvidenceSource source,
    int maxImages = 3,
  }) async {
    if (cancelNextPick) return const [];
    final count = source == EvidenceSource.camera
        ? 1
        : galleryPickCount.clamp(0, maxImages);
    return [
      for (var i = 0; i < count; i++)
        (await captureImage(findingId: findingId, source: source))!,
    ];
  }
}

/// Local photo-quality hints without decoding anything: every photo
/// looks clear unless a test lists issues for its path (or for all).
class FakeImageQualityService implements ImageQualityService {
  FakeImageQualityService({this.issuesForAll = const []});

  List<LocalImageIssue> issuesForAll;
  final Map<String, List<LocalImageIssue>> issuesByPath = {};
  int checks = 0;

  @override
  Future<ImageQualityAssessment> assess(String filePath) async {
    checks++;
    return ImageQualityAssessment(issuesByPath[filePath] ?? issuesForAll);
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
  BillingService? billingService,
  AreaCandidateService? areaCandidateService,
  ImageQualityService? imageQualityService,
}) {
  final resolvedBillingService = billingService ?? FakeBillingService();
  final resolvedWalletActivityService =
      resolvedBillingService is WalletActivityService
      ? resolvedBillingService as WalletActivityService
      : FakeBillingService();
  final resolvedHousePassStatusService =
      resolvedBillingService is HousePassStatusService
      ? resolvedBillingService as HousePassStatusService
      : FakeBillingService();
  return [
    inspectionRepositoryProvider.overrideWithValue(
      repository ?? createInMemoryRepository(),
    ),
    evidenceCaptureServiceProvider.overrideWithValue(
      captureService ?? FakeEvidenceCaptureService(),
    ),
    // Never decodes real photos in a test.
    imageQualityServiceProvider.overrideWithValue(
      imageQualityService ?? FakeImageQualityService(),
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
    // Never a real `FirebaseBillingService`/`FirestoreWalletActivityService`
    // in a test — even a test that sets `firebaseReadyProvider` true has
    // no real Firebase project behind it. The same fake instance backs
    // both providers, exactly like production's local-only mode (see
    // `billing_providers.dart`).
    billingServiceProvider.overrideWithValue(resolvedBillingService),
    // Never the real callable client in a test (no Firebase app exists).
    areaCandidateServiceProvider.overrideWithValue(
      areaCandidateService ?? FakeAreaCandidateService(),
    ),
    walletActivityServiceProvider.overrideWithValue(
      resolvedWalletActivityService,
    ),
    housePassStatusServiceProvider.overrideWithValue(
      resolvedHousePassStatusService,
    ),
  ];
}

/// Provider overrides for tests that also exercise auth/sync: a fake,
/// already-"configured" Firebase (`firebaseReadyProvider` true) backed
/// entirely by [FakeAuthService]/[FakeCloudInspectionRepository] — no
/// real Firebase project is ever touched.
List<Override> testOverridesWithSync({
  InspectionRepository? repository,
  EvidenceCaptureService? captureService,
  FakeAuthService? authService,
  FakeCloudInspectionRepository? cloudRepository,
  ConnectivityService? connectivityService,
  BillingService? billingService,
  AreaCandidateService? areaCandidateService,
}) {
  return [
    ...testOverrides(
      repository: repository,
      captureService: captureService,
      connectivityService: connectivityService,
      billingService: billingService,
      areaCandidateService: areaCandidateService,
    ),
    firebaseReadyProvider.overrideWithValue(true),
    authServiceProvider.overrideWithValue(authService ?? FakeAuthService()),
    cloudInspectionRepositoryProvider.overrideWithValue(
      cloudRepository ?? FakeCloudInspectionRepository(),
    ),
  ];
}

const testAuthUser = AuthUser(uid: 'test-uid', email: 'inspector@example.com');
