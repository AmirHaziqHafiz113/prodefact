import 'dart:math' as math;
import 'dart:typed_data';

/// A possible problem with a captured photo, found locally (no AI call).
/// Advisory only — never a reason to block saving a finding.
enum LocalImageIssue {
  unreadable,
  lowResolution,
  tooDark,
  overexposed,
  blurry;

  String get label => switch (this) {
    LocalImageIssue.unreadable => 'Photo could not be read',
    LocalImageIssue.lowResolution => 'Photo resolution is low',
    LocalImageIssue.tooDark => 'Image appears too dark',
    LocalImageIssue.overexposed => 'Image appears overexposed',
    LocalImageIssue.blurry => 'Image appears blurry',
  };
}

class ImageQualityAssessment {
  const ImageQualityAssessment([this.issues = const []]);

  /// Nothing worth mentioning (also used when a check couldn't run).
  static const clear = ImageQualityAssessment();

  final List<LocalImageIssue> issues;

  bool get looksClear => issues.isEmpty;
}

/// A cheap, local quality hint for a captured photo — never an AI
/// request. Implementations must never throw: a check that can't run
/// reports [ImageQualityAssessment.clear] rather than nagging.
abstract class ImageQualityService {
  Future<ImageQualityAssessment> assess(String filePath);
}

/// Thresholds are deliberately loose: the goal is to catch an obviously
/// dark, blown-out or out-of-focus photo, not to grade framing.
const kMinShortSidePx = 480;
const kTooDarkMeanLuma = 45.0;
const kTooDarkP90Luma = 90.0;
const kOverexposedFraction = 0.5;
const kBlurLaplacianVariance = 12.0;

/// Only judged blurry if the scene has real contrast: a plain wall or
/// tile is naturally low-detail and must not be called blurry.
const kBlurMinLumaStdDev = 25.0;

/// Scores a downscaled RGBA copy of a photo ([width] x [height]) whose
/// original size was [sourceWidth] x [sourceHeight].
ImageQualityAssessment assessPixels({
  required int sourceWidth,
  required int sourceHeight,
  required int width,
  required int height,
  required Uint8List rgba,
}) {
  final issues = <LocalImageIssue>[];
  if (math.min(sourceWidth, sourceHeight) < kMinShortSidePx) {
    issues.add(LocalImageIssue.lowResolution);
  }
  final count = width * height;
  if (count == 0 || rgba.length < count * 4) {
    return ImageQualityAssessment(issues);
  }

  final luma = Float64List(count);
  var sum = 0.0;
  var bright = 0;
  for (var i = 0; i < count; i++) {
    final r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    luma[i] = y;
    sum += y;
    if (y > 250) bright++;
  }
  final mean = sum / count;
  var sq = 0.0;
  for (final y in luma) {
    sq += (y - mean) * (y - mean);
  }
  final stdDev = math.sqrt(sq / count);
  final sorted = Float64List.fromList(luma)..sort();
  final p90 = sorted[(count * 0.9).floor().clamp(0, count - 1)];

  if (mean < kTooDarkMeanLuma && p90 < kTooDarkP90Luma) {
    issues.add(LocalImageIssue.tooDark);
  }
  if (bright / count > kOverexposedFraction) {
    issues.add(LocalImageIssue.overexposed);
  }

  // Variance of the Laplacian: low when edges are soft (out of focus or
  // motion blur).
  if (width >= 3 && height >= 3 && stdDev >= kBlurMinLumaStdDev) {
    var lapSum = 0.0;
    var lapSq = 0.0;
    var n = 0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final c = y * width + x;
        final lap =
            luma[c - width] +
            luma[c + width] +
            luma[c - 1] +
            luma[c + 1] -
            4 * luma[c];
        lapSum += lap;
        lapSq += lap * lap;
        n++;
      }
    }
    final lapMean = lapSum / n;
    final lapVariance = lapSq / n - lapMean * lapMean;
    if (lapVariance < kBlurLaplacianVariance) {
      issues.add(LocalImageIssue.blurry);
    }
  }
  return ImageQualityAssessment(issues);
}
