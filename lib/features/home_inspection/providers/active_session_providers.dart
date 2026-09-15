import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';
import '../config/home_inspection_config.dart';
import '../config/property_type.dart';
import 'session_list_providers.dart';

String? _orNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// The single active inspection session, held fully in memory and
/// written through to [InspectionRepository] on every change.
///
/// The local database is the durable source of truth; this notifier is
/// a synchronized in-memory mirror of it so the UI can read/update
/// state synchronously without waiting on disk I/O for every rebuild.
/// Persistence happens as an un-awaited write-through after each
/// in-memory update, which is why normal inspection work never blocks
/// on storage — offline or otherwise.
///
/// Null until a session is started ([startNew]) or resumed ([resume]).
class ActiveInspectionSession extends Notifier<InspectionSession?> {
  @override
  InspectionSession? build() => null;

  InspectionRepository get _repository =>
      ref.read(inspectionRepositoryProvider);

  Future<void> startNew(PropertyType propertyType) async {
    final sections = HomeInspectionConfig.defaultSectionsFor(propertyType);
    final session = await _repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: propertyType.name,
      initialSections: sections,
    );
    state = session;
    ref.invalidate(sessionSummariesProvider);
  }

  Future<void> resume(String sessionId) async {
    state = await _repository.loadSession(sessionId);
  }

  void clear() => state = null;

  // ---- area configuration (Phase 2) ----

  void resetAreasToDefaults() {
    final session = state;
    if (session == null) return;
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == session.assetTypeId,
    );
    if (propertyType == null) return;
    _updateSections(HomeInspectionConfig.defaultSectionsFor(propertyType));
  }

  void toggleAreaIncluded(String sectionId) {
    final session = state;
    if (session == null) return;
    _updateSections([
      for (final section in session.sections)
        if (section.id == sectionId)
          section.copyWith(isIncluded: !section.isIncluded)
        else
          section,
    ]);
  }

  void renameArea(String sectionId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final session = state;
    if (session == null) return;
    _updateSections([
      for (final section in session.sections)
        if (section.id == sectionId)
          section.copyWith(name: trimmed)
        else
          section,
    ]);
  }

  void removeArea(String sectionId) {
    final session = state;
    if (session == null) return;
    _updateSections(
      session.sections.where((section) => section.id != sectionId).toList(),
    );
  }

  void addCustomArea(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final session = state;
    if (session == null) return;
    _updateSections([
      ...session.sections,
      HomeInspectionConfig.customSection(trimmed),
    ]);
  }

  void _updateSections(List<Section> sections) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(sections: sections, updatedAt: DateTime.now());
    unawaited(_repository.saveSections(session.id, sections));
    ref.invalidate(sessionSummariesProvider);
  }

  // ---- physical inspection progress (Phase 3) ----

  void setSectionStatus(String sectionId, SectionStatus status) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      sectionStatuses: {...session.sectionStatuses, sectionId: status},
      updatedAt: DateTime.now(),
    );
    unawaited(_repository.saveSectionStatus(session.id, sectionId, status));
    ref.invalidate(sessionSummariesProvider);
  }

  Finding addFinding({
    required String sectionId,
    required String elementId,
    String? componentId,
    String? description,
    String? notes,
  }) {
    final session = state;
    if (session == null) {
      throw StateError('Cannot add a finding without an active session');
    }
    final now = DateTime.now();
    final finding = Finding(
      id: 'finding_${now.microsecondsSinceEpoch}',
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      description: _orNull(description),
      notes: _orNull(notes),
      createdAt: now,
      updatedAt: now,
    );
    state = session.copyWith(
      findings: [...session.findings, finding],
      updatedAt: now,
    );
    unawaited(_repository.saveFinding(session.id, finding));
    ref.invalidate(sessionSummariesProvider);
    return finding;
  }

  void updateFinding({
    required String findingId,
    required String? description,
    required String? notes,
  }) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    Finding? updatedFinding;
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          (updatedFinding = finding.copyWith(
            description: _orNull(description) ?? '',
            notes: _orNull(notes) ?? '',
            updatedAt: now,
          ))
        else
          finding,
    ];
    final finding = updatedFinding;
    if (finding == null) return;
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.saveFinding(session.id, finding));
    ref.invalidate(sessionSummariesProvider);
  }

  void removeFinding(String findingId) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      findings: session.findings
          .where((finding) => finding.id != findingId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    unawaited(_repository.deleteFinding(session.id, findingId));
    ref.invalidate(sessionSummariesProvider);
  }

  Future<void> markPhysicalInspectionComplete() async {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    state = session.copyWith(
      status: InspectionStatus.physicalInspectionComplete,
      updatedAt: now,
    );
    await _repository.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    ref.invalidate(sessionSummariesProvider);
  }

  // ---- evidence (Phase 4) ----

  Future<void> addEvidence({
    required String findingId,
    required EvidenceSource source,
  }) async {
    final session = state;
    if (session == null) return;

    final captureService = ref.read(evidenceCaptureServiceProvider);
    final captured = await captureService.captureImage(
      findingId: findingId,
      source: source,
    );
    if (captured == null) return; // user cancelled the picker

    final now = DateTime.now();
    final evidence = Evidence(
      id: 'evidence_${now.microsecondsSinceEpoch}',
      findingId: findingId,
      filePath: captured.filePath,
      createdAt: now,
      source: captured.source,
    );

    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: [...finding.evidence, evidence],
            updatedAt: now,
          )
        else
          finding,
    ];
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.addEvidence(session.id, evidence));
  }

  void removeEvidence({required String findingId, required String evidenceId}) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: finding.evidence
                .where((e) => e.id != evidenceId)
                .toList(),
            updatedAt: now,
          )
        else
          finding,
    ];
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.removeEvidence(session.id, evidenceId));
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveInspectionSession, InspectionSession?>(
      ActiveInspectionSession.new,
    );
