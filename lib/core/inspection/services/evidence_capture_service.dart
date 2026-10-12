import '../entities/evidence.dart';

/// Technical SAFETY CEILING for one gallery selection — not a product
/// limit. A selection is never silently truncated: if the platform returns
/// more than this, the whole selection is refused with a clear message so
/// the inspector can pick fewer. Raise or lower it per build with
/// `--dart-define=MAX_GALLERY_PHOTOS=<n>`; 100 findings per pick keeps the
/// copy-into-app-storage step and the findings list responsive.
const int kMaxGalleryPhotosPerSelection = int.fromEnvironment(
  'MAX_GALLERY_PHOTOS',
  defaultValue: 100,
);

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

  /// Acquires several photos in one action. From the gallery the
  /// inspector can select many at once (up to the technical safety
  /// ceiling [maxImages], [kMaxGalleryPhotosPerSelection] by default —
  /// never silently truncated); the camera still takes a single shot.
  /// Each photo becomes its own finding. Returns an empty list if
  /// cancelled.
  Future<List<CapturedEvidence>> captureImages({
    required String findingId,
    required EvidenceSource source,
    int maxImages = kMaxGalleryPhotosPerSelection,
  });
}
