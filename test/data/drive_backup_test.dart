import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/backup/drive_backup.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/backup/drift_drive_backup_store.dart';
import 'package:prodefact/data/backup/drive_backup_coordinator.dart';
import 'package:prodefact/data/backup/in_memory_drive_backup_store.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/drive_backup_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// An in-memory Google Drive.
class _FakeDrive implements GoogleDriveClient {
  final Map<String, ({List<int> bytes, Map<String, String> props})> files = {};
  final Map<String, String> folders = {}; // folderKey -> id
  int uploads = 0;
  int failNextUploads = 0;
  bool failWithAuth = false;
  bool corruptSize = false;
  var _ids = 0;

  @override
  Future<String> ensureFolder({
    required String accessToken,
    required String name,
    required String folderKey,
    String? parentId,
  }) async => folders[folderKey] ??= 'folder_${_ids++}';

  @override
  Future<DriveFileInfo?> findByEvidenceId({
    required String accessToken,
    required String evidenceId,
  }) async {
    for (final e in files.entries) {
      if (e.value.props['prodefactEvidenceId'] == evidenceId) {
        return _info(e.key);
      }
    }
    return null;
  }

  DriveFileInfo _info(String id) {
    final bytes = files[id]!.bytes;
    return DriveFileInfo(
      id: id,
      size: corruptSize ? bytes.length + 1 : bytes.length,
      md5Checksum: md5.convert(bytes).toString(),
    );
  }

  @override
  Future<DriveFileInfo> upload({
    required String accessToken,
    required String folderId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    required Map<String, String> appProperties,
  }) async {
    if (failWithAuth) throw const DriveAuthRequiredException();
    if (failNextUploads > 0) {
      failNextUploads--;
      throw const DriveNetworkException();
    }
    uploads++;
    final id = 'file_${_ids++}';
    files[id] = (bytes: bytes, props: appProperties);
    return _info(id);
  }

  @override
  Future<DriveFileInfo?> getFile({
    required String accessToken,
    required String fileId,
  }) async => files.containsKey(fileId) ? _info(fileId) : null;

  @override
  Future<List<int>> download({
    required String accessToken,
    required String fileId,
  }) async => files[fileId]!.bytes;
}

class _FakeAuth implements DriveAuthService {
  bool expired = false;
  int connects = 0;

  @override
  Future<DriveAccount> connect() async {
    connects++;
    expired = false;
    return const DriveAccount(email: 'inspector@example.com');
  }

  @override
  Future<DriveAccount?> restore() async =>
      const DriveAccount(email: 'inspector@example.com');

  @override
  Future<String> accessToken() async {
    if (expired) throw const DriveAuthRequiredException();
    return 'token';
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  late Directory dir;
  late DriveBackupStore store;
  late _FakeDrive drive;
  late _FakeAuth auth;
  late DateTime now;
  late bool online;
  late Map<String, DriveBackupPhoto> photos;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('drive_backup_test');
    store = InMemoryDriveBackupStore();
    drive = _FakeDrive();
    auth = _FakeAuth();
    now = DateTime(2026, 10, 11, 9);
    online = true;
    photos = {};
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<String> photo(String id, {int size = 2048}) async {
    final file = File('${dir.path}/$id.jpg');
    await file.writeAsBytes(List<int>.generate(size, (i) => i % 251));
    photos[id] = DriveBackupPhoto(
      evidenceId: id,
      sessionId: 'session_1',
      findingId: 'finding_$id',
      sectionId: 'kitchen',
      sectionName: 'Kitchen',
      inspectionTitle: 'Residensi Vista',
      inspectionDate: DateTime(2026, 10, 9),
      originalFilePath: file.path,
    );
    return file.path;
  }

  DriveBackupCoordinator coordinator({DriveBackupStore? withStore}) =>
      DriveBackupCoordinator(
        store: withStore ?? store,
        client: drive,
        auth: auth,
        resolvePhoto: (e) async => photos[e.evidenceId],
        isOnline: () => online,
        clock: () => now,
      );

  Future<void> connected(DriveBackupCoordinator c) async {
    await c.connect();
    await c.processQueue();
  }

  Future<void> enqueue(DriveBackupCoordinator c, String id) => c.enqueue(
    sessionId: 'session_1',
    findingId: 'finding_$id',
    evidenceId: id,
  );

  test('queue after capture: a saved photo is queued, uploaded to '
      'ProDefact/Inspections/<year>/<inspection>/<area>, and verified', () async {
    final c = coordinator();
    await connected(c);
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();

    final entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.verified);
    expect(entry.driveFileId, isNotNull);
    expect(entry.backedUpAt, now);
    expect(drive.folders.keys, [
      'root',
      'inspections',
      'year:2026',
      'inspection:session_1',
      'area:session_1:kitchen',
    ]);
    final props = drive.files[entry.driveFileId]!.props;
    expect(props['prodefactEvidenceId'], 'ev_1');
    expect(props['prodefactInspectionId'], 'session_1');
    expect(await c.lastSuccessAt, now);
  });

  test('Drive not connected: the photo is kept (notStarted) and backed up '
      'once Drive is connected', () async {
    final c = coordinator();
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.notStarted);
    expect(drive.uploads, 0);

    await connected(c);
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.verified);
  });

  test('Firebase success + Drive pending: offline, the photo waits in the '
      'queue (nothing uploaded, nothing lost) and goes up when back online',
      () async {
    final c = coordinator();
    await connected(c);
    online = false;
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.queued);
    expect(c.blocker, DriveBackupBlocker.offline);
    expect(drive.uploads, 0);

    online = true;
    await c.processQueue();
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.verified);
  });

  test('retry: a network failure backs off, is not retried early, and is '
      'retried (and verified) once the backoff elapses', () async {
    final c = coordinator();
    await connected(c);
    await photo('ev_1');
    drive.failNextUploads = 1;
    await enqueue(c, 'ev_1');
    await c.processQueue();

    var entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.failed);
    expect(entry.retryCount, 1);
    expect(entry.lastError, 'network');
    expect(entry.nextAttemptAt, now.add(const Duration(minutes: 1)));

    await c.processQueue(); // too early
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.failed);

    now = now.add(const Duration(minutes: 2));
    await c.processQueue();
    entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.verified);
    expect(drive.uploads, 1);
  });

  test('backoff grows exponentially and is capped at 6 hours', () {
    expect(DriveBackupCoordinator.backoffFor(1), const Duration(minutes: 1));
    expect(DriveBackupCoordinator.backoffFor(2), const Duration(minutes: 2));
    expect(DriveBackupCoordinator.backoffFor(5), const Duration(minutes: 16));
    expect(DriveBackupCoordinator.backoffFor(30), const Duration(hours: 6));
  });

  test('app restart recovery: an upload interrupted by the app stopping is '
      're-queued on start and completed — the queue lives in the database',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final persisted = DriftDriveBackupStore(db);
    await photo('ev_1');
    await persisted.writeSetting(DriveBackupSettings.accountEmail, 'a@b.c');
    await persisted.writeSetting(DriveBackupSettings.autoBackup, 'true');
    await persisted.insertIfAbsent(
      DriveBackupEntry(
        evidenceId: 'ev_1',
        sessionId: 'session_1',
        findingId: 'finding_ev_1',
        status: DriveBackupStatus.uploading, // the app died mid-upload
        createdAt: now,
        updatedAt: now,
      ),
    );

    // "Restart": a brand-new store and coordinator over the same database.
    final restarted = coordinator(withStore: DriftDriveBackupStore(db));
    await restarted.start();
    await restarted.processQueue();

    final entry = (await DriftDriveBackupStore(db).get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.verified);
    expect(drive.uploads, 1);
  });

  test('duplicate prevention: a photo is queued once, concurrent runs '
      'upload it once, and an upload a crashed attempt already made is '
      'adopted instead of uploaded again', () async {
    final c = coordinator();
    await connected(c);
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    await enqueue(c, 'ev_1');
    await Future.wait([c.processQueue(), c.processQueue(), c.processQueue()]);
    expect(drive.uploads, 1);
    expect(drive.files, hasLength(1));

    // A previous attempt uploaded ev_2 but crashed before recording it.
    final path = await photo('ev_2');
    final bytes = await File(path).readAsBytes();
    drive.files['orphan'] = (
      bytes: bytes,
      props: {'prodefactEvidenceId': 'ev_2'},
    );
    await enqueue(c, 'ev_2');
    await c.processQueue();
    final entry = (await store.get('ev_2'))!;
    expect(entry.status, DriveBackupStatus.verified);
    expect(entry.driveFileId, 'orphan');
    expect(drive.uploads, 1, reason: 'no second copy uploaded');
  });

  test('auth expiry pauses the queue without dropping or penalising '
      'photos; reconnecting resumes it', () async {
    final c = coordinator();
    await connected(c);
    await photo('ev_1');
    auth.expired = true;
    await enqueue(c, 'ev_1');
    await c.processQueue();
    var entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.queued);
    expect(entry.retryCount, 0);
    expect(c.blocker, DriveBackupBlocker.auth);

    // Expiry discovered mid-upload (401) also just pauses.
    auth.expired = false;
    drive.failWithAuth = true;
    await c.processQueue();
    entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.queued);
    expect(entry.lastError, 'auth_required');

    drive.failWithAuth = false;
    await c.connect(); // "Reconnect"
    await c.processQueue();
    expect((await store.get('ev_1'))!.status, DriveBackupStatus.verified);
  });

  test('disconnecting Drive stops uploads and keeps the queue', () async {
    final c = coordinator();
    await connected(c);
    await c.disconnect();
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();
    expect(drive.uploads, 0);
    expect(await store.get('ev_1'), isNotNull);
    expect(c.blocker, DriveBackupBlocker.notConnected);
  });

  test('verified only when Drive reports the same size and checksum', () async {
    final c = coordinator();
    await connected(c);
    await photo('ev_1');
    drive.corruptSize = true;
    await enqueue(c, 'ev_1');
    await c.processQueue();
    final entry = (await store.get('ev_1'))!;
    expect(entry.status, DriveBackupStatus.failed);
    expect(entry.lastError, 'verify_mismatch');
    expect(entry.driveFileId, isNull);
  });

  test('a deleted photo leaves the queue; a missing local file fails '
      'without crashing the run', () async {
    final c = coordinator();
    await connected(c);
    await store.insertIfAbsent(
      DriveBackupEntry(
        evidenceId: 'gone',
        sessionId: 'session_1',
        findingId: 'f',
        status: DriveBackupStatus.queued,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final path = await photo('ev_missing');
    await File(path).delete();
    await enqueue(c, 'ev_missing');
    await c.processQueue();
    expect(await store.get('gone'), isNull);
    expect(
      (await store.get('ev_missing'))!.lastError,
      'local_file_missing',
    );
  });

  test('View Original downloads the verified Drive copy; falls back (null) '
      'when there is none or Drive is unreachable', () async {
    final c = coordinator();
    await connected(c);
    final path = await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();
    expect(await c.downloadOriginal('ev_1'), await File(path).readAsBytes());
    expect(await c.downloadOriginal('unknown'), isNull);
    auth.expired = true;
    expect(await c.downloadOriginal('ev_1'), isNull);
  });

  test('cleanup is never triggered automatically: verified + retention '
      'elapsed is still not eligible while the policy is disabled, and the '
      'local original is never deleted', () async {
    final c = coordinator();
    await connected(c);
    final path = await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();
    final entry = (await store.get('ev_1'))!;
    final later = now.add(const Duration(days: 400));

    const policy = FirebaseRetentionPolicy();
    expect(policy.cleanupEnabled, isFalse);
    final state = policy.stateOf(
      firebaseOriginalPresent: true,
      backup: entry,
      now: later,
    );
    expect(state.driveVerified, isTrue);
    expect(state.eligibleForCleanup, isFalse);
    expect(await File(path).exists(), isTrue);

    // Only an explicitly enabled policy, after verification AND the
    // retention period, would ever make one eligible.
    const enabled = FirebaseRetentionPolicy(cleanupEnabled: true);
    expect(
      enabled
          .stateOf(firebaseOriginalPresent: true, backup: entry, now: now)
          .eligibleForCleanup,
      isFalse,
      reason: 'retention not elapsed',
    );
    expect(
      enabled
          .stateOf(firebaseOriginalPresent: true, backup: entry, now: later)
          .eligibleForCleanup,
      isTrue,
    );
    expect(
      enabled
          .stateOf(firebaseOriginalPresent: true, backup: null, now: later)
          .eligibleForCleanup,
      isFalse,
      reason: 'never without a verified Drive copy',
    );
  });

  test('Drive failure never blocks AI: with Drive broken, saving a finding '
      'still runs AI to a result, and the photo waits in the backup queue',
      () async {
    final brokenDrive = _FakeDrive()..failWithAuth = true;
    final brokenAuth = _FakeAuth()..expired = true;
    late ProviderContainer container;
    await Future<void>(() async {
      container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          googleDriveClientProvider.overrideWithValue(brokenDrive),
          driveAuthServiceProvider.overrideWithValue(brokenAuth),
        ],
      );
    });
    addTearDown(container.dispose);
    final backupStore = container.read(driveBackupStoreProvider);
    await backupStore.writeSetting(DriveBackupSettings.autoBackup, 'true');
    await backupStore.writeSetting(
      DriveBackupSettings.accountEmail,
      'inspector@example.com',
    );

    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    final section = container.read(inspectionQueueProvider).first.id;
    final captured = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: section,
      photo: captured!,
      note: 'Hollow tile',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final finding = container.read(activeSessionProvider)!.findings.single;
    expect(
      finding.aiStatus,
      isIn([AiFindingStatus.completed, AiFindingStatus.needsReview]),
    );
    final entry = await backupStore.get(finding.evidence.single.id);
    expect(entry, isNotNull, reason: 'queued for backup');
    expect(entry!.status, isNot(DriveBackupStatus.verified));
    expect(brokenDrive.uploads, 0);
  });

  test('a Residence / Unit Photo is backed up as its own asset type: its '
      'own "Residence Photo" folder and tag, never a finding area\'s', () async {
    final c = coordinator();
    await connected(c);
    final file = File('${dir.path}/residence.jpg');
    await file.writeAsBytes(List<int>.generate(4096, (i) => i % 251));
    const id = 'residence_session_1_residence';
    photos[id] = DriveBackupPhoto(
      evidenceId: id,
      sessionId: 'session_1',
      findingId: kResidencePhotoFindingId,
      sectionId: '__residence__',
      sectionName: 'Residence Photo',
      inspectionTitle: 'Residensi Vista',
      inspectionDate: DateTime(2026, 10, 9),
      originalFilePath: file.path,
      assetType: DriveAssetType.residencePhoto,
    );
    await c.enqueue(
      sessionId: 'session_1',
      findingId: kResidencePhotoFindingId,
      evidenceId: id,
    );
    await c.processQueue();

    final entry = (await store.get(id))!;
    expect(entry.status, DriveBackupStatus.verified);
    expect(entry.assetType, DriveAssetType.residencePhoto);
    expect(drive.folders.keys.last, 'area:session_1:__residence__');
    expect(drive.folders.keys, isNot(contains('area:session_1:kitchen')));
    final props = drive.files[entry.driveFileId]!.props;
    expect(props['prodefactAssetType'], 'residencePhoto');
    expect(props['prodefactFindingId'], kResidencePhotoFindingId);

    // A defect photo in the same inspection stays separate and is tagged so.
    await photo('ev_1');
    await enqueue(c, 'ev_1');
    await c.processQueue();
    final evidence = (await store.get('ev_1'))!;
    expect(evidence.assetType, DriveAssetType.findingEvidence);
    expect(
      drive.files[evidence.driveFileId]!.props['prodefactAssetType'],
      'findingEvidence',
    );
    expect(evidence.driveFolderId, isNot(entry.driveFolderId));
  });
}
