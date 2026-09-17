import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/inspection/report/report_model.dart';
import '../../core/inspection/report/report_renderer.dart';

/// Renders a [ReportModel] to a professional Home Inspection PDF using
/// `package:pdf`. This is the only file in the app that imports it —
/// everything else depends on the [ReportRenderer] abstraction.
///
/// A missing/unreadable evidence file is skipped (with a small "photo
/// unavailable" note in its place) rather than failing the whole
/// render — see `docs/report.md`.
class PdfReportRenderer implements ReportRenderer {
  static final _accentColor = PdfColor.fromHex('#1E3A5F');
  static final _mutedColor = PdfColor.fromHex('#6B7280');
  static final _dividerColor = PdfColor.fromHex('#D1D5DB');

  @override
  Future<Uint8List> render(ReportModel model) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _buildRunningHeader(model),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildCover(model),
          pw.SizedBox(height: 24),
          _buildSummary(model),
          pw.SizedBox(height: 16),
          for (final area in model.areas) _buildArea(area),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildCover(ReportModel model) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ProDefact',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: _accentColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Home Inspection Report',
          style: pw.TextStyle(fontSize: 16, color: _mutedColor),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: _dividerColor),
        pw.SizedBox(height: 12),
        _buildCoverRow(
          'Property',
          model.propertyTitle ?? model.propertyTypeLabel,
        ),
        if (model.projectName != null)
          _buildCoverRow('Project / Development', model.projectName!),
        if (model.blockTower != null || model.unitNumber != null)
          _buildCoverRow(
            'Block / Unit',
            [
              model.blockTower,
              model.unitNumber,
            ].whereType<String>().join(' / '),
          ),
        if (model.propertyAddress != null)
          _buildCoverRow('Address', model.propertyAddress!),
        _buildCoverRow('Property type', model.propertyTypeLabel),
        if (model.clientName != null)
          _buildCoverRow('Client', model.clientName!),
        if (model.inspectorName != null)
          _buildCoverRow('Inspector', model.inspectorName!),
        _buildCoverRow('Inspection ID', model.sessionId),
        _buildCoverRow('Inspection date', _formatDate(model.inspectionDate)),
        _buildCoverRow(
          'Report date',
          _formatDate(model.reportDate ?? model.generatedAt),
        ),
        _buildCoverRow('Report generated', _formatDate(model.generatedAt)),
        _buildCoverRow('Report version', 'v${model.version}'),
      ],
    );
  }

  pw.Widget _buildCoverRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: _mutedColor, fontSize: 11),
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(ReportModel model) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _dividerColor),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Inspection Summary',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              _summaryStat('Applicable areas', '${model.totalAreas}'),
              _summaryStat('Completed areas', '${model.completedAreas}'),
              _summaryStat('Findings recorded', '${model.totalFindings}'),
              _summaryStat('Photos attached', '${model.totalEvidence}'),
              _summaryStat(
                'Completion',
                model.completedAreas >= model.totalAreas && model.totalAreas > 0
                    ? 'All areas completed'
                    : '${model.completedAreas} of ${model.totalAreas} areas',
              ),
            ],
          ),
          if (model.inspectionNote != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Inspection note: ${model.inspectionNote}',
              style: pw.TextStyle(fontSize: 10, color: _mutedColor),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _summaryStat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _mutedColor)),
      ],
    );
  }

  pw.Widget _buildArea(ReportAreaSection area) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text(
          area.name,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _accentColor,
          ),
        ),
        pw.Divider(color: _dividerColor, height: 8),
        if (area.note != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              'Note: ${area.note}',
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: _mutedColor,
              ),
            ),
          ),
        if (area.findings.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Text(
              'No defects recorded.',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: _mutedColor,
              ),
            ),
          )
        else
          for (final finding in area.findings) _buildFinding(finding),
      ],
    );
  }

  pw.Widget _buildFinding(ReportFinding finding) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F9FAFB'),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            [
              '#${finding.number}',
              finding.elementName,
              if (finding.componentName != null) finding.componentName!,
            ].join(' — '),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Finding: ${finding.defectType ?? 'Not specified'}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (finding.recommendation != null)
            pw.Text(
              'Recommendation: ${finding.recommendation}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (finding.notes != null)
            pw.Text(
              'Notes: ${finding.notes}',
              style: pw.TextStyle(fontSize: 9, color: _mutedColor),
            ),
          if (finding.evidenceFilePaths.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: finding.evidenceFilePaths
                  .map(_buildEvidenceThumbnail)
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildEvidenceThumbnail(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return _missingPhotoBox();
      }
      final bytes = file.readAsBytesSync();
      final image = pw.MemoryImage(bytes);
      return pw.Container(
        width: 90,
        height: 90,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _dividerColor),
        ),
        child: pw.Image(image, fit: pw.BoxFit.cover),
      );
    } catch (_) {
      // A missing/corrupt/unreadable image must never fail the whole
      // report — skip it and show a placeholder instead.
      return _missingPhotoBox();
    }
  }

  pw.Widget _missingPhotoBox() {
    return pw.Container(
      width: 90,
      height: 90,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _dividerColor),
        color: PdfColor.fromHex('#F3F4F6'),
      ),
      child: pw.Text(
        'Photo\nunavailable',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, color: _mutedColor),
      ),
    );
  }

  pw.Widget _buildRunningHeader(ReportModel model) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        'ProDefact Home Inspection Report — ${model.sessionId}',
        style: pw.TextStyle(fontSize: 9, color: _mutedColor),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _dividerColor),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by ProDefact. Advisory report for informational '
              'purposes only.',
              style: pw.TextStyle(fontSize: 7, color: _mutedColor),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _mutedColor),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }
}
