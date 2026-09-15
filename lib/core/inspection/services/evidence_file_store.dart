/// Deletes app-managed evidence photo files from local storage.
///
/// Kept separate from [EvidenceCaptureService] (which only *acquires*
/// files) so cleanup — on evidence removal, finding deletion, and
/// session deletion — goes through one seam that tests can fake instead
/// of touching the real device filesystem. See
/// `docs/production_readiness.md` ("Local file lifecycle").
abstract class EvidenceFileStore {
  /// Deletes the file at [filePath] if it exists. Never throws if the
  /// file is already missing — a stale/already-cleaned-up reference is
  /// not an error.
  Future<void> deleteEvidenceFile(String filePath);
}
