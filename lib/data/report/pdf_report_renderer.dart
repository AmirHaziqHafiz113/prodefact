import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/inspection/report/report_model.dart';
import '../../core/inspection/report/report_page_plan.dart';
import '../../core/inspection/report/report_renderer.dart';
import 'pdf_safe_text.dart';

/// Renders a [ReportModel] to a professional Home Inspection PDF using
/// `package:pdf`. This is the only file in the app that imports it —
/// everything else depends on the [ReportRenderer] abstraction.
///
/// A missing/unreadable evidence file is skipped (with a small "photo
/// unavailable" note in its place) rather than failing the whole
/// render — see `docs/report.md`.
class PdfReportRenderer implements ReportRenderer {
  /// [compress] is on for real reports; tests turn it off so the page
  /// content streams can be inspected.
  PdfReportRenderer({this.compress = true});

  final bool compress;

  static final _accentColor = PdfColor.fromHex('#1E3A5F');
  static final _mutedColor = PdfColor.fromHex('#6B7280');
  static final _textColor = PdfColor.fromHex('#111827');
  static final _dividerColor = PdfColor.fromHex('#D1D5DB');
  static final _findingBackground = PdfColor.fromHex('#F9FAFB');

  static const _pageMargin = pw.EdgeInsets.fromLTRB(36, 32, 36, 28);

  @override
  Future<Uint8List> render(ReportModel model) async {
    final doc = pw.Document(compress: compress);

    // Page 1: branding, title, report details and the Inspection
    // Summary only. Defects always start on page 2.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        footer: _buildFooter,
        build: (context) => [
          _buildCover(model),
          pw.SizedBox(height: 16),
          ..._buildResidencePhoto(model),
          _buildSummary(model),
        ],
      ),
    );

    // One MultiPage per planned page of at most 5 findings: each starts
    // on a fresh page, and if its photos are too tall for one page it
    // continues onto the next without ever splitting a finding.
    final pages = planDefectPages(
      model,
      findingHeight: _estimatedFindingHeight,
      // A4 body below the compact header and above the footer, with a
      // little slack so an estimate that runs short still fits.
      pageHeight: PdfPageFormat.a4.height - _pageMargin.vertical - 90,
      areaHeadingHeight: 44,
      noDefectsHeight: 26,
    );
    for (final page in pages) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: _pageMargin,
          header: (context) => _buildRunningHeader(model),
          footer: _buildFooter,
          build: (context) => [for (final entry in page) ..._buildEntry(entry)],
        ),
      );
    }

    return doc.save();
  }

  /// Every string drawn in the report passes through here — see
  /// [pdfSafeText] for why.
  pw.Text _text(String value, {pw.TextStyle? style, pw.TextAlign? align}) =>
      pw.Text(pdfSafeText(value), style: style, textAlign: align);

  pw.Widget _buildCover(ReportModel model) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          'ProDefact',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: _accentColor,
          ),
        ),
        pw.SizedBox(height: 4),
        _text(
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
        if (model.projectDeveloperName != null)
          _buildCoverRow('Project / Developer', model.projectDeveloperName!),
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
        if (model.contactNumber != null)
          _buildCoverRow('Client / Agent Contact', model.contactNumber!),
        if (model.inspectorName != null)
          _buildCoverRow('Inspector', model.inspectorName!),
        _buildCoverRow('Inspection ID', model.sessionId),
        _buildCoverRow(
          'Inspection date & time',
          _formatDateTime(model.inspectionDate),
        ),
        _buildCoverRow(
          'Report date',
          _formatDate(model.reportDate ?? model.generatedAt),
        ),
        _buildCoverRow('Report generated', _formatDate(model.generatedAt)),
        _buildCoverRow('Report version', 'v${model.version}'),
      ],
    );
  }

  /// The optional Residence / Unit Photo: a fixed, full-width box in the
  /// middle of page 1 with the photo fitted inside it (aspect ratio
  /// preserved, never stretched). Nothing is drawn — and no blank box is
  /// left behind — when there is no photo or it can't be read.
  List<pw.Widget> _buildResidencePhoto(ReportModel model) {
    final path = model.coverPhotoPath;
    if (path == null || path.isEmpty) return const [];
    final pw.MemoryImage image;
    try {
      final file = File(path);
      if (!file.existsSync()) return const [];
      image = pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return const [];
    }
    return [
      pw.Container(
        width: double.infinity,
        height: _residencePhotoHeight,
        decoration: pw.BoxDecoration(
          color: _findingBackground,
          border: pw.Border.all(color: _dividerColor),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  /// Height of the Residence / Unit Photo box on page 1, in points.
  static const double _residencePhotoHeight = 220;

  pw.Widget _buildCoverRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: _text(
              label,
              style: pw.TextStyle(color: _mutedColor, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: _text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
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
          _text(
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
            _text(
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
        _text(
          value,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        _text(label, style: pw.TextStyle(fontSize: 9, color: _mutedColor)),
      ],
    );
  }

  /// One planned entry: the area heading (when this is the area's first
  /// entry on the page), then the finding as one unbreakable block.
  List<pw.Widget> _buildEntry(ReportPageEntry entry) {
    final finding = entry.finding;
    final photoRows = finding == null
        ? const <List<String>>[]
        : _photoRows(finding.evidenceFilePaths);
    return [
      if (entry.showAreaHeading && finding == null)
        pw.Inseparable(child: _buildAreaHeading(entry)),
      if (finding == null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: _text(
            'No defects recorded.',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: _mutedColor,
            ),
          ),
        )
      else ...[
        // Column/Container would otherwise span pages and print a
        // finding's text on one page and its photos on the next.
        // Inseparable, with the area heading when there is one, so a
        // heading is never stranded at the foot of a page.
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (entry.showAreaHeading) _buildAreaHeading(entry),
              _buildFinding(
                finding,
                photoRows.isEmpty ? null : photoRows.first,
              ),
            ],
          ),
        ),
        // New findings have exactly one photo (one photo = one finding).
        // A historical multi-photo finding with more than 3 continues in
        // further rows; they follow it and never split a photo.
        for (final row in photoRows.skip(1))
          pw.Inseparable(
            child: pw.Container(
              color: _findingBackground,
              padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _buildPhotoRow(row),
            ),
          ),
        pw.SizedBox(height: 10),
      ],
    ];
  }

  pw.Widget _buildAreaHeading(ReportPageEntry entry) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        _text(
          entry.areaName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _accentColor,
          ),
        ),
        pw.Divider(color: _dividerColor, height: 8),
        if (entry.areaNote != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: _text(
              'Note: ${entry.areaNote}',
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: _mutedColor,
              ),
            ),
          ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  /// Two-line heading — element, then component — followed by the
  /// finding and recommendation, then the photos. No numbering, bullets
  /// or icons.
  pw.Widget _buildFinding(ReportFinding finding, List<String>? firstPhotos) {
    final labelStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: _textColor,
    );
    const bodyStyle = pw.TextStyle(fontSize: 10);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      color: _findingBackground,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            finding.elementName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _textColor,
            ),
          ),
          if (finding.componentName != null)
            _text(
              finding.componentName!,
              style: pw.TextStyle(fontSize: 11, color: _textColor),
            ),
          pw.SizedBox(height: 6),
          _labelled(
            'Finding: ',
            finding.defectType ?? 'Not specified',
            labelStyle,
            bodyStyle,
          ),
          if (finding.recommendation != null) ...[
            pw.SizedBox(height: 3),
            _labelled(
              'Recommendation: ',
              finding.recommendation!,
              labelStyle,
              bodyStyle,
            ),
          ],
          if (finding.notes != null) ...[
            pw.SizedBox(height: 3),
            _text(
              'Inspector note: ${finding.notes}',
              style: pw.TextStyle(fontSize: 9, color: _mutedColor),
            ),
          ],
          if (firstPhotos != null) ...[
            pw.SizedBox(height: 8),
            _buildPhotoRow(firstPhotos),
          ],
        ],
      ),
    );
  }

  pw.Widget _labelled(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle bodyStyle,
  ) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: pdfSafeText(label), style: labelStyle),
          pw.TextSpan(text: pdfSafeText(value), style: bodyStyle),
        ],
      ),
    );
  }

  /// A generous estimate of one printed finding: heading, text lines
  /// and photo rows (see [_buildPhotoRow] for the row heights).
  static double _estimatedFindingHeight(ReportFinding finding) {
    double lines(String? text) =>
        text == null ? 0 : 14.0 * (1 + text.length ~/ 90);
    final rows = _photoRows(finding.evidenceFilePaths);
    final photos = rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          10 +
          switch (row.length) {
            1 => 170,
            2 => 150,
            _ => 115,
          },
    );
    return 20 + // padding
        30 + // element + component
        6 +
        lines(finding.defectType) +
        lines(finding.recommendation) +
        lines(finding.notes) +
        photos +
        10; // gap after the block
  }

  static List<List<String>> _photoRows(List<String> paths) => [
    for (var i = 0; i < paths.length; i += 3)
      paths.sublist(i, i + 3 > paths.length ? paths.length : i + 3),
  ];

  /// 1 photo: one large image. 2: side by side. 3: a row of three.
  /// Every photo keeps its own aspect ratio (fitted, never cropped or
  /// stretched).
  pw.Widget _buildPhotoRow(List<String> paths) {
    if (paths.length == 1) {
      return _buildPhoto(
        paths.single,
        pw.Alignment.topLeft,
        maxWidth: 260,
        maxHeight: 170,
      );
    }
    final height = paths.length == 2 ? 150.0 : 115.0;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3 && i < paths.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.SizedBox(
              height: height,
              child: _buildPhoto(paths[i], pw.Alignment.center),
            ),
          ),
        ],
      ],
    );
  }

  /// With [maxWidth]/[maxHeight], the photo is sized to its own aspect
  /// ratio inside that box (no empty bands around a wide or tall photo).
  pw.Widget _buildPhoto(
    String filePath,
    pw.Alignment alignment, {
    double? maxWidth,
    double? maxHeight,
  }) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return _missingPhotoBox();
      final image = pw.MemoryImage(file.readAsBytesSync());
      final widget = pw.Image(
        image,
        fit: pw.BoxFit.contain,
        alignment: alignment,
      );
      final w = image.width, h = image.height;
      if (maxWidth == null || maxHeight == null || w == null || h == null) {
        return widget;
      }
      final scale = [
        maxWidth / w,
        maxHeight / h,
      ].reduce((a, b) => a < b ? a : b);
      return pw.SizedBox(width: w * scale, height: h * scale, child: widget);
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
      child: _text(
        'Photo\nunavailable',
        align: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, color: _mutedColor),
      ),
    );
  }

  /// Compact header from page 2 onward.
  pw.Widget _buildRunningHeader(ReportModel model) {
    final title = model.propertyTitle ?? model.propertyTypeLabel;
    final unit = model.unitNumber;
    final property = unit == null || title.contains(unit)
        ? title
        : '$title, $unit';
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _dividerColor)),
      ),
      child: pw.Row(
        children: [
          _text(
            'ProDefact',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _text(
              'Home Inspection Report  |  $property',
              style: pw.TextStyle(fontSize: 9, color: _mutedColor),
            ),
          ),
          _text(
            _formatDate(model.reportDate ?? model.generatedAt),
            style: pw.TextStyle(fontSize: 9, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  /// MultiPage reserves the footer's own space on every page, so body
  /// content can never run underneath it.
  pw.Widget _buildFooter(pw.Context context) {
    final style = pw.TextStyle(fontSize: 7, color: _mutedColor);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _dividerColor)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text('Generated by ProDefact', style: style),
                _text(
                  'Advisory report for informational purposes only.',
                  style: style,
                ),
              ],
            ),
          ),
          _text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: style,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }

  /// Date and time together, for the one place this report renders an
  /// actual moment in time rather than a calendar date — see QA/QC
  /// simplification pass ("Inspection Date & Time"). A pre-upgrade
  /// inspection that only ever captured a date still renders cleanly
  /// here (its stored time defaults to midnight).
  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${_formatDate(dateTime)} ${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}
