import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/services/image_quality_service.dart';
import '../../core/logging/app_logger.dart';

/// Local photo-quality hints with Flutter's own image decoder — no
/// native dependency and no AI request. The photo is decoded at a small
/// size (160 px wide) and scored by [assessPixels].
class BasicImageQualityService implements ImageQualityService {
  static const _sampleWidth = 160;
  static const _timeout = Duration(seconds: 3);

  @override
  Future<ImageQualityAssessment> assess(String filePath) async {
    try {
      return await _assess(filePath).timeout(_timeout);
    } on TimeoutException {
      return ImageQualityAssessment.clear;
    } catch (error) {
      AppLogger.warning('Photo quality check could not read the photo', error);
      return const ImageQualityAssessment([LocalImageIssue.unreadable]);
    }
  }

  Future<ImageQualityAssessment> _assess(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final sourceWidth = descriptor.width;
    final sourceHeight = descriptor.height;
    final codec = await descriptor.instantiateCodec(
      targetWidth: sourceWidth > _sampleWidth ? _sampleWidth : sourceWidth,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return ImageQualityAssessment.clear;
      return assessPixels(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        width: image.width,
        height: image.height,
        rgba: data.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

final imageQualityServiceProvider = Provider<ImageQualityService>(
  (ref) => BasicImageQualityService(),
);
