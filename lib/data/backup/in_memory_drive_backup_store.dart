import '../../core/inspection/backup/drive_backup.dart';

/// A non-persistent [DriveBackupStore] — for repositories that aren't
/// database-backed (and for tests).
class InMemoryDriveBackupStore implements DriveBackupStore {
  final Map<String, DriveBackupEntry> entries = {};
  final Map<String, String> settings = {};

  @override
  Future<bool> insertIfAbsent(DriveBackupEntry entry) async {
    if (entries.containsKey(entry.evidenceId)) return false;
    entries[entry.evidenceId] = entry;
    return true;
  }

  @override
  Future<DriveBackupEntry?> get(String evidenceId) async => entries[evidenceId];

  @override
  Future<void> save(DriveBackupEntry entry) async =>
      entries[entry.evidenceId] = entry;

  @override
  Future<void> remove(String evidenceId) async => entries.remove(evidenceId);

  @override
  Future<void> removeSession(String sessionId) async =>
      entries.removeWhere((_, e) => e.sessionId == sessionId);

  @override
  Future<List<DriveBackupEntry>> due(DateTime now, {int limit = 50}) async {
    final due =
        entries.values
            .where(
              (e) =>
                  e.status == DriveBackupStatus.queued ||
                  (e.status == DriveBackupStatus.failed &&
                      (e.nextAttemptAt == null ||
                          !e.nextAttemptAt!.isAfter(now))),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return due.take(limit).toList();
  }

  @override
  Future<List<DriveBackupEntry>> forSession(String sessionId) async =>
      entries.values.where((e) => e.sessionId == sessionId).toList();

  Future<int> _move(DriveBackupStatus from, DriveBackupStatus to) async {
    var n = 0;
    for (final e in entries.values.toList()) {
      if (e.status == from) {
        entries[e.evidenceId] = e.copyWith(status: to);
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> queueNotStarted(DateTime now) =>
      _move(DriveBackupStatus.notStarted, DriveBackupStatus.queued);

  @override
  Future<int> resetInterruptedUploads(DateTime now) =>
      _move(DriveBackupStatus.uploading, DriveBackupStatus.queued);

  @override
  Future<int> retryFailedNow(DateTime now) async {
    var n = 0;
    for (final e in entries.values.toList()) {
      if (e.status == DriveBackupStatus.failed) {
        entries[e.evidenceId] = e.copyWith(clearNextAttemptAt: true);
        n++;
      }
    }
    return n;
  }

  @override
  Future<DriveBackupCounts> counts() async {
    int of(DriveBackupStatus s) =>
        entries.values.where((e) => e.status == s).length;
    return DriveBackupCounts(
      waiting: of(DriveBackupStatus.queued),
      uploading: of(DriveBackupStatus.uploading),
      verified: of(DriveBackupStatus.verified),
      failed: of(DriveBackupStatus.failed),
      notStarted: of(DriveBackupStatus.notStarted),
    );
  }

  @override
  Future<String?> readSetting(String key) async => settings[key];

  @override
  Future<void> writeSetting(String key, String? value) async {
    if (value == null) {
      settings.remove(key);
    } else {
      settings[key] = value;
    }
  }
}
