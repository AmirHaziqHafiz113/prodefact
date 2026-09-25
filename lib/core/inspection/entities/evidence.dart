import 'sync_status.dart';

/// The kind of media an [Evidence] record holds. Photos only for now —
/// other media types can be added without changing existing rows.
enum EvidenceMediaType { photo }

/// Where an [Evidence] photo was acquired from.
enum EvidenceSource { camera, gallery }

/// A piece of evidence (currently just a photo) captured for a [Finding]
/// during the physical inspection.
///
/// Stores a local file reference, not raw bytes: the file itself lives
/// in an app-managed directory (see the evidence storage service), and
/// this record only tracks metadata about it. [storagePath] is filled in
/// once the file has been uploaded to cloud storage — the local
/// [filePath] is preserved regardless, so the app keeps working offline
/// even after a successful sync.
class Evidence {
  const Evidence({
    required this.id,
    required this.findingId,
    required this.filePath,
    required this.createdAt,
    this.mediaType = EvidenceMediaType.photo,
    this.source = EvidenceSource.gallery,
    this.caption,
    this.syncStatus = SyncStatus.localOnly,
    this.storagePath,
    this.annotatedFilePath,
  });

  final String id;
  final String findingId;

  /// Path to the file on local device storage. Never raw image bytes.
  final String filePath;

  final DateTime createdAt;
  final EvidenceMediaType mediaType;
  final EvidenceSource source;
  final String? caption;
  final SyncStatus syncStatus;

  /// Where this file lives in cloud storage once uploaded (see the
  /// Storage path model in `docs/firebase.md`). Null until the first
  /// successful upload.
  final String? storagePath;

  /// A marked-up copy of this photo (QA #14), saved as a separate local
  /// file. [filePath] — the original — is never modified or replaced:
  /// the original stays the audit record and is what AI analyses, while
  /// the report shows the inspector's markup. Null when not annotated.
  final String? annotatedFilePath;

  /// What to show the inspector and the report: the annotated copy when
  /// one exists, otherwise the original.
  String get displayFilePath => annotatedFilePath ?? filePath;

  bool get isAnnotated => annotatedFilePath != null;

  Evidence copyWith({
    String? caption,
    SyncStatus? syncStatus,
    String? storagePath,
    String? annotatedFilePath,
  }) {
    return Evidence(
      id: id,
      findingId: findingId,
      filePath: filePath,
      createdAt: createdAt,
      mediaType: mediaType,
      source: source,
      caption: caption ?? this.caption,
      syncStatus: syncStatus ?? this.syncStatus,
      storagePath: storagePath ?? this.storagePath,
      annotatedFilePath: annotatedFilePath ?? this.annotatedFilePath,
    );
  }

  @override
  String toString() => 'Evidence($id, $filePath)';
}
