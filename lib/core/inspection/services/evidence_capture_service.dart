import '../entities/evidence.dart';

/// Result of successfully acquiring one photo for a finding: where it
/// now lives in app-managed local storage.
class CapturedEvidence {
  const CapturedEvidence({required this.filePath, required this.source});

  final String filePath;
  final EvidenceSource source;
}

/// Acquires a photo (camera or gallery) and imports it into app-managed
/// local storage, returning a stable local path Evidence can reference.
///
/// Kept as an abstraction so the UI/providers never depend on
/// `image_picker` directly, and so tests can substitute a fake instead
/// of driving a real device camera/gallery picker.
abstract class EvidenceCaptureService {
  /// Returns null if the user cancels the picker without choosing a
  /// photo.
  Future<CapturedEvidence?> captureImage({
    required String findingId,
    required EvidenceSource source,
  });
}
