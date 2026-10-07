import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';

import '../support/png_fixture.dart';

/// Report page usage (2026-10-08): the defect table packs rows down the
/// whole printable A4 height instead of stopping early, the cover leads
/// with a large Residence / Unit Photo, and a long row moves to the next
/// page only when it cannot fit.
///
/// Set PRODEFACT_SAMPLE_REPORT_DIR to a folder holding landscape.jpg,
/// portrait.jpg, square.jpg, wide.jpg and cover.jpg to also write
/// sample.pdf there for a visual check.

/// Lowest y (PDF origin bottom-left) the body may reach: the bottom
/// margin (28) plus the footer block and its gap (~31).
const _bodyFloorY = 59.0;

/// One full table row with a photo is ~135pt.
const _oneRow = 135.0;

final _sampleDir = Platform.environment['PRODEFACT_SAMPLE_REPORT_DIR'];

ReportFinding _finding(
  int n, {
  String? recommendation,
  String? notes,
  List<String> photos = const [],
  String component = 'Floor Tile',
}) => ReportFinding(
  number: n,
  elementName: 'Floor',
  componentName: component,
  defectType: 'Finding $n hollow sound when tapped',
  recommendation: recommendation ?? 'Rec$n re-lay affected tiles',
  notes: notes,
  evidenceFilePaths: photos,
);

ReportModel _model(List<ReportFinding> findings, {String? coverPhoto}) =>
    ReportModel(
      sessionId: 'session_usage',
      propertyTypeLabel: 'High Rise',
      inspectionDate: DateTime(2026, 10, 1, 9),
      generatedAt: DateTime(2026, 10, 2),
      totalAreas: 1,
      completedAreas: 1,
      totalFindings: findings.length,
      totalEvidence: 0,
      areas: [
        ReportAreaSection(
          name: 'Living',
          isPlumbing: false,
          findings: findings,
        ),
      ],
      propertyTitle: 'Residensi Test',
      clientName: 'Siti',
      inspectorName: 'Aman',
      contactNumber: '011-2233 4455',
      coverPhotoPath: coverPhoto,
    );

class _Page {
  _Page(this.content);
  final String content;

  /// The drawn words are one `[(word)]TJ` each.
  bool has(String word) => content.contains('[($word)]TJ');

  int count(String word) => '[($word)]TJ'.allMatches(content).length;

  /// The table's outer border is the one absolute-coordinate
  /// `36 <y> 523.. <h> re S`: [tableBottomY] is where the last row ends.
  late final RegExpMatch? _outline = RegExp(
    r'36 ([\d.]+) 523\.\d+ ([\d.]+) re S',
  ).firstMatch(content);
  double get tableBottomY => double.parse(_outline!.group(1)!);
}

/// Each page's content stream, in page order (uncompressed PDF).
List<_Page> _pages(Uint8List bytes) {
  final pdf = latin1.decode(bytes);
  final objects = <String, String>{
    for (final m in RegExp(
      r'(\d+) 0 obj(.*?)endobj',
      dotAll: true,
    ).allMatches(pdf))
      m.group(1)!: m.group(2)!,
  };
  final kids = RegExp(r'/Kids\s*\[([^\]]*)\]')
      .firstMatch(
        objects.values.firstWhere((o) => RegExp(r'/Type\s*/Pages').hasMatch(o)),
      )!
      .group(1)!;
  return [
    for (final id in RegExp(r'(\d+) 0 R').allMatches(kids).map((m) => m[1]!))
      _Page(
        [
          for (final ref in RegExp(r'(\d+) 0 R').allMatches(
            RegExp(r'/Contents\s*(\[[^\]]*\]|\d+ 0 R)')
                .firstMatch(objects[id]!)!
                .group(1)!,
          ))
            objects[ref.group(1)!]!,
        ].join('\n'),
      ),
  ];
}

Future<List<_Page>> _render(ReportModel model) async =>
    _pages(await PdfReportRenderer(compress: false).render(model));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prodefact_usage'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('cover', () {
    test('the cover photo is rendered large and fitted inside its box '
        '(aspect ratio preserved)', () async {
      final photo = writePng(dir, 'unit', 400, 300);
      final bytes = await PdfReportRenderer(compress: false)
          .render(_model(const [], coverPhoto: photo));
      final pdf = latin1.decode(bytes);
      final m = RegExp(r'([\d.]+) 0 0 ([\d.]+) [\d.\-]+ [\d.\-]+ cm\s*/I\d+ Do')
          .firstMatch(pdf)!;
      final w = double.parse(m[1]!), h = double.parse(m[2]!);
      expect(w / h, closeTo(400 / 300, 0.01));
      // The box is 523 x 420 (less padding): the 4:3 photo fills its
      // height, so it is a hero image, not a thumbnail.
      expect(h, greaterThan(370));
      expect(w, lessThanOrEqualTo(523.3));
    });

    test('with no photo the same box stays as a placeholder', () async {
      final pages = await _render(_model(const []));
      expect(pages.first.has('Residence'), isTrue);
    });
  });

  group('table page usage', () {
    test('no premature break: every full page is packed to within one '
        'row of the footer, about five rows per page', () async {
      final photo = writePng(dir, 'p', 400, 300);
      final pages = await _render(
        _model([
          for (var n = 1; n <= 17; n++) _finding(n, photos: [photo]),
        ]),
      );
      final table = pages.skip(1).toList();
      for (final p in table.take(table.length - 1)) {
        expect(
          p.tableBottomY,
          lessThan(_bodyFloorY + _oneRow),
          reason: 'blank band at the bottom of a full page',
        );
      }
      final rowsPerPage = [
        for (final p in table)
          [for (var n = 1; n <= 17; n++) n].where((n) => p.has('Rec$n')).length,
      ];
      expect(rowsPerPage.first, inInclusiveRange(5, 6));
      expect(rowsPerPage.fold(0, (a, b) => a + b), 17);
      expect(table.length, inInclusiveRange(3, 4));
    });

    test('the header row repeats on every table page', () async {
      final photo = writePng(dir, 'p', 400, 300);
      final pages = await _render(
        _model([
          for (var n = 1; n <= 12; n++) _finding(n, photos: [photo]),
        ]),
      );
      final table = pages.skip(1).toList();
      expect(table.length, greaterThan(1));
      for (final p in table) {
        expect(p.has('Recommendation'), isTrue);
        expect(p.has('Element'), isTrue);
      }
    });

    test('a long row that cannot fit moves whole to the next page; '
        'nothing is split or clipped', () async {
      final photo = writePng(dir, 'p', 400, 300);
      final longText = List.filled(40, 'replace').join(' ');
      final findings = [
        for (var n = 1; n <= 4; n++) _finding(n, photos: [photo]),
        _finding(5, photos: [photo], recommendation: 'LongRec $longText'),
        _finding(6, photos: [photo]),
      ];
      final pages = (await _render(_model(findings))).skip(1).toList();
      // The long row's 40-word text is whole on exactly one page.
      expect(pages.where((p) => p.has('LongRec')).length, 1);
      final withLong = pages.firstWhere((p) => p.has('LongRec'));
      expect(withLong.count('replace'), 40);
      for (final p in pages) {
        expect(p.tableBottomY, greaterThanOrEqualTo(_bodyFloorY));
      }
      expect(pages.any((p) => p.has('Rec6')), isTrue);
      expect(pages.length, 2, reason: 'the long row starts page 2');
      expect(pages.first.has('Rec5'), isFalse);
    });

    test('the final page does not reserve a large blank area: two rows '
        'share one page and end right after the last row', () async {
      final pages = await _render(_model([_finding(1), _finding(2)]));
      expect(pages.length, 2);
      // Header (~35) + two ~135pt rows: the table ends in the upper
      // half; nothing forces a third page.
      expect(pages[1].tableBottomY, greaterThan(841.89 / 2 - 60));
    });
  });

  test('preview and export are identical bytes: rendering is '
      'deterministic apart from the creation timestamp', () async {
    final model = _model([_finding(1), _finding(2)]);
    String stable(Uint8List b) => latin1
        .decode(b)
        .replaceAll(
          RegExp(r'/CreationDate\s*\(?[^)\n]*\)?|/ID\s*\[[^\]]*\]'),
          '',
        );
    final a = stable(await PdfReportRenderer(compress: false).render(model));
    final b = stable(await PdfReportRenderer(compress: false).render(model));
    expect(a, b);
  });

  test('writes the visual-QA sample when PRODEFACT_SAMPLE_REPORT_DIR is '
      'set', () async {
    final d = _sampleDir;
    if (d == null) return;
    String p(String n) => '$d/$n.jpg';
    final names = ['landscape', 'portrait', 'square', 'wide'];
    final recs = [
      'Re-lay.',
      'Hack out and re-lay the affected tiles with approved tile adhesive, '
          'grout evenly and allow to cure for 48 hours before use.',
      'Repaint.',
      'Rectify the crack by cutting a V-groove, applying a flexible '
          'sealant and repainting the whole wall plane to match.',
    ];
    final findings = [
      for (var n = 1; n <= 17; n++)
        _finding(
          n,
          photos: [p(names[n % 4])],
          recommendation: recs[n % 4],
          component: ['Floor Tile', 'Wall Plaster', 'Door Frame'][n % 3],
          notes: n % 3 == 0 ? 'Inspector note for finding $n.' : null,
        ),
    ];
    File('$d/sample.pdf').writeAsBytesSync(
      await PdfReportRenderer().render(
        _model(findings, coverPhoto: p('cover')),
      ),
    );
  });
}
