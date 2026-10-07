import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';

import '../support/png_fixture.dart';

/// The report rebuild (2026-10-07): a cover with the large photo at the
/// top and the details below it, then a No. | Area / Element | Finding |
/// Photo | Recommendation | Note table. The renderer draws whatever
/// catalogue entry it is given — no component whitelist.

String _pdf(Uint8List bytes) => latin1.decode(bytes);

ReportFinding _fromEntry(
  int n,
  String entryId, {
  String? note,
  List<String> photos = const [],
}) {
  final e = DefectCatalogue.instance.byId(entryId)!;
  return ReportFinding(
    number: n,
    elementName: e.mainElementName,
    componentName: e.componentName,
    defectType: e.defectDescription,
    recommendation: e.correctiveAction,
    notes: note,
    evidenceFilePaths: photos,
  );
}

ReportModel _model(List<ReportAreaSection> areas, {String? coverPhoto}) =>
    ReportModel(
      sessionId: 'session_table',
      propertyTypeLabel: 'High Rise',
      inspectionDate: DateTime(2026, 10, 1, 9),
      generatedAt: DateTime(2026, 10, 2),
      totalAreas: areas.length,
      completedAreas: areas.length,
      totalFindings: areas.fold(0, (s, a) => s + a.findings.length),
      totalEvidence: 0,
      areas: areas,
      propertyTitle: 'Residensi Test',
      propertyAddress: '1 Jalan Ujian, Kuala Lumpur',
      clientName: 'Siti Purchaser',
      inspectorName: 'Aman Inspector',
      contactNumber: '011-2233 4455',
      coverPhotoPath: coverPhoto,
    );

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prodefact_table'));
  tearDown(() {
    dir.deleteSync(recursive: true);
    DefectCatalogue.instance.replaceCustomEntries(const []);
  });

  test('cover: brand, then the large photo, then the title, then the '
      'dynamic details, then the summary — top to bottom', () async {
    final photo = writePng(dir, 'unit', 400, 300);
    final pdf = _pdf(
      await PdfReportRenderer(compress: false)
          .render(_model(const [], coverPhoto: photo)),
    );
    int at(String needle, [int from = 0]) => pdf.indexOf(needle, from);
    final brand = at('[(ProDefact)]TJ');
    final image = pdf.indexOf(RegExp(r'/I\d+ Do'));
    final title = at('[(BUILDING)]TJ');
    final purchaser = at('[(Purchaser)]TJ');
    final summary = at('[(Summary)]TJ');
    expect(brand, greaterThan(-1));
    expect(image, greaterThan(brand));
    expect(title, greaterThan(image), reason: 'photo is ABOVE the title');
    expect(purchaser, greaterThan(title));
    expect(summary, greaterThan(purchaser));
    for (final dynamicValue in [
      'Residensi',
      'Siti',
      'Aman',
      '011-2233',
      '2026-10-01',
    ]) {
      expect(pdf, contains(dynamicValue));
    }
  });

  test(
    'the table has its header, one row per finding, recommendations '
    'from the catalogue, and the header repeats on every defect page',
    () async {
      final ids = [
        'door.door_frame.07',
        'door.sliding_door_frame.04',
        'wall.wall_tile.04',
        'door.door_frame.01',
        'wall.wall_tile.01',
        'door.door_frame.02',
        'wall.wall_tile.02',
      ];
      final findings = [
        for (var i = 0; i < ids.length; i++) _fromEntry(i + 1, ids[i]),
      ];
      final bytes = await PdfReportRenderer(compress: false).render(
        _model([
          ReportAreaSection(
            name: 'Balcony',
            isPlumbing: false,
            findings: findings,
          ),
        ]),
      );
      final pdf = _pdf(bytes);
      // 7 findings at most 5 per page -> 2 defect pages, each with a header.
      expect('[(Recommendation)]TJ'.allMatches(pdf).length, 2);
      expect('[(Area)]TJ'.allMatches(pdf).length, greaterThanOrEqualTo(2));
      for (final id in ids) {
        final e = DefectCatalogue.instance.byId(id)!;
        expect(
          pdf,
          contains(e.correctiveAction!.split(' ').first),
          reason: 'recommendation of $id',
        );
      }
    },
  );

  test('every photo sits in the same fixed box with its aspect ratio '
      'preserved', () async {
    final wide = writePng(dir, 'wide', 200, 100);
    final tall = writePng(dir, 'tall', 100, 200);
    final bytes = await PdfReportRenderer(compress: false).render(
      _model([
        ReportAreaSection(
          name: 'Kitchen',
          isPlumbing: false,
          findings: [
            _fromEntry(1, 'door.door_frame.07', photos: [wide]),
            _fromEntry(2, 'wall.wall_tile.04', photos: [tall]),
          ],
        ),
      ]),
    );
    final pdf = _pdf(bytes);
    final placed =
        RegExp(
          r'([\d.]+) 0 0 ([\d.]+) [\d.\-]+ [\d.\-]+ cm\s*/I\d+ Do',
        ).allMatches(pdf).map((m) {
          return (w: double.parse(m.group(1)!), h: double.parse(m.group(2)!));
        }).toList();
    expect(placed, hasLength(greaterThanOrEqualTo(2)));
    for (final p in placed) {
      expect(p.w, lessThanOrEqualTo(104.01));
      expect(p.h, lessThanOrEqualTo(80.01));
    }
    final ratios = placed.map((p) => p.w / p.h).toList();
    expect(ratios.any((r) => (r - 2.0).abs() < 0.02), isTrue);
    expect(ratios.any((r) => (r - 0.5).abs() < 0.02), isTrue);
  });

  test('the renderer is component-agnostic: Door Frame, Sliding Door, '
      'Concrete Wall, Floor Tiles — and a custom Railing — all render with '
      'their own finding and recommendation', () async {
    DefectCatalogue.instance.replaceCustomEntries([
      CustomDefect(
        id: 'custom.railing.1',
        ownerUid: 'u',
        elementId: 'custom_element.balcony',
        elementName: 'Balcony',
        componentId: 'custom_component.balcony.railing',
        componentName: 'Railing',
        defectDescription: 'Poor paint finishing on the railing',
        correctiveAction: 'Sand, prime and repaint the railing evenly.',
        createdAt: DateTime(2026, 10, 7),
      ).toEntry(),
    ]);
    final floor = DefectCatalogue.instance.masterEntries.firstWhere(
      (e) => e.componentName == 'Floor Tiles',
    );
    final wall = DefectCatalogue.instance.masterEntries.firstWhere(
      (e) => e.componentName == 'Concrete Wall',
    );
    final entries = [
      'custom.railing.1',
      'door.door_frame.07',
      'door.sliding_door_frame.04',
      wall.id,
      floor.id,
    ];
    final pdf = _pdf(
      await PdfReportRenderer(compress: false).render(
        _model([
          ReportAreaSection(
            name: 'Balcony',
            isPlumbing: false,
            findings: [
              for (var i = 0; i < entries.length; i++)
                _fromEntry(i + 1, entries[i], note: 'note ${i + 1}'),
            ],
          ),
        ]),
      ),
    );
    expect(pdf, contains('[(Railing)]TJ'));
    expect(pdf, contains('railing'));
    expect(pdf, contains('[(Sand,)]TJ'));
    for (final name in ['Door', 'Sliding', 'Concrete', 'Floor']) {
      expect(pdf, contains(name));
    }
  });

  test('preview and export are the same bytes: rendering is deterministic '
      '(ignoring the creation timestamp)', () async {
    final model = _model([
      ReportAreaSection(
        name: 'Kitchen',
        isPlumbing: false,
        findings: [_fromEntry(1, 'door.door_frame.07')],
      ),
    ]);
    String stable(Uint8List b) => _pdf(
      b,
    ).replaceAll(RegExp(r'/CreationDate\s*\(?[^)\n]*\)?|/ID\s*\[[^\]]*\]'), '');
    final a = stable(await PdfReportRenderer(compress: false).render(model));
    final b = stable(await PdfReportRenderer(compress: false).render(model));
    expect(a, b);
  });
}
