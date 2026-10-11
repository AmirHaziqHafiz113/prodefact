import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../core/inspection/backup/drive_backup.dart';

/// Merges a verified photo's Drive metadata onto its cloud evidence
/// record (`users/{uid}/inspections/{id}/findings/{id}/evidence/{id}`) —
/// merged, so the sync's own fields are never overwritten — so history
/// on another device knows where the original lives. Never OAuth data.
Future<void> mirrorDriveMetadataToFirestore(
  String uid,
  DriveBackupEntry entry, {
  fs.FirebaseFirestore? firestore,
}) {
  return (firestore ?? fs.FirebaseFirestore.instance)
      .collection('users')
      .doc(uid)
      .collection('inspections')
      .doc(entry.sessionId)
      .collection('findings')
      .doc(entry.findingId)
      .collection('evidence')
      .doc(entry.evidenceId)
      .set({
        'driveFileId': entry.driveFileId,
        'driveFolderId': entry.driveFolderId,
        'driveBackupStatus': entry.status.name,
        'driveBackedUpAt': entry.backedUpAt == null
            ? null
            : fs.Timestamp.fromDate(entry.backedUpAt!),
        // Retention states (cleanup is prepared, not enabled): the
        // Firebase original is kept.
        'firebaseOriginalPresent': true,
        'driveVerified': entry.isVerified,
        'eligibleForCleanup': false,
      }, fs.SetOptions(merge: true));
}
