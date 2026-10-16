import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';

/// Area boundaries: a new area always starts on a fresh page; one area
/// may still flow across several pages.

int _n = 0;

ReportFinding _finding(int n) => ReportFinding(
  number: n,
  elementName: 'Floor',
  componentName: 'Floor Tile',
  defectType: 'Hollow sound when tapped',
  recommendation: 'Re-lay affected tiles',
  evidenceFilePaths: const [],
);

/// [counts] = findings per area; numbering runs on across areas.
ReportModel _model(Map<String, int> counts) {
  _n = 0;
  return ReportModel(
    sessionId: 'session_pagination',
    propertyTypeLabel: 'High Rise',
    inspectionDate: DateTime(2026, 10, 1, 9),
    generatedAt: DateTime(2026, 10, 2),
    totalAreas: counts.length,
    completedAreas: counts.length,
    totalFindings: counts.values.fold(0, (a, b) => a + b),
    totalEvidence: 0,
    areas: [
      for (final e in counts.entries)
        ReportAreaSection(
          name: e.key,
          isPlumbing: false,
          findings: [for (var i = 0; i < e.value; i++) _finding(++_n)],
        ),
    ],
  );
}

/// The decoded text of each page's content stream (uncompressed PDF).
Future<List<String>> _pages(ReportModel model) async {
  final pdf = latin1.decode(
    await PdfReportRenderer(compress: false).render(model),
  );
  final objects = {
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
      [
        for (final ref in RegExp(r'(\d+) 0 R').allMatches(
          RegExp(r'/Contents\s*(\[[^\]]*\]|\d+ 0 R)')
              .firstMatch(objects[id]!)!
              .group(1)!,
        ))
          objects[ref.group(1)!]!,
      ].join('\n'),
  ];
}

bool _has(String page, String word) => page.contains('[($word)]TJ');

/// Body pages only (page 0 is the cover).
Iterable<String> _body(List<String> pages) => pages.skip(1);

void main() {
  test('two small areas: area B starts on a new page', () async {
    final pages = await _pages(_model({'Bathroom': 2, 'Foyer': 2}));
    expect(pages, hasLength(3));
    expect(_has(pages[1], 'Bathroom'), isTrue);
    expect(_has(pages[1], 'Foyer'), isFalse);
    expect(_has(pages[2], 'Foyer'), isTrue);
    expect(_has(pages[2], 'Bathroom'), isFalse);
  });

  test('one large area may span several pages', () async {
    final pages = await _pages(_model({'Bathroom': 14}));
    expect(pages.length, greaterThan(2));
    for (final p in _body(pages)) {
      expect(_has(p, 'Bathroom'), isTrue);
    }
  });

  test(
    'large area A then small area B: B starts the page after A ends',
    () async {
      final pages = await _pages(_model({'Bathroom': 14, 'Foyer': 2}));
      final body = _body(pages).toList();
      final firstFoyer = body.indexWhere((p) => _has(p, 'Foyer'));
      expect(firstFoyer, body.length - 1, reason: 'Foyer only on last page');
      expect(firstFoyer, greaterThan(1));
      expect(_has(body[firstFoyer], 'Bathroom'), isFalse);
      expect(_has(body[firstFoyer - 1], 'Bathroom'), isTrue);
    },
  );

  test('three areas each start on a fresh page', () async {
    final pages = await _pages(
      _model({'Bathroom': 1, 'Foyer': 1, 'Kitchen': 1}),
    );
    expect(pages, hasLength(4));
    for (final (i, name) in ['Bathroom', 'Foyer', 'Kitchen'].indexed) {
      for (final other in ['Bathroom', 'Foyer', 'Kitchen']) {
        expect(_has(pages[i + 1], other), other == name);
      }
    }
  });

  test(
    'table header repeats on every body page, same-area or new-area',
    () async {
      final pages = await _pages(_model({'Bathroom': 14, 'Foyer': 2}));
      for (final p in _body(pages)) {
        expect(_has(p, 'Recommendation'), isTrue);
        expect(_has(p, 'Area'), isTrue);
      }
    },
  );

  test('row numbering stays continuous across area pages', () async {
    final pages = await _pages(
      _model({'Bathroom': 7, 'Foyer': 2, 'Kitchen': 3}),
    );
    final seen = <int>[
      for (final p in _body(pages))
        for (final m in RegExp(r'\[\((\d+)\)\]TJ').allMatches(p))
          int.parse(m.group(1)!),
    ];
    // The footer also prints digits, so check 1..12 appear in order.
    var next = 1;
    for (final n in seen) {
      if (n == next && next <= 12) next++;
    }
    expect(next, 13);
    // And no finding number is printed twice in a row-number position:
    // each of 1..12 is present.
    expect(seen.toSet().containsAll([for (var i = 1; i <= 12; i++) i]), isTrue);
  });
}
