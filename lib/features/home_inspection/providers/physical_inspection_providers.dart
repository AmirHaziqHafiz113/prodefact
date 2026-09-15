import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import 'active_session_providers.dart';
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
/// Derived from and written through [activeSessionProvider], so progress
/// is durable across restarts and never lost to unrelated rebuilds.
class SectionStatuses extends Notifier<Map<String, SectionStatus>> {
  @override
  Map<String, SectionStatus> build() {
    return ref.watch(activeSessionProvider)?.sectionStatuses ?? const {};
  }

  SectionStatus statusOf(String sectionId) =>
      state[sectionId] ?? SectionStatus.notStarted;

  void setStatus(String sectionId, SectionStatus status) {
    ref
        .read(activeSessionProvider.notifier)
        .setSectionStatus(sectionId, status);
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

/// Findings recorded during physical inspection.
///
/// Derived from and written through [activeSessionProvider], so
/// findings are durable across restarts and never lost to unrelated
/// rebuilds or navigation.
class InspectionFindings extends Notifier<List<Finding>> {
  @override
  List<Finding> build() {
    return ref.watch(activeSessionProvider)?.findings ?? const [];
  }

  Finding addFinding({
    required String sectionId,
    required String elementId,
    String? componentId,
    String? description,
    String? notes,
  }) {
    return ref
        .read(activeSessionProvider.notifier)
        .addFinding(
          sectionId: sectionId,
          elementId: elementId,
          componentId: componentId,
          description: description,
          notes: notes,
        );
  }

  /// Replaces the description and notes of an existing finding. Both are
  /// required (even if unchanged) so a caller can never accidentally
  /// wipe one field while only meaning to update the other.
  void updateFinding({
    required String findingId,
    required String? description,
    required String? notes,
  }) {
    ref
        .read(activeSessionProvider.notifier)
        .updateFinding(
          findingId: findingId,
          description: description,
          notes: notes,
        );
  }

  void removeFinding(String findingId) {
    ref.read(activeSessionProvider.notifier).removeFinding(findingId);
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
