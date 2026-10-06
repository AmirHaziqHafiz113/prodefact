import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';

/// Page 1 "Residence / Unit Photo": optional, fitted (never stretched)
/// into a fixed box, and absent without leaving a blank hole.

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _png(int width, int height) {
  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, data.length))
      ..add(body)
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, _crc(body)));
  }

  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  chunk(
    'IHDR',
    Uint8List(13)
      ..buffer.asByteData().setUint32(0, width)
      ..buffer.asByteData().setUint32(4, height)
      ..[8] = 8
      ..[9] = 2,
  );
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      raw.add([30, 120, 200]);
    }
  }
  chunk('IDAT', ZLibEncoder().convert(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

ReportModel _model({String? coverPhotoPath}) => ReportModel(
  sessionId: 'session_cover',
  propertyTypeLabel: 'High Rise',
  inspectionDate: DateTime(2026, 1, 1),
  generatedAt: DateTime(2026, 1, 2),
  totalAreas: 1,
  completedAreas: 1,
  totalFindings: 0,
  totalEvidence: 0,
  areas: const [
    ReportAreaSection(name: 'Kitchen', isPlumbing: true, findings: []),
  ],
  coverPhotoPath: coverPhotoPath,
);

String _pdfText(Uint8List bytes) => latin1.decode(bytes);

int _pageCount(String pdf) => RegExp(r'/Type\s*/Page\b').allMatches(pdf).length;

int _imageCount(String pdf) =>
    RegExp(r'/Subtype\s*/Image').allMatches(pdf).length;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prodefact_cover'));
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'with no photo: no image, no blank box — same pages as before',
    () async {
      final pdf = _pdfText(
        await PdfReportRenderer(compress: false).render(_model()),
      );
      expect(_imageCount(pdf), 0);
      expect(_pageCount(pdf), 2);
    },
  );

  test('with a photo it appears on page 1 and does not add a page', () async {
    final file = File('${dir.path}/unit.png')..writeAsBytesSync(_png(300, 100));
    final pdf = _pdfText(
      await PdfReportRenderer(compress: false)
          .render(_model(coverPhotoPath: file.path)),
    );
    // The image XObject (plus its soft mask, if the encoder writes one).
    expect(_imageCount(pdf), greaterThanOrEqualTo(1));
    expect(_pageCount(pdf), 2, reason: 'page 1 still holds cover + summary');
  });

  test('aspect ratio is preserved for wide and tall photos (never '
      'stretched to the box)', () async {
    for (final size in [(w: 300, h: 100), (w: 100, h: 300)]) {
      final file = File('${dir.path}/unit_${size.w}x${size.h}.png')
        ..writeAsBytesSync(_png(size.w, size.h));
      final pdf = _pdfText(
        await PdfReportRenderer(compress: false)
            .render(_model(coverPhotoPath: file.path)),
      );
      // "<w> 0 0 <h> <x> <y> cm /Imn Do" — the image's placed size.
      final match = RegExp(
        r'([\d.]+)\s+0\s+0\s+([\d.]+)\s+[\d.\-]+\s+[\d.\-]+\s+cm\s*\n?\s*/\w+\s+Do',
      ).firstMatch(pdf);
      expect(match, isNotNull, reason: 'image placement not found');
      final placedRatio =
          double.parse(match!.group(1)!) / double.parse(match.group(2)!);
      expect(placedRatio, closeTo(size.w / size.h, 0.02));
    }
  });

  test('a missing or unreadable photo file is skipped without failing '
      'the report', () async {
    final bad = File('${dir.path}/broken.png')..writeAsBytesSync([1, 2, 3]);
    for (final path in ['${dir.path}/gone.png', bad.path]) {
      final bytes = await PdfReportRenderer(compress: false)
          .render(_model(coverPhotoPath: path));
      expect(_pdfText(bytes).startsWith('%PDF-'), isTrue);
      expect(_imageCount(_pdfText(bytes)), 0);
    }
  });
}
