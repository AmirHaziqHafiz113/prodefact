import 'package:drift/drift.dart';

import '../../core/inspection/backup/drive_backup.dart';
import '../local/database.dart';

/// The Drive backup queue in the on-device database (`DriveBackupRows`,
/// `AppSettingRows`, schema v18) — so the queue survives restarts.
class DriftDriveBackupStore implements DriveBackupStore {
  DriftDriveBackupStore(this._db);

  final AppDatabase _db;

  DriveBackupEntry _fromRow(DriveBackupRow row) => DriveBackupEntry(
    evidenceId: row.evidenceId,
    sessionId: row.sessionId,
    findingId: row.findingId,
    status: driveBackupStatusFromName(row.status),
    driveFileId: row.driveFileId,
    driveFolderId: row.driveFolderId,
    backedUpAt: row.backedUpAt,
    lastError: row.lastError,
    retryCount: row.retryCount,
    nextAttemptAt: row.nextAttemptAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  DriveBackupRowsCompanion _toCompanion(DriveBackupEntry e) =>
      DriveBackupRowsCompanion(
        evidenceId: Value(e.evidenceId),
        sessionId: Value(e.sessionId),
        findingId: Value(e.findingId),
        status: Value(e.status.name),
        driveFileId: Value(e.driveFileId),
        driveFolderId: Value(e.driveFolderId),
        backedUpAt: Value(e.backedUpAt),
        lastError: Value(e.lastError),
        retryCount: Value(e.retryCount),
        nextAttemptAt: Value(e.nextAttemptAt),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
      );

  @override
  Future<bool> insertIfAbsent(DriveBackupEntry entry) async {
    final inserted = await _db
        .into(_db.driveBackupRows)
        .insert(_toCompanion(entry), mode: InsertMode.insertOrIgnore);
    return inserted > 0;
  }

  @override
  Future<DriveBackupEntry?> get(String evidenceId) async {
    final row = await (_db.select(
      _db.driveBackupRows,
    )..where((t) => t.evidenceId.equals(evidenceId))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> save(DriveBackupEntry entry) async {
    await _db
        .into(_db.driveBackupRows)
        .insertOnConflictUpdate(_toCompanion(entry));
  }

  @override
  Future<void> remove(String evidenceId) async {
    await (_db.delete(
      _db.driveBackupRows,
    )..where((t) => t.evidenceId.equals(evidenceId))).go();
  }

  @override
  Future<void> removeSession(String sessionId) async {
    await (_db.delete(
      _db.driveBackupRows,
    )..where((t) => t.sessionId.equals(sessionId))).go();
  }

  @override
  Future<List<DriveBackupEntry>> due(DateTime now, {int limit = 50}) async {
    final rows =
        await (_db.select(_db.driveBackupRows)
              ..where(
                (t) =>
                    t.status.equals(DriveBackupStatus.queued.name) |
                    (t.status.equals(DriveBackupStatus.failed.name) &
                        (t.nextAttemptAt.isNull() |
                            t.nextAttemptAt.isSmallerOrEqualValue(now))),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<DriveBackupEntry>> forSession(String sessionId) async {
    final rows = await (_db.select(
      _db.driveBackupRows,
    )..where((t) => t.sessionId.equals(sessionId))).get();
    return rows.map(_fromRow).toList();
  }

  Future<int> _moveStatus(
    DriveBackupStatus from,
    DriveBackupStatus to,
    DateTime now,
  ) {
    return (_db.update(
      _db.driveBackupRows,
    )..where((t) => t.status.equals(from.name))).write(
      DriveBackupRowsCompanion(status: Value(to.name), updatedAt: Value(now)),
    );
  }

  @override
  Future<int> queueNotStarted(DateTime now) =>
      _moveStatus(DriveBackupStatus.notStarted, DriveBackupStatus.queued, now);

  @override
  Future<int> resetInterruptedUploads(DateTime now) =>
      _moveStatus(DriveBackupStatus.uploading, DriveBackupStatus.queued, now);

  @override
  Future<int> retryFailedNow(DateTime now) {
    return (_db.update(
      _db.driveBackupRows,
    )..where((t) => t.status.equals(DriveBackupStatus.failed.name))).write(
      DriveBackupRowsCompanion(
        nextAttemptAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<DriveBackupCounts> counts() async {
    final count = _db.driveBackupRows.evidenceId.count();
    final rows =
        await (_db.selectOnly(_db.driveBackupRows)
              ..addColumns([_db.driveBackupRows.status, count])
              ..groupBy([_db.driveBackupRows.status]))
            .get();
    int of(DriveBackupStatus status) =>
        rows
            .where((r) => r.read(_db.driveBackupRows.status) == status.name)
            .map((r) => r.read(count) ?? 0)
            .firstOrNull ??
        0;
    return DriveBackupCounts(
      waiting: of(DriveBackupStatus.queued),
      uploading: of(DriveBackupStatus.uploading),
      verified: of(DriveBackupStatus.verified),
      failed: of(DriveBackupStatus.failed),
      notStarted: of(DriveBackupStatus.notStarted),
    );
  }

  @override
  Future<String?> readSetting(String key) async {
    final row = await (_db.select(
      _db.appSettingRows,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> writeSetting(String key, String? value) async {
    if (value == null) {
      await (_db.delete(
        _db.appSettingRows,
      )..where((t) => t.key.equals(key))).go();
      return;
    }
    await _db
        .into(_db.appSettingRows)
        .insertOnConflictUpdate(
          AppSettingRowsCompanion.insert(key: key, value: value),
        );
  }
}
