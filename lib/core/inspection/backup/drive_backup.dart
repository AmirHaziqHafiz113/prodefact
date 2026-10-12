/// Google Drive backup of inspection ORIGINAL photos — the domain types.
/// See docs/drive_backup.md.
///
/// Firebase Storage stays the operational store (AI reads it, sync uses
/// it); the user's own Google Drive becomes the long-term home of the
/// original, full-resolution photo. A backup never blocks capture, AI,
/// sync or report generation: it runs from a persistent queue, retries
/// with backoff, and is idempotent per photo.
library;

/// Where one photo's Drive backup stands. Persisted by name.
enum DriveBackupStatus {
  /// Recorded, but Auto Backup is off or Drive isn't connected — queued
  /// as soon as both are true.
  notStarted,

  /// Waiting to upload (including after a recoverable failure, once its
  /// backoff has elapsed).
  queued,

  /// An upload is in progress (reset to [queued] on the next start if
  /// the app stopped mid-upload).
  uploading,

  /// Uploaded and re-read from Drive with a matching size and checksum.
  verified,

  /// The last attempt failed; retried automatically after a backoff.
  failed,
}

DriveBackupStatus driveBackupStatusFromName(String? name) =>
    DriveBackupStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => DriveBackupStatus.notStarted,
    );

/// What kind of asset a backup row is. Defect evidence and the report-cover
/// Residence / Unit Photo are tracked separately: different Drive folder,
/// different metadata, never mixed into a finding's evidence state.
enum DriveAssetType { findingEvidence, residencePhoto }

/// The reserved "finding id" of a Residence / Unit Photo backup row. It is
/// not a finding (no finding row ever has this id); it only tags the row so
/// the queue, the resolver and the Drive metadata can tell the two asset
/// types apart without a schema change.
const String kResidencePhotoFindingId = '__residence_photo__';

/// The backup row id of one Residence / Unit Photo file. Unique per
/// photo file, so replacing the photo queues the new file as its own asset
/// instead of being skipped as "already queued".
String residencePhotoBackupId(String sessionId, String filePath) {
  final name = filePath.split(RegExp(r'[\\/]')).last;
  final stem = name.contains('.')
      ? name.substring(0, name.lastIndexOf('.'))
      : name;
  return 'residence_${sessionId}_$stem';
}

/// One photo's backup record (the queue row).
class DriveBackupEntry {
  const DriveBackupEntry({
    required this.evidenceId,
    required this.sessionId,
    required this.findingId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.driveFileId,
    this.driveFolderId,
    this.backedUpAt,
    this.lastError,
    this.retryCount = 0,
    this.nextAttemptAt,
  });

  final String evidenceId;
  final String sessionId;
  final String findingId;
  final DriveBackupStatus status;
  final String? driveFileId;
  final String? driveFolderId;
  final DateTime? backedUpAt;

  /// A short, safe code (`network`, `auth_required`, `drive_403`, …) —
  /// never a token or raw response body.
  final String? lastError;
  final int retryCount;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVerified => status == DriveBackupStatus.verified;

  /// Defect evidence or the report-cover Residence / Unit Photo.
  DriveAssetType get assetType => findingId == kResidencePhotoFindingId
      ? DriveAssetType.residencePhoto
      : DriveAssetType.findingEvidence;

  DriveBackupEntry copyWith({
    DriveBackupStatus? status,
    String? driveFileId,
    String? driveFolderId,
    DateTime? backedUpAt,
    String? lastError,
    bool clearLastError = false,
    int? retryCount,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    DateTime? updatedAt,
  }) {
    return DriveBackupEntry(
      evidenceId: evidenceId,
      sessionId: sessionId,
      findingId: findingId,
      status: status ?? this.status,
      driveFileId: driveFileId ?? this.driveFileId,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      backedUpAt: backedUpAt ?? this.backedUpAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: clearNextAttemptAt
          ? null
          : (nextAttemptAt ?? this.nextAttemptAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Counts for the Storage & Backup screen.
class DriveBackupCounts {
  const DriveBackupCounts({
    this.waiting = 0,
    this.uploading = 0,
    this.verified = 0,
    this.failed = 0,
    this.notStarted = 0,
  });

  /// Queued (including failures waiting out their backoff are counted
  /// in [failed], not here).
  final int waiting;
  final int uploading;
  final int verified;
  final int failed;
  final int notStarted;
}

/// Persistent storage for the backup queue and its few settings.
abstract class DriveBackupStore {
  /// Records [entry] unless a row for its photo already exists — a photo
  /// is never queued twice. Returns whether it was added.
  Future<bool> insertIfAbsent(DriveBackupEntry entry);

  Future<DriveBackupEntry?> get(String evidenceId);

  Future<void> save(DriveBackupEntry entry);

  Future<void> remove(String evidenceId);

  Future<void> removeSession(String sessionId);

  /// Entries ready to attempt now: `queued`, or `failed` whose backoff
  /// has elapsed — oldest first.
  Future<List<DriveBackupEntry>> due(DateTime now, {int limit = 50});

  Future<List<DriveBackupEntry>> forSession(String sessionId);

  /// Moves every `notStarted` entry to `queued` (Auto Backup turned on).
  Future<int> queueNotStarted(DateTime now);

  /// Puts entries left `uploading` by a stopped app back to `queued`.
  Future<int> resetInterruptedUploads(DateTime now);

  /// Makes every `failed` entry due now (a manual "Retry now").
  Future<int> retryFailedNow(DateTime now);

  Future<DriveBackupCounts> counts();

  Future<String?> readSetting(String key);

  Future<void> writeSetting(String key, String? value);
}

/// Setting keys (never secrets).
abstract final class DriveBackupSettings {
  static const autoBackup = 'drive_auto_backup';
  static const accountEmail = 'drive_account_email';
  static const lastSuccessAt = 'drive_last_success_at';
}

/// A Drive file as the backup needs to know it.
class DriveFileInfo {
  const DriveFileInfo({required this.id, this.size, this.md5Checksum});

  final String id;
  final int? size;
  final String? md5Checksum;
}

/// The access token expired or was revoked — the inspector must
/// reconnect Drive. Never a reason to drop a queued photo.
class DriveAuthRequiredException implements Exception {
  const DriveAuthRequiredException([this.reason = 'auth_required']);

  final String reason;

  @override
  String toString() => 'DriveAuthRequiredException($reason)';
}

/// The network was unavailable or dropped mid-request.
class DriveNetworkException implements Exception {
  const DriveNetworkException();

  @override
  String toString() => 'DriveNetworkException';
}

/// Drive answered with an error status.
class DriveApiException implements Exception {
  const DriveApiException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'DriveApiException($statusCode)';
}

/// The Drive API surface the backup uses — authorized per call with a
/// short-lived access token the platform sign-in SDK provides.
abstract class GoogleDriveClient {
  /// The folder with this stable [folderKey] (stored in the folder's
  /// `appProperties`), creating it under [parentId] if absent. The
  /// human-readable [name] is display only.
  Future<String> ensureFolder({
    required String accessToken,
    required String name,
    required String folderKey,
    String? parentId,
  });

  /// The already-uploaded file for this photo, if any — matched by the
  /// `prodefactEvidenceId` app property, so a retry never duplicates it.
  Future<DriveFileInfo?> findByEvidenceId({
    required String accessToken,
    required String evidenceId,
  });

  /// Uploads [bytes] as a new file in [folderId] with [appProperties].
  Future<DriveFileInfo> upload({
    required String accessToken,
    required String folderId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    required Map<String, String> appProperties,
  });

  /// The file's current metadata, or null if it no longer exists (or was
  /// trashed).
  Future<DriveFileInfo?> getFile({
    required String accessToken,
    required String fileId,
  });

  /// The file's contents (for "View Original").
  Future<List<int>> download({
    required String accessToken,
    required String fileId,
  });
}

/// The connected Google account, for display.
class DriveAccount {
  const DriveAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;
}

/// Google OAuth for Drive, limited to the minimum scope
/// ([kDriveFileScope]: only files this app creates).
abstract class DriveAuthService {
  /// Restores a previous connection silently (no UI); null if none.
  Future<DriveAccount?> restore();

  /// Interactive connect: sign in and grant the Drive file scope.
  Future<DriveAccount> connect();

  /// A current access token without any UI. Throws
  /// [DriveAuthRequiredException] when the inspector must reconnect.
  Future<String> accessToken();

  /// Revokes access and signs out.
  Future<void> disconnect();
}

/// `drive.file` — per-file access to files the app creates or the user
/// opens with it. Not full Drive access.
const kDriveFileScope = 'https://www.googleapis.com/auth/drive.file';

/// Future Firebase original-photo cleanup — prepared, NOT enabled. A
/// Firebase original may only ever be removed once ALL hold: the Drive
/// copy is verified, the retention period has elapsed since that
/// verification, and the policy is enabled. [cleanupEnabled] is false,
/// and nothing in the app deletes Firebase originals.
class FirebaseRetentionPolicy {
  const FirebaseRetentionPolicy({
    this.cleanupEnabled = false,
    this.retention = const Duration(days: 180),
  });

  final bool cleanupEnabled;
  final Duration retention;

  RetentionState stateOf({
    required bool firebaseOriginalPresent,
    required DriveBackupEntry? backup,
    required DateTime now,
  }) {
    final driveVerified = backup?.isVerified == true;
    final verifiedAt = backup?.backedUpAt;
    final retentionElapsed =
        verifiedAt != null && now.difference(verifiedAt) >= retention;
    return RetentionState(
      firebaseOriginalPresent: firebaseOriginalPresent,
      driveVerified: driveVerified,
      eligibleForCleanup:
          cleanupEnabled &&
          firebaseOriginalPresent &&
          driveVerified &&
          retentionElapsed,
    );
  }
}

class RetentionState {
  const RetentionState({
    required this.firebaseOriginalPresent,
    required this.driveVerified,
    required this.eligibleForCleanup,
  });

  final bool firebaseOriginalPresent;
  final bool driveVerified;
  final bool eligibleForCleanup;
}
