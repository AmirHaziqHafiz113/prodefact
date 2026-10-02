import '../entities/ai_finding_status.dart';
import '../entities/ai_level.dart';
import '../entities/sync_status.dart';

/// One finding's place in the AI queue, for QA diagnostics (debug logs
/// only). Holds safe facts only — never the note, photo, or any key.
class AiQueueDiagnostic {
  const AiQueueDiagnostic({
    required this.findingId,
    this.aiStatus,
    this.uploadStatus,
    this.aiLevel,
    this.retryCount = 0,
    this.lastTransitionAt,
    this.lastErrorCode,
  });

  final String findingId;
  final AiFindingStatus? aiStatus;
  final SyncStatus? uploadStatus;
  final AiLevel? aiLevel;
  final int retryCount;
  final DateTime? lastTransitionAt;

  /// A short, safe code such as `offline`, `signedOut`, `upload_timeout`
  /// or `ai_failure` — never a raw error message.
  final String? lastErrorCode;

  AiQueueDiagnostic copyWith({
    AiFindingStatus? aiStatus,
    SyncStatus? uploadStatus,
    AiLevel? aiLevel,
    int? retryCount,
    DateTime? lastTransitionAt,
    String? lastErrorCode,
  }) => AiQueueDiagnostic(
    findingId: findingId,
    aiStatus: aiStatus ?? this.aiStatus,
    uploadStatus: uploadStatus ?? this.uploadStatus,
    aiLevel: aiLevel ?? this.aiLevel,
    retryCount: retryCount ?? this.retryCount,
    lastTransitionAt: lastTransitionAt ?? this.lastTransitionAt,
    lastErrorCode: lastErrorCode ?? this.lastErrorCode,
  );

  String toLogString() =>
      'finding=$findingId ai=${aiStatus?.name} '
      'upload=${uploadStatus?.name} level=${aiLevel?.name} '
      'retries=$retryCount '
      'last=${lastTransitionAt?.toIso8601String()} '
      'error=${lastErrorCode ?? '-'}';
}
