import 'package:collection/collection.dart';

import '../entities/component.dart';
import '../entities/element.dart';
import '../entities/finding.dart';
import '../entities/inspection_session.dart';
import '../entities/section.dart';
import '../entities/section_status.dart';
import 'report_model.dart';

/// Builds the typed, print-ready [ReportModel] for a session.
///
/// This is the one place "final value precedence" is applied: where a
/// finding has a resolved AI suggestion, the report uses
/// `AiSuggestion.final*` (which already holds the inspector's
/// accept/edit/reject-correction outcome) — **never**
/// `AiSuggestion.suggested*`, the original AI output. A finding with no
/// suggestion at all (or, defensively, an unresolved one) falls back to
/// the inspector's own finding text rather than ever printing an
/// unapproved AI value. See `docs/report.md`.
///
/// Excluded areas never appear. Included areas with no findings are
/// still represented, with an empty `findings` list — the renderer is
/// responsible for printing something like "No defects recorded" for
/// those, rather than the model silently omitting them.
ReportModel buildReportModel({
  required InspectionSession session,
  required String propertyTypeLabel,
  required DateTime generatedAt,
}) {
  final includedSections = session.sections
      .where((section) => section.isIncluded)
      .toList();

  final areas = includedSections
      .map((section) => _buildAreaSection(session, section))
      .toList();

  final totalFindings = areas.fold<int>(
    0,
    (sum, area) => sum + area.findings.length,
  );
  final totalEvidence = areas.fold<int>(
    0,
    (sum, area) =>
        sum + area.findings.fold(0, (s, f) => s + f.evidenceFilePaths.length),
  );
  final completedAreas = includedSections
      .where(
        (section) =>
            session.sectionStatuses[section.id] == SectionStatus.completed,
      )
      .length;

  return ReportModel(
    sessionId: session.id,
    propertyTypeLabel: propertyTypeLabel,
    inspectionDate: session.createdAt,
    generatedAt: generatedAt,
    totalAreas: includedSections.length,
    completedAreas: completedAreas,
    totalFindings: totalFindings,
    totalEvidence: totalEvidence,
    areas: areas,
  );
}

ReportAreaSection _buildAreaSection(
  InspectionSession session,
  Section section,
) {
  final findings = session.findings
      .where((finding) => finding.sectionId == section.id)
      .map((finding) => _buildReportFinding(session, section, finding))
      .toList();

  return ReportAreaSection(
    name: section.name,
    isPlumbing: section.isPlumbing,
    findings: findings,
  );
}

ReportFinding _buildReportFinding(
  InspectionSession session,
  Section section,
  Finding finding,
) {
  final InspectionElement? element = section.elements.firstWhereOrNull(
    (e) => e.id == finding.elementId,
  );
  final Component? component = element?.components.firstWhereOrNull(
    (c) => c.id == finding.componentId,
  );

  final suggestion = session.aiSuggestions.firstWhereOrNull(
    (s) => s.findingId == finding.id,
  );
  final useFinal = suggestion != null && suggestion.isResolved;

  return ReportFinding(
    elementName: element?.name ?? finding.elementId,
    componentName: component?.name,
    defectType: useFinal
        ? _presentOrNull(suggestion.finalDefectType)
        : finding.description,
    recommendation: useFinal
        ? _presentOrNull(suggestion.finalRecommendation)
        : null,
    notes: useFinal ? _presentOrNull(suggestion.finalNotes) : finding.notes,
    evidenceFilePaths: finding.evidence.map((e) => e.filePath).toList(),
  );
}

String? _presentOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : value;
