import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';
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
    this.residencePhotoPath,
  });

  final PropertyType propertyType;
  final List<Section> sections;

  /// Filled in by the Basic Details step (the screen right after
  /// property type selection) — null only if that step is somehow
  /// skipped, in which case `ReviewSetupScreen`/`startInspection` fall
  /// back to `PropertyDetails.empty`.
  ///
  /// Setup no longer asks the inspector to choose Pay as you go vs.
  /// House Pass or an AI quality tier (see the QA/QC setup-
  /// simplification pass) — every new inspection starts with
  /// `commercialMode`/`selectedAiLevel` unset, which
  /// `PricedAiClassificationCoordinator`/estimate logic already treat
  /// as "Pay as you go" and "Smart" respectively. Both remain full,
  /// independently choosable fields on `InspectionSession` — House
  /// Pass purchase (`HousePassScreen`) and a per-finding AI level
  /// override are both still available after setup.
  final PropertyDetails? propertyDetails;

  /// The optional Residence / Unit Photo chosen during setup (a local
  /// file). It becomes the new inspection's report cover photo when the
  /// inspection starts. Not a defect photo.
  final String? residencePhotoPath;

  NewInspectionDraft copyWith({
    List<Section>? sections,
    PropertyDetails? propertyDetails,
    String? residencePhotoPath,
    bool clearResidencePhoto = false,
  }) {
    return NewInspectionDraft(
      propertyType: propertyType,
      sections: sections ?? this.sections,
      propertyDetails: propertyDetails ?? this.propertyDetails,
      residencePhotoPath: clearResidencePhoto
          ? null
          : (residencePhotoPath ?? this.residencePhotoPath),
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
  void discard() {
    final photo = state?.residencePhotoPath;
    state = null;
    if (photo != null) _deleteFile(photo);
  }

  /// Chooses (or replaces) the optional Residence / Unit Photo on the draft.
  /// Returns whether a photo was set. A capture error is surfaced via
  /// [activeSessionErrorProvider]; nothing is persisted until the
  /// inspection starts.
  Future<bool> chooseResidencePhoto(EvidenceSource source) async {
    final draft = state;
    if (draft == null) return false;
    try {
      final captured = await ref
          .read(evidenceCaptureServiceProvider)
          .captureImage(
            findingId:
                'residence_draft_${DateTime.now().microsecondsSinceEpoch}',
            source: source,
          );
      if (captured == null || !ref.mounted || state == null) return false;
      final previous = state!.residencePhotoPath;
      state = state!.copyWith(residencePhotoPath: captured.filePath);
      if (previous != null) _deleteFile(previous);
      return true;
    } catch (_) {
      ref
          .read(activeSessionErrorProvider.notifier)
          .set(
            'Could not add that photo. Check camera/photo permissions and '
            'try again.',
          );
      return false;
    }
  }

  void removeResidencePhoto() {
    final draft = state;
    final photo = draft?.residencePhotoPath;
    if (draft == null || photo == null) return;
    state = draft.copyWith(clearResidencePhoto: true);
    _deleteFile(photo);
  }

  void _deleteFile(String path) {
    unawaited(ref.read(evidenceFileStoreProvider).deleteEvidenceFile(path));
  }

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
  ///
  /// [PropertyDetails.unitNumber] being required before an inspector
  /// may begin inspecting (the QA/QC simplification pass) is enforced
  /// by the UI (`PropertyDetailsScreen`'s form validator, and
  /// `ReviewSetupScreen`'s disabled Start Inspection button) rather
  /// than here — this notifier is also driven directly by tests/other
  /// callers that legitimately create a session without ever touching
  /// the Basic Details screen at all.
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
        // The setup photo becomes the new inspection's cover photo — the
        // same single write path Overview and Report Details use.
        final photo = draft.residencePhotoPath;
        if (photo != null) {
          ref.read(activeSessionProvider.notifier).setResidencePhoto(photo);
        }
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
