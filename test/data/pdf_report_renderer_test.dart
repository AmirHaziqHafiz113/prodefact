import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';

void main() {
  test('rendering succeeds and produces non-empty PDF bytes even when an '
      'evidence file is missing/deleted — a bad photo must never fail '
      'the whole report', () async {
    final model = ReportModel(
      sessionId: 'session_missing_photo',
      propertyTypeLabel: 'High Rise',
      inspectionDate: DateTime(2026, 1, 1),
      generatedAt: DateTime(2026, 1, 2),
      totalAreas: 1,
      completedAreas: 1,
      totalFindings: 1,
      totalEvidence: 1,
      areas: [
        ReportAreaSection(
          name: 'Master Bathroom',
          isPlumbing: true,
          findings: [
            ReportFinding(
              number: 1,
              elementName: 'Floor',
              componentName: 'Floor tile',
              defectType: 'Cracked tile',
              recommendation: 'Replace tile',
              notes: null,
              evidenceFilePaths: ['/this/path/does/not/exist/missing.jpg'],
            ),
          ],
        ),
      ],
    );

    final renderer = PdfReportRenderer();
    final bytes = await renderer.render(model);

    expect(bytes, isNotEmpty);
    // A real PDF file starts with the "%PDF-" magic header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('rendering a report with a zero-finding area produces non-empty '
      'bytes ("No defects recorded" case)', () async {
    final model = ReportModel(
      sessionId: 'session_empty_area',
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
    );

    final bytes = await PdfReportRenderer().render(model);

    expect(bytes, isNotEmpty);
  });
}
