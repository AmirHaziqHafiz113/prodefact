import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/inspection/backup/drive_backup.dart';
import '../../core/logging/app_logger.dart';

/// What the backup needs to know about one queued photo — resolved from
/// the local inspection data at upload time.
class DriveBackupPhoto {
  const DriveBackupPhoto({
    required this.evidenceId,
    required this.sessionId,
    required this.findingId,
    required this.sectionId,
    required this.sectionName,
    required this.inspectionTitle,
    required this.inspectionDate,
    required this.originalFilePath,
  });

  final String evidenceId;
  final String sessionId;
  final String findingId;
  final String sectionId;
  final String sectionName;
  final String inspectionTitle;
  final DateTime inspectionDate;

  /// The ORIGINAL photo — never the marked-up copy.
  final String originalFilePath;
}

/// Resolves a queued entry to its photo; null when the photo (or its
/// inspection) no longer exists on this device.
typedef DriveBackupPhotoResolver = Future<DriveBackupPhoto?> Function(
  DriveBackupEntry entry,
);

/// Why the last processing run stopped short, for the settings screen.
enum DriveBackupBlocker { none, notConnected, autoBackupOff, offline, auth }

/// Runs the Google Drive backup queue (see docs/drive_backup.md).
///
/// Guarantees:
/// - **Never blocks the inspection.** [enqueue] only writes one local
///   row and never throws; uploads run later, off the capture path, and
///   AI, sync and report generation never wait for them.
/// - **Survives restarts.** The queue is the `DriveBackupRows` table; an
///   upload interrupted by the app stopping is re-queued on [start].
/// - **No duplicates.** One row per photo; before uploading, Drive is
///   asked for a file already carrying the photo's id (a previous attempt
///   that uploaded but didn't record it), which is adopted instead.
/// - **Verified.** A photo is `verified` only after Drive reports the
///   same size and MD5 as the local original.
/// - **Retries.** Network/server failures back off exponentially
///   (1 min … 6 h); auth expiry pauses the queue (nothing is dropped)
///   until the inspector reconnects; disconnecting Drive stops uploads
///   and keeps the queue for a later reconnect.
class DriveBackupCoordinator {
  DriveBackupCoordinator({
    required this._store,
    required this._client,
    required this._auth,
    required this._resolvePhoto,
    required this._isOnline,
    DateTime Function()? clock,
    this._onVerified,
  }) : _clock = clock ?? DateTime.now;

  final DriveBackupStore _store;
  final GoogleDriveClient _client;
  final DriveAuthService _auth;
  final DriveBackupPhotoResolver _resolvePhoto;
  final bool Function() _isOnline;
  final DateTime Function() _clock;

  /// Called after a photo is verified — mirrors its Drive metadata to the
  /// cloud inspection record. Failures there never undo the backup.
  final Future<void> Function(DriveBackupEntry entry)? _onVerified;

  final _changes = StreamController<void>.broadcast();
  final Map<String, String> _folderIds = {};
  Future<void>? _current;
  bool _rerun = false;
  DriveAccount? _account;
  DriveBackupBlocker _blocker = DriveBackupBlocker.none;

  /// Fires whenever counts/status may have changed.
  Stream<void> get changes => _changes.stream;

  DriveAccount? get account => _account;
  DriveBackupBlocker get blocker => _blocker;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<bool> get autoBackupEnabled async =>
      await _store.readSetting(DriveBackupSettings.autoBackup) == 'true';

  /// The remembered connected account's email (display only).
  Future<String?> get connectedEmail =>
      _store.readSetting(DriveBackupSettings.accountEmail);

  Future<DateTime?> get lastSuccessAt async {
    final raw = await _store.readSetting(DriveBackupSettings.lastSuccessAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// App start: re-queue interrupted uploads, silently restore a previous
  /// Drive connection (only if one was made — never touches Google
  /// Sign-In otherwise), then process.
  Future<void> start() async {
    try {
      await _store.resetInterruptedUploads(_clock());
      if (await connectedEmail != null) {
        _account = await _auth.restore();
      }
    } catch (error) {
      AppLogger.warning('drive_backup_restore_failed', error);
    }
    _notify();
    unawaited(processQueue());
  }

  /// Records a newly saved photo for backup. Queued now when Auto Backup
  /// is on and Drive is connected; otherwise kept as `notStarted` and
  /// queued later. Never throws — a backup problem must never surface on
  /// the capture path.
  Future<void> enqueue({
    required String sessionId,
    required String findingId,
    required String evidenceId,
  }) async {
    try {
      final now = _clock();
      final active = await autoBackupEnabled && await connectedEmail != null;
      final added = await _store.insertIfAbsent(
        DriveBackupEntry(
          evidenceId: evidenceId,
          sessionId: sessionId,
          findingId: findingId,
          status: active
              ? DriveBackupStatus.queued
              : DriveBackupStatus.notStarted,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (added) _notify();
      if (active) unawaited(processQueue());
    } catch (error) {
      AppLogger.warning('drive_backup_enqueue_failed', error);
    }
  }

  /// Interactive: connect Google Drive, remember the account, queue what
  /// was waiting, and start uploading.
  Future<DriveAccount> connect() async {
    final account = await _auth.connect();
    _account = account;
    await _store.writeSetting(DriveBackupSettings.accountEmail, account.email);
    if (await _store.readSetting(DriveBackupSettings.autoBackup) == null) {
      await _store.writeSetting(DriveBackupSettings.autoBackup, 'true');
    }
    _blocker = DriveBackupBlocker.none;
    if (await autoBackupEnabled) await _store.queueNotStarted(_clock());
    _notify();
    unawaited(processQueue());
    return account;
  }

  /// Disconnects Drive. The queue is kept (photos stay safe locally and
  /// in Firebase) and resumes on a later reconnect.
  Future<void> disconnect() async {
    try {
      await _auth.disconnect();
    } catch (error) {
      AppLogger.warning('drive_backup_disconnect_failed', error);
    }
    _account = null;
    _folderIds.clear();
    await _store.writeSetting(DriveBackupSettings.accountEmail, null);
    _blocker = DriveBackupBlocker.notConnected;
    _notify();
  }

  Future<void> setAutoBackup(bool enabled) async {
    await _store.writeSetting(
      DriveBackupSettings.autoBackup,
      enabled ? 'true' : 'false',
    );
    if (enabled) await _store.queueNotStarted(_clock());
    _notify();
    if (enabled) unawaited(processQueue());
  }

  /// Makes failed uploads due now and processes.
  Future<void> retryNow() async {
    await _store.retryFailedNow(_clock());
    _notify();
    await processQueue();
  }

  /// Uploads everything due. Safe to call often: concurrent calls
  /// coalesce into one run (plus one follow-up if work arrived mid-run).
  Future<void> processQueue() {
    final current = _current;
    if (current != null) {
      // A run is in progress: make it go round once more for any work
      // that just arrived, and let this caller wait for it to finish.
      _rerun = true;
      return current;
    }
    return _current = _drain().whenComplete(() {
      _current = null;
      _notify();
    });
  }

  Future<void> _drain() async {
    do {
      _rerun = false;
      await _runOnce();
    } while (_rerun);
  }

  Future<void> _runOnce() async {
    if (await connectedEmail == null) {
      _blocker = DriveBackupBlocker.notConnected;
      return;
    }
    if (!await autoBackupEnabled) {
      _blocker = DriveBackupBlocker.autoBackupOff;
      return;
    }
    if (!_isOnline()) {
      _blocker = DriveBackupBlocker.offline;
      return;
    }
    final due = await _store.due(_clock());
    if (due.isEmpty) {
      _blocker = DriveBackupBlocker.none;
      return;
    }
    final String token;
    try {
      token = await _auth.accessToken();
    } on DriveAuthRequiredException {
      _blocker = DriveBackupBlocker.auth;
      return;
    } catch (error) {
      AppLogger.warning('drive_backup_token_failed', error);
      _blocker = DriveBackupBlocker.auth;
      return;
    }
    _blocker = DriveBackupBlocker.none;
    for (final entry in due) {
      if (!_isOnline()) {
        _blocker = DriveBackupBlocker.offline;
        return;
      }
      final keepGoing = await _backUp(entry, token);
      if (!keepGoing) return;
    }
  }

  /// Backs up one photo. Returns false when the run should stop (auth).
  Future<bool> _backUp(DriveBackupEntry entry, String token) async {
    final photo = await _resolvePhoto(entry);
    if (photo == null) {
      // The photo (or its inspection) was deleted on this device.
      await _store.remove(entry.evidenceId);
      return true;
    }
    final file = File(photo.originalFilePath);
    if (!await file.exists()) {
      await _fail(entry, 'local_file_missing');
      return true;
    }
    var current = entry.copyWith(
      status: DriveBackupStatus.uploading,
      updatedAt: _clock(),
    );
    await _store.save(current);
    _notify();
    try {
      final bytes = await file.readAsBytes();
      final localMd5 = md5.convert(bytes).toString();
      final folderId = await _areaFolder(photo, token);

      // Idempotency: a previous attempt may have uploaded the file but
      // stopped before recording it — adopt that file, never upload a
      // second copy.
      var info = current.driveFileId == null
          ? await _client.findByEvidenceId(
              accessToken: token,
              evidenceId: photo.evidenceId,
            )
          : await _client.getFile(
              accessToken: token,
              fileId: current.driveFileId!,
            );
      info ??= await _client.upload(
        accessToken: token,
        folderId: folderId,
        fileName: _fileName(photo),
        mimeType: 'image/jpeg',
        bytes: bytes,
        appProperties: {
          'prodefactEvidenceId': photo.evidenceId,
          'prodefactInspectionId': photo.sessionId,
          'prodefactFindingId': photo.findingId,
          'prodefactSectionId': photo.sectionId,
        },
      );
      // Record the file id before verifying, so a crash here re-checks
      // this exact file instead of searching or uploading again.
      current = current.copyWith(
        driveFileId: info.id,
        driveFolderId: folderId,
        updatedAt: _clock(),
      );
      await _store.save(current);

      final remote = await _client.getFile(accessToken: token, fileId: info.id);
      final verified =
          remote != null &&
          remote.size == bytes.length &&
          (remote.md5Checksum == null || remote.md5Checksum == localMd5);
      if (!verified) {
        // Not a match (or gone): forget it and upload afresh next time.
        await _fail(
          current.copyWith(driveFileId: null),
          'verify_mismatch',
          clearFileId: true,
        );
        return true;
      }
      final now = _clock();
      final verifiedEntry = current.copyWith(
        status: DriveBackupStatus.verified,
        backedUpAt: now,
        clearLastError: true,
        clearNextAttemptAt: true,
        updatedAt: now,
      );
      await _store.save(verifiedEntry);
      try {
        await _onVerified?.call(verifiedEntry);
      } catch (error) {
        AppLogger.warning('drive_backup_mirror_failed', error);
      }
      await _store.writeSetting(
        DriveBackupSettings.lastSuccessAt,
        now.toIso8601String(),
      );
      _notify();
      return true;
    } on DriveAuthRequiredException {
      // Pause, keep the photo queued (no retry penalty) until reconnect.
      await _store.save(
        current.copyWith(
          status: DriveBackupStatus.queued,
          lastError: 'auth_required',
          updatedAt: _clock(),
        ),
      );
      _blocker = DriveBackupBlocker.auth;
      return false;
    } on DriveNetworkException {
      await _fail(current, 'network');
      return true;
    } on DriveApiException catch (e) {
      await _fail(current, 'drive_${e.statusCode}');
      return true;
    } catch (error) {
      AppLogger.warning('drive_backup_upload_failed', error);
      await _fail(current, 'unexpected');
      return true;
    }
  }

  Future<void> _fail(
    DriveBackupEntry entry,
    String code, {
    bool clearFileId = false,
  }) async {
    final retries = entry.retryCount + 1;
    final now = _clock();
    final failed = DriveBackupEntry(
      evidenceId: entry.evidenceId,
      sessionId: entry.sessionId,
      findingId: entry.findingId,
      status: DriveBackupStatus.failed,
      driveFileId: clearFileId ? null : entry.driveFileId,
      driveFolderId: entry.driveFolderId,
      backedUpAt: entry.backedUpAt,
      lastError: code,
      retryCount: retries,
      nextAttemptAt: now.add(backoffFor(retries)),
      createdAt: entry.createdAt,
      updatedAt: now,
    );
    await _store.save(failed);
    _notify();
  }

  /// 1, 2, 4 … minutes, capped at 6 hours.
  static Duration backoffFor(int retryCount) {
    final minutes = 1 << (retryCount - 1).clamp(0, 12);
    return Duration(minutes: minutes.clamp(1, 360));
  }

  /// `ProDefact/Inspections/<year>/<inspection>/<area>` — each folder found
  /// by a stable key (never by its display name), created once.
  Future<String> _areaFolder(DriveBackupPhoto photo, String token) async {
    final year = '${photo.inspectionDate.year}';
    final shortId = photo.sessionId.length > 8
        ? photo.sessionId.substring(photo.sessionId.length - 8)
        : photo.sessionId;
    final levels = [
      ('ProDefact', 'root'),
      ('Inspections', 'inspections'),
      (year, 'year:$year'),
      (
        _safe('$shortId - ${photo.inspectionTitle}'),
        'inspection:${photo.sessionId}',
      ),
      (_safe(photo.sectionName), 'area:${photo.sessionId}:${photo.sectionId}'),
    ];
    String? parent;
    for (final (name, key) in levels) {
      parent = _folderIds[key] ??= await _client.ensureFolder(
        accessToken: token,
        name: name,
        folderKey: key,
        parentId: parent,
      );
    }
    return parent!;
  }

  static String _fileName(DriveBackupPhoto photo) {
    final d = photo.inspectionDate;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_'
        '${_safe(photo.sectionName)}_${photo.evidenceId}.jpg';
  }

  static String _safe(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]+'), ' ').trim();
    return cleaned.isEmpty ? 'Untitled' : cleaned;
  }

  /// "View Original": the Drive original's bytes, or null when there is
  /// no verified copy or Drive can't be reached (callers fall back to the
  /// on-device / Firebase copy).
  Future<List<int>?> downloadOriginal(String evidenceId) async {
    try {
      final entry = await _store.get(evidenceId);
      if (entry == null || !entry.isVerified || entry.driveFileId == null) {
        return null;
      }
      final token = await _auth.accessToken();
      return await _client.download(
        accessToken: token,
        fileId: entry.driveFileId!,
      );
    } catch (error) {
      AppLogger.warning('drive_original_download_failed', error);
      return null;
    }
  }

  Future<void> dispose() => _changes.close();
}
