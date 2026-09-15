import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import 'home_inspection_providers.dart';

/// The ordered queue of areas to physically inspect: included areas
/// only, with plumbing-related areas first — their leakage/ponding tests
/// need time to run while the inspector covers the remaining areas.
///
/// Derived from [configuredAreasProvider], so it always reflects the
/// inspector's current Phase 2 configuration (renames, exclusions,
/// custom areas).
final inspectionQueueProvider = Provider<List<Section>>((ref) {
  final sections = ref
      .watch(configuredAreasProvider)
      .where((section) => section.isIncluded)
      .toList();

  sections.sort((a, b) {
    if (a.isPlumbing == b.isPlumbing) return 0;
    return a.isPlumbing ? -1 : 1;
  });
  return sections;
});

/// Per-area physical inspection progress, keyed by section id. An area
/// missing from the map is [SectionStatus.notStarted].
///
/// Resets only when the property type changes (a new inspection begins)
/// — unrelated widget rebuilds and navigation never lose progress.
class SectionStatuses extends Notifier<Map<String, SectionStatus>> {
  @override
  Map<String, SectionStatus> build() {
    ref.watch(selectedPropertyTypeProvider);
    return const {};
  }

  SectionStatus statusOf(String sectionId) =>
      state[sectionId] ?? SectionStatus.notStarted;

  void setStatus(String sectionId, SectionStatus status) {
    state = {...state, sectionId: status};
  }
}

final sectionStatusesProvider =
    NotifierProvider<SectionStatuses, Map<String, SectionStatus>>(
      SectionStatuses.new,
    );

/// Whether every area in [inspectionQueueProvider] has been marked
/// [SectionStatus.completed]. The full physical inspection can only be
/// completed once this is true.
final isPhysicalInspectionCompleteProvider = Provider<bool>((ref) {
  final queue = ref.watch(inspectionQueueProvider);
  if (queue.isEmpty) return false;

  final statuses = ref.watch(sectionStatusesProvider);
  return queue.every(
    (section) =>
        (statuses[section.id] ?? SectionStatus.notStarted) ==
        SectionStatus.completed,
  );
});

String? _orNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Findings recorded during physical inspection.
///
/// Resets only when the property type changes (a new inspection begins)
/// — unrelated widget rebuilds and navigation never lose in-progress
/// findings.
class InspectionFindings extends Notifier<List<Finding>> {
  @override
  List<Finding> build() {
    ref.watch(selectedPropertyTypeProvider);
    return const [];
  }

  Finding addFinding({
    required String sectionId,
    required String elementId,
    String? componentId,
    String? description,
    String? notes,
  }) {
    final finding = Finding(
      id: 'finding_${DateTime.now().microsecondsSinceEpoch}',
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      description: _orNull(description),
      notes: _orNull(notes),
    );
    state = [...state, finding];
    return finding;
  }

  /// Replaces the description and notes of an existing finding. Both are
  /// required (even if unchanged) so a caller can never accidentally
  /// wipe one field while only meaning to update the other.
  void updateFinding({
    required String findingId,
    required String? description,
    required String? notes,
  }) {
    state = [
      for (final finding in state)
        if (finding.id == findingId)
          finding.copyWith(
            description: _orNull(description) ?? '',
            notes: _orNull(notes) ?? '',
          )
        else
          finding,
    ];
  }

  void removeFinding(String findingId) {
    state = state.where((finding) => finding.id != findingId).toList();
  }

  List<Finding> forSection(String sectionId) =>
      state.where((finding) => finding.sectionId == sectionId).toList();

  List<Finding> forElement(String sectionId, String elementId) => state
      .where(
        (finding) =>
            finding.sectionId == sectionId && finding.elementId == elementId,
      )
      .toList();
}

final inspectionFindingsProvider =
    NotifierProvider<InspectionFindings, List<Finding>>(InspectionFindings.new);
