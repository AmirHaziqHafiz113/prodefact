import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/inspection/entities/evidence.dart';
import '../../core/inspection/services/evidence_capture_service.dart';

/// Thrown by [ImagePickerEvidenceCaptureService] when acquiring or
/// importing a photo fails (permission denied, picker platform error,
/// disk full/unreadable during the copy into app-managed storage).
/// Callers should show [message] to the user rather than a raw
/// exception — see `docs/production_readiness.md` ("Error handling").
class EvidenceCaptureException implements Exception {
  const EvidenceCaptureException(this.message);

  final String message;

  @override
  String toString() => 'EvidenceCaptureException: $message';
}

/// Production [EvidenceCaptureService]: uses `image_picker` to acquire a
/// photo, then copies it into an app-managed `evidence/<findingId>/`
/// directory under the app's documents directory so the reference stays
/// valid regardless of where the OS put the original temp file.
class ImagePickerEvidenceCaptureService implements EvidenceCaptureService {
  ImagePickerEvidenceCaptureService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CapturedEvidence?> captureImage({
    required String findingId,
    required EvidenceSource source,
  }) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source == EvidenceSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // QA #19: keep the evidence close to the camera original. A
        // symmetric 4096px bound leaves typical 12MP phone photos
        // (4032x3024) untouched, applies equally to portrait and
        // landscape (the old width-only 2000px cap shrank landscape
        // photos more), never crops, and keeps aspect ratio. Setting a
        // quality also makes iOS return JPEG rather than HEIC, which the
        // report renderer and the AI pipeline can't read. The AI gets
        // its own smaller copy server-side (1568px, JPEG 82).
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 95,
      );
    } catch (error) {
      // Most commonly a `PlatformException` for camera/photo-library
      // permission denial — surfaced as one friendly, generic message
      // rather than a raw platform exception reaching the UI.
      throw EvidenceCaptureException(
        'Could not access the camera/photo library ($error).',
      );
    }
    if (picked == null) return null;

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final evidenceDir = Directory(
        p.join(documentsDir.path, 'evidence', findingId),
      );
      await evidenceDir.create(recursive: true);

      final extension = p.extension(picked.path);
      final destinationPath = p.join(
        evidenceDir.path,
        '${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}',
      );
      await File(picked.path).copy(destinationPath);

      return CapturedEvidence(filePath: destinationPath, source: source);
    } catch (error) {
      throw EvidenceCaptureException('Could not save that photo ($error).');
    }
  }
}
