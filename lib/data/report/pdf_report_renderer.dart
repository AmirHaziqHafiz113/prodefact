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

    // Page 1 (cover): brand header, the large Residence / Unit Photo,
    // the report title, then the property and inspector details and the
    // Inspection Summary. Defects always start on page 2.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin,
        footer: _buildFooter,
        build: (context) => [
          _buildBrandHeader(model),
          pw.SizedBox(height: 14),
          ..._buildResidencePhoto(model),
          _buildCoverTitleAndDetails(model),
          pw.SizedBox(height: 14),
          _buildSummary(model),
        ],
      ),
    );

    // One MultiPage per planned page of at most 5 findings, each a table
    // (No. | Area / Element | Finding | Photo | Recommendation | Note).
    // A table that outgrows its page continues on the next one with the
    // header row repeated; a row is never split.
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
          build: (context) => [_buildDefectTable(page)],
        ),
      );
    }

    return doc.save();
  }

  /// Every string drawn in the report passes through here — see
  /// [pdfSafeText] for why.
  pw.Text _text(String value, {pw.TextStyle? style, pw.TextAlign? align}) =>
      pw.Text(pdfSafeText(value), style: style, textAlign: align);

  /// Top band of the cover: brand on the left, document kind on the
  /// right, over a rule.
  pw.Widget _buildBrandHeader(ReportModel model) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _text(
              'ProDefact',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _accentColor,
              ),
            ),
            pw.Spacer(),
            _text(
              'Home Inspection',
              style: pw.TextStyle(fontSize: 10, color: _mutedColor),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 2, color: _accentColor),
      ],
    );
  }

  /// The title and the dynamic property/inspector details, below the
  /// photo.
  pw.Widget _buildCoverTitleAndDetails(ReportModel model) {
    final title = model.propertyTitle ?? model.propertyTypeLabel;
    final property = [
      title,
      if (model.blockTower != null && !title.contains(model.blockTower!))
        model.blockTower!,
      if (model.unitNumber != null && !title.contains(model.unitNumber!))
        model.unitNumber!,
    ].join(', ');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: _text(
            'BUILDING DEFECT INSPECTION REPORT',
            align: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: _text(
            property,
            align: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, color: _textColor),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _dividerColor, height: 1),
        pw.SizedBox(height: 8),
        if (model.propertyAddress != null)
          _buildCoverRow('Address', model.propertyAddress!),
        if (model.clientName != null)
          _buildCoverRow('Purchaser / Owner', model.clientName!),
        _buildCoverRow('Property type', model.propertyTypeLabel),
        if (model.projectDeveloperName != null)
          _buildCoverRow('Project / Developer', model.projectDeveloperName!),
        _buildCoverRow(
          'Inspection date',
          _formatDateTime(model.inspectionDate),
        ),
        if (model.inspectorName != null)
          _buildCoverRow('Prepared by', model.inspectorName!),
        if (model.contactNumber != null)
          _buildCoverRow('Contact', model.contactNumber!),
        pw.SizedBox(height: 4),
        _text(
          'Report v${model.version} - ${_formatDate(model.reportDate ?? model.generatedAt)} '
          '- ID ${model.sessionId}',
          style: pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ],
    );
  }

  /// The large Residence / Unit Photo at the top of the cover: a fixed,
  /// full-width box with the photo fitted inside it (aspect ratio
  /// preserved, never stretched). Nothing is drawn — and no blank box is
  /// left behind — when there is no photo or it can't be read.
  List<pw.Widget> _buildResidencePhoto(ReportModel model) {
    final path = model.coverPhotoPath;
    if (path == null || path.isEmpty) return [pw.SizedBox(height: 24)];
    final pw.MemoryImage image;
    try {
      final file = File(path);
      if (!file.existsSync()) return [pw.SizedBox(height: 24)];
      image = pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return [pw.SizedBox(height: 24)];
    }
    return [
      pw.Container(
        width: double.infinity,
        height: _residencePhotoHeight,
        decoration: pw.BoxDecoration(
          color: _findingBackground,
          border: pw.Border.all(color: _dividerColor),
        ),
        padding: const pw.EdgeInsets.all(3),
        child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  /// Height of the Residence / Unit Photo box on the cover, in points.
  static const double _residencePhotoHeight = 290;

  pw.Widget _buildCoverRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: _text(
              label,
              style: pw.TextStyle(color: _mutedColor, fontSize: 10.5),
            ),
          ),
          pw.Expanded(
            child: _text(
              value,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
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

  // ---- defect table -------------------------------------------------
  //
  // Page content width is 523.3pt (A4 less 36pt margins). Columns, in
  // points: No. 26 | Area / Element 88 | Finding 110 | Photo 116 |
  // Recommendation 112 | Note 71. Estimated from the brief (no measured
  // reference was available): see docs/report.md.
  static const _colNo = 26.0;
  static const _colArea = 88.0;
  static const _colFinding = 110.0;
  static const _colPhoto = 116.0;
  static const _colRecommendation = 112.0;
  static const _colNote = 71.0;

  /// Every photo sits in the same box, fitted (never stretched).
  static const _photoBoxWidth = 104.0;
  static const _photoBoxHeight = 80.0;

  pw.Widget _buildDefectTable(List<ReportPageEntry> page) {
    return pw.Table(
      border: pw.TableBorder.all(color: _dividerColor, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(_colNo),
        1: pw.FixedColumnWidth(_colArea),
        2: pw.FixedColumnWidth(_colFinding),
        3: pw.FixedColumnWidth(_colPhoto),
        4: pw.FixedColumnWidth(_colRecommendation),
        5: pw.FixedColumnWidth(_colNote),
      },
      children: [
        _buildTableHeader(),
        for (final entry in page) _buildTableRow(entry),
      ],
    );
  }

  pw.TableRow _buildTableHeader() {
    pw.Widget cell(String label) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: _text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
    return pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(color: _accentColor),
      children: [
        cell('No.'),
        cell('Area / Element'),
        cell('Finding'),
        cell('Photo'),
        cell('Recommendation'),
        cell('Note'),
      ],
    );
  }

  pw.Widget _cell(pw.Widget child) =>
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: child);

  pw.Widget _cellText(String? value, {pw.TextStyle? style}) => _cell(
    _text(value ?? '', style: style ?? const pw.TextStyle(fontSize: 8.5)),
  );

  pw.TableRow _buildTableRow(ReportPageEntry entry) {
    final finding = entry.finding;
    if (finding == null) {
      return pw.TableRow(
        children: [
          _cellText(''),
          _cellText(
            entry.areaName,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          _cellText(
            'No defects recorded.',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontStyle: pw.FontStyle.italic,
              color: _mutedColor,
            ),
          ),
          _cellText(''),
          _cellText(''),
          _cellText(entry.areaNote),
        ],
      );
    }
    final element = [
      finding.elementName,
      if (finding.componentName != null) finding.componentName!,
    ].join(' - ');
    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.top,
      children: [
        _cellText('${finding.number}'),
        _cell(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(
                entry.areaName,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              _text(element, style: const pw.TextStyle(fontSize: 8.5)),
              if (entry.areaNote != null) ...[
                pw.SizedBox(height: 2),
                _text(
                  'Area note: ${entry.areaNote}',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontStyle: pw.FontStyle.italic,
                    color: _mutedColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        _cellText(finding.defectType ?? 'Not specified'),
        _cell(_buildPhotoCell(finding.evidenceFilePaths)),
        _cellText(finding.recommendation),
        _cellText(finding.notes),
      ],
    );
  }

  /// The Photo cell: one fixed box per photo. A new finding has exactly
  /// one photo; a historical multi-photo finding stacks its photos, each
  /// in the same box.
  pw.Widget _buildPhotoCell(List<String> paths) {
    if (paths.isEmpty) return pw.SizedBox(height: _photoBoxHeight);
    return pw.Column(
      children: [
        for (var i = 0; i < paths.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 4),
          pw.Container(
            width: _photoBoxWidth,
            height: _photoBoxHeight,
            alignment: pw.Alignment.center,
            color: PdfColor.fromHex('#F3F4F6'),
            child: _buildPhoto(
              paths[i],
              pw.Alignment.center,
              maxWidth: _photoBoxWidth,
              maxHeight: _photoBoxHeight,
            ),
          ),
        ],
      ],
    );
  }

  /// A generous estimate of one printed table row: the photo box(es) or
  /// the tallest text column, whichever is taller, plus padding.
  static double _estimatedFindingHeight(ReportFinding finding) {
    double textLines(String? text, double columnWidth) {
      if (text == null || text.isEmpty) return 0;
      final charsPerLine = ((columnWidth - 8) / 4.3).floor();
      return 11.0 * (1 + text.length ~/ charsPerLine);
    }

    final photos = finding.evidenceFilePaths.isEmpty
        ? _photoBoxHeight
        : finding.evidenceFilePaths.length * (_photoBoxHeight + 4);
    final text = [
      textLines(finding.defectType, _colFinding),
      textLines(finding.recommendation, _colRecommendation),
      textLines(finding.notes, _colNote),
      textLines('${finding.elementName} ${finding.componentName}', _colArea) +
          14,
    ].reduce((a, b) => a > b ? a : b);
    return (photos > text ? photos : text) + 10;
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
