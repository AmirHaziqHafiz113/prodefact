import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/inspection/entities/evidence.dart';
import '../../core/inspection/services/evidence_capture_service.dart';

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
    final picked = await _picker.pickImage(
      source: source == EvidenceSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (picked == null) return null;

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
  }
}
