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
        // QA #19 + #26: high-quality evidence that still uploads fast
        // on a phone connection. A symmetric 2560px bound applies equally
        // to portrait and landscape, never crops, keeps aspect ratio, and
        // exceeds what an A4 report prints at 300 dpi (~2480px). The
        // previous 4096px / quality 95 produced ~4-6 MB files whose
        // upload dominated the wait before AI could start; this is
        // roughly a quarter of that. Setting a quality also makes iOS
        // return JPEG rather than HEIC, which the report renderer and
        // the AI pipeline need. The AI gets its own smaller copy
        // server-side (1568px, JPEG 82).
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
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
    return CapturedEvidence(
      filePath: await _copyIntoEvidenceDir(findingId, picked),
      source: source,
    );
  }

  @override
  Future<List<CapturedEvidence>> captureImages({
    required String findingId,
    required EvidenceSource source,
    int maxImages = 3,
  }) async {
    if (source == EvidenceSource.camera) {
      final single = await captureImage(findingId: findingId, source: source);
      return single == null ? const [] : [single];
    }
    final List<XFile> picked;
    try {
      // Same quality bound as a single pick: whole photo, no crop.
      picked = await _picker.pickMultiImage(
        limit: maxImages,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
      );
    } catch (error) {
      throw EvidenceCaptureException(
        'Could not access the photo library ($error).',
      );
    }
    final captured = <CapturedEvidence>[];
    // Some platforms ignore `limit`; never attach more than asked.
    for (final file in picked.take(maxImages)) {
      captured.add(
        CapturedEvidence(
          filePath: await _copyIntoEvidenceDir(findingId, file),
          source: source,
        ),
      );
    }
    return captured;
  }

  Future<String> _copyIntoEvidenceDir(String findingId, XFile picked) async {
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
      return destinationPath;
    } catch (error) {
      throw EvidenceCaptureException('Could not save that photo ($error).');
    }
  }
}
