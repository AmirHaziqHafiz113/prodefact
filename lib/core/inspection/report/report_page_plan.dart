import 'report_model.dart';

/// At most this many findings are printed on one report page, so a page
/// never becomes a wall of defects (inspector feedback, 2026-10-01).
const kMaxFindingsPerReportPage = 5;

/// One block on a defect page: an inspected area's finding, or (when
/// [finding] is null) the area's "No defects recorded" line.
class ReportPageEntry {
  const ReportPageEntry({
    required this.areaName,
    required this.showAreaHeading,
    this.areaNote,
    this.finding,
  });

  final String areaName;

  /// Whether the area's heading is printed above this entry — true for
  /// the first entry of an area on each page, so a reader never has to
  /// flip back a page to know which area a finding belongs to.
  final bool showAreaHeading;

  /// The area's note, attached only to the area's very first entry.
  final String? areaNote;
  final ReportFinding? finding;
}

/// Splits the report's areas into defect pages (page 2 onward — page 1
/// carries only the report details and Inspection Summary).
///
/// Each page holds at most [maxFindingsPerPage] findings, in report
/// order. An area with no defects adds its "No defects recorded" line
/// to the current page without counting toward the limit.
///
/// When the renderer supplies [findingHeight] (an estimate of one
/// printed finding) and [pageHeight] (the usable body height), a page
/// also ends before it would overflow — so photo-heavy findings start a
/// new planned page, with its area heading, instead of spilling onto an
/// unlabelled continuation page. [areaHeadingHeight] and
/// [noDefectsHeight] estimate the other blocks.
List<List<ReportPageEntry>> planDefectPages(
  ReportModel model, {
  int maxFindingsPerPage = kMaxFindingsPerReportPage,
  double Function(ReportFinding finding)? findingHeight,
  double pageHeight = double.infinity,
  double areaHeadingHeight = 0,
  double noDefectsHeight = 0,
}) {
  assert(maxFindingsPerPage > 0);
  final pages = <List<ReportPageEntry>>[];
  var current = <ReportPageEntry>[];
  var findingsOnPage = 0;
  var used = 0.0;

  void startPage() {
    if (current.isNotEmpty) pages.add(current);
    current = [];
    findingsOnPage = 0;
    used = 0;
  }

  bool fits(double height) => current.isEmpty || used + height <= pageHeight;

  for (final area in model.areas) {
    var firstOfArea = true;
    String? noteFor() => firstOfArea ? area.note : null;

    if (area.findings.isEmpty) {
      final height = areaHeadingHeight + noDefectsHeight;
      if (!fits(height)) startPage();
      used += height;
      current.add(
        ReportPageEntry(
          areaName: area.name,
          showAreaHeading: true,
          areaNote: noteFor(),
        ),
      );
      continue;
    }

    var headingShownOnPage = false;
    for (final finding in area.findings) {
      final height =
          (findingHeight?.call(finding) ?? 0) +
          (headingShownOnPage ? 0 : areaHeadingHeight);
      if (findingsOnPage == maxFindingsPerPage || !fits(height)) {
        startPage();
        headingShownOnPage = false;
      }
      used +=
          (findingHeight?.call(finding) ?? 0) +
          (headingShownOnPage ? 0 : areaHeadingHeight);
      current.add(
        ReportPageEntry(
          areaName: area.name,
          showAreaHeading: !headingShownOnPage,
          areaNote: noteFor(),
          finding: finding,
        ),
      );
      headingShownOnPage = true;
      firstOfArea = false;
      findingsOnPage++;
    }
  }
  startPage();
  return pages;
}
