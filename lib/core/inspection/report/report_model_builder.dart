import 'package:collection/collection.dart';

import '../entities/ai_review.dart';
import '../entities/component.dart';
import '../entities/defect_catalogue.dart';
import '../entities/element.dart';
import '../entities/finding.dart';
import '../entities/inspection_session.dart';
import '../entities/report_metadata.dart';
import '../entities/section.dart';
import '../entities/section_status.dart';
import 'report_model.dart';

/// Builds the typed, print-ready [ReportModel] for a session.
///
/// This is the one place "final value precedence" is applied. For a
/// camera-first finding, the report always uses the inspector's
/// **final, approved catalogue entry** — resolved fresh from
/// `DefectCatalogue` by id, never any AI-provided free text — never
/// the original AI suggestion, and never a still-pending or rejected/
/// unresolved classification presented as if it were approved. A
/// legacy finding (schema v5 and earlier, component-first workflow,
/// `elementId` set) falls back to its own recorded element/component/
/// description text, unaffected by any of this. See `docs/report.md`.
///
/// Excluded areas never appear. Included areas with no findings are
/// still represented, with an empty `findings` list — the renderer is
/// responsible for printing something like "No defects recorded" for
/// those, rather than the model silently omitting them.
ReportModel buildReportModel({
  required InspectionSession session,
  required String propertyTypeLabel,
  required DateTime generatedAt,
  int version = 1,
}) {
  final includedSections = session.sections
      .where((section) => section.isIncluded)
      .toList();

  var nextNumber = 1;
  final areas = includedSections.map((section) {
    final area = _buildAreaSection(session, section, nextNumber);
    nextNumber += area.findings.length;
    return area;
  }).toList();

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

  // The inspector-confirmed report metadata takes precedence over the
  // original Property Details setup data — see `ReportMetadata`'s doc
  // comment for why they're kept as two separate values.
  final details = session.propertyDetails;
  final metadata =
      session.reportMetadata ??
      (details.isEmpty
          ? null
          : ReportMetadata.fromPropertyDetails(
              details,
              reportDate: generatedAt,
            ));

  return ReportModel(
    sessionId: session.id,
    propertyTypeLabel: propertyTypeLabel,
    inspectionDate: metadata?.inspectionDate ?? session.createdAt,
    generatedAt: generatedAt,
    totalAreas: includedSections.length,
    completedAreas: completedAreas,
    totalFindings: totalFindings,
    totalEvidence: totalEvidence,
    areas: areas,
    version: version,
    propertyTitle: metadata?.title,
    propertyAddress: metadata?.address,
    projectDeveloperName: metadata?.projectDeveloperName,
    blockTower: metadata?.blockTower,
    unitNumber: metadata?.unitNumber,
    clientName: metadata?.clientName,
    inspectorName: metadata?.inspectorName,
    contactNumber: metadata?.contactNumber,
    reportDate: metadata?.reportDate,
    inspectionNote: session.inspectionNote,
  );
}

ReportAreaSection _buildAreaSection(
  InspectionSession session,
  Section section,
  int startingNumber,
) {
  final sectionFindings = session.findings
      .where((finding) => finding.sectionId == section.id)
      .toList();
  final findings = [
    for (var i = 0; i < sectionFindings.length; i++)
      _buildReportFinding(
        session,
        section,
        sectionFindings[i],
        startingNumber + i,
      ),
  ];

  return ReportAreaSection(
    name: section.name,
    isPlumbing: section.isPlumbing,
    findings: findings,
    note: section.note,
  );
}

ReportFinding _buildReportFinding(
  InspectionSession session,
  Section section,
  Finding finding,
  int number,
) {
  final AiSuggestion? suggestion = session.aiSuggestions.firstWhereOrNull(
    (s) => s.findingId == finding.id,
  );

  // A camera-first finding (no legacy elementId) always goes through
  // the catalogue — never the raw suggested* text, and never the
  // inspector's own free-text description as a stand-in for an
  // approved classification.
  if (finding.elementId == null) {
    return _buildCatalogueReportFinding(finding, suggestion, number);
  }

  // Legacy (schema v5 and earlier, component-first) finding — unaltered
  // behavior from before the catalogue existed: uses the inspector's
  // approved AI final* text when a resolved legacy suggestion exists,
  // otherwise the finding's own recorded element/component/description.
  final InspectionElement? element = section.elements.firstWhereOrNull(
    (e) => e.id == finding.elementId,
  );
  final Component? component = element?.components.firstWhereOrNull(
    (c) => c.id == finding.componentId,
  );
  final useLegacyFinal = suggestion != null && suggestion.isResolved;

  return ReportFinding(
    number: number,
    elementName:
        (useLegacyFinal ? suggestion.legacyFinalElementId : null) ??
        element?.name ??
        finding.elementId ??
        'Unspecified',
    componentName:
        (useLegacyFinal ? suggestion.legacyFinalComponentId : null) ??
        component?.name,
    defectType:
        (useLegacyFinal
            ? _presentOrNull(suggestion.legacyFinalDefectType)
            : null) ??
        finding.description,
    recommendation: useLegacyFinal
        ? _presentOrNull(suggestion.legacyFinalRecommendation)
        : null,
    notes:
        (useLegacyFinal ? _presentOrNull(suggestion.legacyFinalNotes) : null) ??
        finding.notes,
    evidenceFilePaths: finding.evidence.map((e) => e.filePath).toList(),
  );
}

String? _presentOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : value;

ReportFinding _buildCatalogueReportFinding(
  Finding finding,
  AiSuggestion? suggestion,
  int number,
) {
  final evidencePaths = finding.evidence.map((e) => e.filePath).toList();

  if (suggestion == null || !suggestion.isResolved) {
    // Physical inspection data is never withheld from the report just
    // because AI/review hasn't finished — report generation itself is
    // gated on this (see the report readiness rule), so reaching this
    // branch in practice means a defensive fallback, not the normal
    // path.
    return ReportFinding(
      number: number,
      elementName: 'Pending review',
      notes: finding.notes ?? finding.description,
      evidenceFilePaths: evidencePaths,
    );
  }

  final entryId = suggestion.finalCatalogueEntryId;
  final entry = (entryId == null || entryId.isEmpty)
      ? null
      : DefectCatalogue.instance.byId(entryId);

  if (entry == null) {
    // Reviewed but explicitly left unresolved (Reject/mark unresolved).
    return ReportFinding(
      number: number,
      elementName: 'Unresolved',
      componentName: null,
      defectType: 'Unresolved — pending manual classification',
      notes: finding.notes ?? finding.description,
      evidenceFilePaths: evidencePaths,
    );
  }

  return ReportFinding(
    number: number,
    elementName: entry.mainElementName,
    componentName: entry.componentName,
    defectType: entry.defectDescription,
    recommendation: entry.correctiveAction,
    notes: finding.notes,
    evidenceFilePaths: evidencePaths,
  );
}
