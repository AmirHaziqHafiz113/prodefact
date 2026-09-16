import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../config/home_inspection_config.dart';
import '../config/property_type.dart';
import 'active_session_providers.dart';

/// In-progress "New Inspection" setup: a property type plus the areas
/// the inspector is configuring, held **only in memory** — nothing here
/// is written to the database and nothing here appears in the
/// dashboard or session list.
///
/// This is deliberately a separate, lighter-weight model from
/// [InspectionSession]: a draft only ever becomes a real, persisted,
/// dashboard-visible inspection when [NewInspectionDraftNotifier.startInspection]
/// succeeds. Backing out of setup at any point before that — however
/// many times, from wherever — simply discards this object; there is
/// no database row to clean up because none was ever created. This is
/// the fix for the "backing out during setup leaves a phantom
/// inspection" defect: previously, selecting a property type called
/// straight through to [ActiveInspectionSession.startNew], which
/// persists immediately.
class NewInspectionDraft {
  const NewInspectionDraft({
    required this.propertyType,
    required this.sections,
    this.propertyDetails,
  });

  final PropertyType propertyType;
  final List<Section> sections;

  /// Filled in by the Property Details step (the screen right after
  /// property type selection) — null only if that step is somehow
  /// skipped, in which case `ReviewSetupScreen`/`startInspection` fall
  /// back to `PropertyDetails.empty`.
  final PropertyDetails? propertyDetails;

  NewInspectionDraft copyWith({
    List<Section>? sections,
    PropertyDetails? propertyDetails,
  }) {
    return NewInspectionDraft(
      propertyType: propertyType,
      sections: sections ?? this.sections,
      propertyDetails: propertyDetails ?? this.propertyDetails,
    );
  }
}

/// Owns the current (if any) [NewInspectionDraft] and every setup-time
/// edit to it. Null whenever no "New Inspection" setup is in progress.
class NewInspectionDraftNotifier extends Notifier<NewInspectionDraft?> {
  @override
  NewInspectionDraft? build() => null;

  bool _isStarting = false;

  /// Begins a fresh draft for [propertyType], discarding any previous
  /// unfinished draft. Purely in-memory — no repository call, no
  /// session id, nothing an inspection list could ever show.
  void begin(PropertyType propertyType) {
    state = NewInspectionDraft(
      propertyType: propertyType,
      sections: HomeInspectionConfig.defaultSectionsFor(propertyType),
    );
  }

  /// Abandons the current draft without starting an inspection. Safe
  /// to call any number of times, including when there is no draft.
  void discard() => state = null;

  /// Records the Property Details step's result on the draft — purely
  /// in-memory, exactly like every other setup-time edit here.
  void updatePropertyDetails(PropertyDetails details) {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(propertyDetails: details);
  }

  void resetToDefaults() {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(
      sections: HomeInspectionConfig.defaultSectionsFor(draft.propertyType),
    );
  }

  void toggleIncluded(String sectionId) {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(
      sections: [
        for (final section in draft.sections)
          if (section.id == sectionId)
            section.copyWith(isIncluded: !section.isIncluded)
          else
            section,
      ],
    );
  }

  /// Updates a draft area's name and/or plumbing flag together — used
  /// by the "Edit area" sheet for both default and custom areas. Either
  /// argument may be omitted to leave that field unchanged; a blank
  /// [name] is ignored rather than clearing the area's name.
  void updateArea(String sectionId, {String? name, bool? isPlumbing}) {
    final draft = state;
    if (draft == null) return;
    final trimmedName = name?.trim();
    state = draft.copyWith(
      sections: [
        for (final section in draft.sections)
          if (section.id == sectionId)
            section.copyWith(
              name: (trimmedName == null || trimmedName.isEmpty)
                  ? null
                  : trimmedName,
              isPlumbing: isPlumbing,
            )
          else
            section,
      ],
    );
  }

  void remove(String sectionId) {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(
      sections: draft.sections
          .where((section) => section.id != sectionId)
          .toList(),
    );
  }

  void addCustom(String name, {bool isPlumbing = false}) {
    final draft = state;
    if (draft == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = draft.copyWith(
      sections: [
        ...draft.sections,
        HomeInspectionConfig.customSection(trimmed, isPlumbing: isPlumbing),
      ],
    );
  }

  /// The explicit, final action that turns this draft into a real,
  /// persisted inspection — the only point at which
  /// [ActiveInspectionSession.startNew] is called. Guarded against a
  /// double-tap/repeated call while already in flight, so a fast
  /// double-press can never create two sessions. Returns false (and
  /// leaves the draft untouched) if there is no draft, a start is
  /// already in progress, or persistence fails.
  Future<bool> startInspection() async {
    final draft = state;
    if (draft == null || _isStarting) return false;

    _isStarting = true;
    try {
      final started = await ref
          .read(activeSessionProvider.notifier)
          .startNew(
            draft.propertyType,
            initialSections: draft.sections,
            propertyDetails: draft.propertyDetails ?? PropertyDetails.empty,
          );
      if (started) {
        state = null;
      }
      return started;
    } finally {
      _isStarting = false;
    }
  }
}

final newInspectionDraftProvider =
    NotifierProvider<NewInspectionDraftNotifier, NewInspectionDraft?>(
      NewInspectionDraftNotifier.new,
    );
