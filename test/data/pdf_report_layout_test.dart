import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/core/inspection/report/report_page_plan.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';
import 'package:prodefact/data/report/pdf_safe_text.dart';

/// Report format pass (2026-10-01): page 1 is details + summary only,
/// defects from page 2 at most 5 per page, no numbering or symbols, a
/// two-line Element / Component heading, Finding and Recommendation,
/// then photos.
///
/// Set PRODEFACT_SAMPLE_REPORT_DIR to a folder holding landscape.jpg,
/// portrait.jpg, square.jpg and wide.jpg to also write sample.pdf there
/// for a visual check.

final _sampleDir = Platform.environment['PRODEFACT_SAMPLE_REPORT_DIR'];

String _photo(String name) =>
    _sampleDir == null ? '/missing/$name.jpg' : '$_sampleDir/$name.jpg';

ReportFinding _finding(
  int n,
  String element,
  String component,
  List<String> photos, {
  String? notes,
}) => ReportFinding(
  number: n,
  elementName: element,
  componentName: component,
  defectType: 'Defect description $n — hollow sound when tapped',
  recommendation: 'Recommendation $n: hack out and re-lay affected tiles',
  notes: notes,
  evidenceFilePaths: [for (final p in photos) _photo(p)],
);

ReportModel _sampleModel() {
  final areas = [
    ReportAreaSection(
      name: 'Living Room',
      isPlumbing: false,
      note: 'Inspected in daylight',
      findings: [
        _finding(1, 'Floor', 'Floor Tile', ['landscape']),
        _finding(2, 'Wall', 'Wall Plaster', ['portrait', 'landscape']),
        _finding(3, 'Ceiling', 'Ceiling Board', [
          'landscape',
          'portrait',
          'square',
        ]),
      ],
    ),
    const ReportAreaSection(name: 'Store', isPlumbing: false),
    ReportAreaSection(
      name: 'Master Bathroom',
      isPlumbing: true,
      findings: [
        _finding(4, 'Sanitary Fitting', 'Water Closet', [
          'wide',
        ], notes: 'Inspector’s note… “leaking” • see photo'),
        _finding(5, 'Door', 'Door Frame', ['square', 'wide']),
        _finding(6, 'Window', 'Window Glass', [
          'portrait',
          'square',
          'landscape',
        ]),
        _finding(7, 'Plumbing', 'Pipe', ['landscape']),
      ],
    ),
  ];
  return ReportModel(
    sessionId: 'session_sample',
    propertyTypeLabel: 'High Rise',
    inspectionDate: DateTime(2026, 10, 1, 10, 30),
    generatedAt: DateTime(2026, 10, 1, 15),
    totalAreas: 3,
    completedAreas: 3,
    totalFindings: 7,
    totalEvidence: 15,
    areas: areas,
    propertyTitle: 'Residensi Harmoni — Unit A-12-3',
    unitNumber: 'A-12-3',
    clientName: 'Nur Aisyah',
    inspectorName: 'Amir',
    contactNumber: '012-345 6789',
  );
}

/// Pulls the text out of each page of an uncompressed PDF, in order.
List<String> _pageTexts(Uint8List bytes) {
  final pdf = latin1.decode(bytes);
  final objects = <String, String>{
    for (final m in RegExp(
      r'(\d+) 0 obj(.*?)endobj',
      dotAll: true,
    ).allMatches(pdf))
      m.group(1)!: m.group(2)!,
  };
  final pages = objects.entries
      .where((e) => RegExp(r'/Type\s*/Page\b(?!s)').hasMatch(e.value))
      .toList();
  // Page tree order is the /Kids order of the root /Pages object.
  final kids = RegExp(r'/Kids\s*\[([^\]]*)\]')
      .firstMatch(
        objects.values.firstWhere((o) => RegExp(r'/Type\s*/Pages').hasMatch(o)),
      )!
      .group(1)!;
  final order = RegExp(r'(\d+) 0 R')
      .allMatches(kids)
      .map((m) => m.group(1)!)
      .toList();
  expect(order, hasLength(pages.length));
  return [
    for (final id in order)
      () {
        final contents = RegExp(r'/Contents\s*(\[[^\]]*\]|\d+ 0 R)')
            .firstMatch(objects[id]!)!
            .group(1)!;
        final buffer = StringBuffer();
        for (final ref in RegExp(r'(\d+) 0 R').allMatches(contents)) {
          final stream = objects[ref.group(1)!]!;
          for (final s in RegExp(r'\(((?:\\.|[^\\)])*)\)').allMatches(stream)) {
            buffer.write(
              s.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'),
            );
            buffer.write(' ');
          }
        }
        return buffer.toString();
      }(),
  ];
}

void main() {
  group('page plan', () {
    test('25. at most 5 findings per page, in report order', () {
      final pages = planDefectPages(_sampleModel());
      final counts = [
        for (final p in pages) p.where((e) => e.finding != null).length,
      ];
      expect(counts, [5, 2]);
      final order = [
        for (final p in pages)
          for (final e in p)
            if (e.finding != null) e.finding!.number,
      ];
      expect(order, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('an area continuing onto the next page repeats its heading; its '
        'note appears once; an empty area says "No defects recorded"', () {
      final pages = planDefectPages(_sampleModel());
      final first = pages[0];
      expect(first.first.showAreaHeading, isTrue);
      expect(first.first.areaNote, 'Inspected in daylight');
      expect(first[1].showAreaHeading, isFalse);
      final store = first.firstWhere((e) => e.areaName == 'Store');
      expect(store.finding, isNull);
      expect(store.showAreaHeading, isTrue);
      final second = pages[1];
      expect(second.first.areaName, 'Master Bathroom');
      expect(second.first.showAreaHeading, isTrue);
    });

    test('37 + 38. with a height budget, a page ends before it would '
        'overflow, and the next page repeats the area heading', () {
      final pages = planDefectPages(
        _sampleModel(),
        findingHeight: (f) => 100.0 * f.evidenceFilePaths.length,
        pageHeight: 350,
        areaHeadingHeight: 20,
      );
      for (final page in pages) {
        expect(page.first.showAreaHeading, isTrue);
        expect(
          page.where((e) => e.finding != null).length,
          lessThanOrEqualTo(kMaxFindingsPerReportPage),
        );
      }
      // Living Room's 1 + 2 photos fit together; its 3-photo finding
      // starts a new page.
      expect(pages[0].map((e) => e.finding?.number), [1, 2]);
      expect(pages[1].first.finding!.number, 3);
    });

    test('a model with no inspected areas has no defect pages', () {
      final model = _sampleModel();
      expect(
        planDefectPages(
          ReportModel(
            sessionId: model.sessionId,
            propertyTypeLabel: model.propertyTypeLabel,
            inspectionDate: model.inspectionDate,
            generatedAt: model.generatedAt,
            totalAreas: 0,
            completedAreas: 0,
            totalFindings: 0,
            totalEvidence: 0,
            areas: const [],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('pdfSafeText (root cause of the "▯" boxes)', () {
    test('29. typography outside Latin-1 maps to plain equivalents', () {
      expect(pdfSafeText('Floor — Tile'), 'Floor - Tile');
      expect(pdfSafeText('it’s “wet”…'), 'it\'s "wet"...');
      expect(pdfSafeText('• note'), '- note');
      expect(pdfSafeText('zero​width'), 'zerowidth');
    });

    test('Latin-1 text (incl. Malay and accents) is untouched; anything '
        'else becomes a visible "?"', () {
      const malay = 'Retak pada jubin lantai, café 25°C · ½';
      expect(pdfSafeText(malay), malay);
      expect(pdfSafeText('ok 👍'), 'ok ?');
      expect(pdfSafeText('a\u0007b'), 'a b');
    });
  });

  group('rendered PDF', () {
    late List<String> pages;

    setUpAll(() async {
      final bytes = await PdfReportRenderer(compress: false)
          .render(_sampleModel());
      pages = _pageTexts(bytes);
      if (_sampleDir != null) {
        // Visual-check copy, compressed like a real report.
        File('$_sampleDir/sample.pdf')
            .writeAsBytesSync(await PdfReportRenderer().render(_sampleModel()));
      }
    });

    test('23 + 24. page 1 is the cover (title, details, summary); the '
        'defect table starts on page 2', () {
      expect(pages.length, greaterThanOrEqualTo(3));
      expect(pages[0], contains('BUILDING DEFECT INSPECTION REPORT'));
      expect(pages[0], contains('Inspection Summary'));
      expect(pages[0], contains('Purchaser / Owner'));
      expect(pages[0], contains('Nur Aisyah'));
      expect(pages[0], contains('Prepared by'));
      expect(pages[0], isNot(contains('Recommendation')));
      expect(pages[0], isNot(contains('Living Room')));
      expect(pages[1], contains('Living Room'));
      expect(pages[1], contains('Recommendation'));
    });

    test('25 + 26. no page has more than 5 findings', () {
      for (final page in pages.skip(1)) {
        expect(
          'Defect description'.allMatches(page).length,
          lessThanOrEqualTo(5),
        );
      }
      expect(pages.join().split('Defect description').length - 1, 7);
    });

    test('27 + 28. no numbering, bullets or icons', () {
      final all = pages.join();
      expect(all, isNot(contains('#1')));
      expect(RegExp(r'#\d').hasMatch(all), isFalse);
      expect(all, isNot(contains('•')));
    });

    test('29 + 30. every drawn character is printable (no "▯"): only '
        'Latin-1 reaches the PDF', () {
      final all = pages.join();
      expect(all.runes.every((r) => r <= 0xFF), isTrue);
      expect(all, contains('Residensi Harmoni - Unit A-12-3'));
      expect(all, contains('Inspector\'s note... "leaking" - see photo'));
    });

    test(
      '31 + 32. the table has the columns No. | Area / Element | Finding '
      '| Photo | Recommendation | Note, in that order, and each row '
      'carries its area, element - component, finding and recommendation',
      () {
        final page = pages[1];
        var at = -1;
        for (final column in [
          'No.',
          'Area / Element',
          'Finding',
          'Photo',
          'Recommendation',
          'Note',
        ]) {
          final next = page.indexOf(column, at + 1);
          expect(next, greaterThan(at), reason: 'column $column out of order');
          at = next;
        }
        expect(page, contains('Floor - Floor Tile'));
        expect(page, contains('Defect description 1'));
        expect(page, contains('Recommendation 1: hack out'));
      },
    );

    test('35 + 36. compact header from page 2 and a footer with Page X of Y '
        'on every page', () {
      expect(pages[0], isNot(contains('Home Inspection Report |')));
      for (var i = 0; i < pages.length; i++) {
        expect(pages[i], contains('Generated by ProDefact'));
        expect(
          pages[i],
          contains('Advisory report for informational purposes only.'),
        );
        expect(pages[i], contains('Page ${i + 1} of ${pages.length}'));
        if (i > 0) {
          expect(pages[i], contains('Home Inspection Report |'));
        }
      }
    });

    test('33 + 34. findings with 1, 2 and 3 photos (and missing files) '
        'render without failing', () {
      // Rendering above already succeeded; every finding is present.
      for (var n = 1; n <= 7; n++) {
        expect(pages.join(), contains('Defect description $n '));
      }
    });
  });
}
