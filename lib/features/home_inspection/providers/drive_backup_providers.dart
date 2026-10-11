import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/backup/drive_backup.dart';
import '../../../core/inspection/inspection_domain.dart';
import '../../../data/backup/drift_drive_backup_store.dart';
import '../../../data/backup/drive_backup_coordinator.dart';
import '../../../data/backup/firestore_drive_metadata.dart';
import '../../../data/backup/google_drive_rest_client.dart';
import '../../../data/backup/google_sign_in_drive_auth.dart';
import '../../../data/backup/in_memory_drive_backup_store.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/local/drift_inspection_repository.dart';
import '../../../data/remote/remote_providers.dart';

/// The persistent backup queue — the same on-device database as the
/// inspection data (schema v18), so it survives restarts.
final driveBackupStoreProvider = Provider<DriveBackupStore>((ref) {
  final repository = ref.watch(inspectionRepositoryProvider);
  if (repository is DriftInspectionRepository) {
    return DriftDriveBackupStore(repository.database);
  }
  return InMemoryDriveBackupStore();
});

final googleDriveClientProvider = Provider<GoogleDriveClient>(
  (ref) => GoogleDriveRestClient(),
);

final driveAuthServiceProvider = Provider<DriveAuthService>(
  (ref) => GoogleSignInDriveAuth(),
);

/// The one backup coordinator. Resolves queued photos from the local
/// inspection data (original files only), and is online when the device
/// has connectivity.
final driveBackupCoordinatorProvider = Provider<DriveBackupCoordinator>((ref) {
  final repository = ref.watch(inspectionRepositoryProvider);
  final sessionCache = <String, (DateTime, InspectionSession?)>{};

  Future<InspectionSession?> session(String id) async {
    final cached = sessionCache[id];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(seconds: 30)) {
      return cached.$2;
    }
    final loaded = await repository.loadSession(id);
    sessionCache[id] = (DateTime.now(), loaded);
    return loaded;
  }

  final coordinator = DriveBackupCoordinator(
    store: ref.watch(driveBackupStoreProvider),
    client: ref.watch(googleDriveClientProvider),
    auth: ref.watch(driveAuthServiceProvider),
    onVerified: (entry) async {
      // Mirror the Drive metadata onto the cloud evidence record.
      if (!ref.read(firebaseReadyProvider)) return;
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid == null) return;
      await mirrorDriveMetadataToFirestore(uid, entry);
    },
    isOnline: () =>
        ref.read(connectivityStatusProvider).value !=
        ConnectivityStatus.offline,
    resolvePhoto: (entry) async {
      final s = await session(entry.sessionId);
      if (s == null) return null;
      final finding = s.findings.firstWhereOrNull(
        (f) => f.id == entry.findingId,
      );
      final evidence = finding?.evidence.firstWhereOrNull(
        (e) => e.id == entry.evidenceId,
      );
      if (finding == null || evidence == null) return null;
      final section = s.sections.firstWhereOrNull(
        (sec) => sec.id == finding.sectionId,
      );
      final details = s.propertyDetails;
      return DriveBackupPhoto(
        evidenceId: evidence.id,
        sessionId: s.id,
        findingId: finding.id,
        sectionId: finding.sectionId,
        sectionName: section?.name ?? 'Area',
        inspectionTitle: details.title.isNotEmpty
            ? details.title
            : s.assetTypeId,
        inspectionDate: details.inspectionDate ?? s.createdAt,
        originalFilePath: evidence.filePath,
      );
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Started once from the app root: re-queues interrupted uploads,
/// restores a previous Drive connection silently, and processes the
/// queue again whenever connectivity returns.
final driveBackupBootstrapProvider = Provider<void>((ref) {
  final coordinator = ref.watch(driveBackupCoordinatorProvider);
  unawaited(coordinator.start());
  ref.listen(connectivityStatusProvider, (previous, next) {
    if (next.value != ConnectivityStatus.offline &&
        previous?.value == ConnectivityStatus.offline) {
      unawaited(coordinator.processQueue());
    }
  });
});

/// Everything the Storage & Backup screen shows.
class DriveBackupOverview {
  const DriveBackupOverview({
    required this.connectedEmail,
    required this.autoBackup,
    required this.counts,
    required this.lastSuccessAt,
    required this.blocker,
  });

  final String? connectedEmail;
  final bool autoBackup;
  final DriveBackupCounts counts;
  final DateTime? lastSuccessAt;
  final DriveBackupBlocker blocker;

  bool get isConnected => connectedEmail != null;
}

final driveBackupOverviewProvider =
    StreamProvider.autoDispose<DriveBackupOverview>((ref) async* {
      final coordinator = ref.watch(driveBackupCoordinatorProvider);
      final store = ref.watch(driveBackupStoreProvider);
      Future<DriveBackupOverview> read() async => DriveBackupOverview(
        connectedEmail: await coordinator.connectedEmail,
        autoBackup: await coordinator.autoBackupEnabled,
        counts: await store.counts(),
        lastSuccessAt: await coordinator.lastSuccessAt,
        blocker: coordinator.blocker,
      );
      yield await read();
      await for (final _ in coordinator.changes) {
        yield await read();
      }
    });

/// One session's backup records by evidence id — for Past Inspection
/// photos ("Backed up to Drive" / "View Original").
final sessionDriveBackupsProvider = FutureProvider.autoDispose
    .family<Map<String, DriveBackupEntry>, String>((ref, sessionId) async {
      final store = ref.watch(driveBackupStoreProvider);
      final entries = await store.forSession(sessionId);
      return {for (final e in entries) e.evidenceId: e};
    });
