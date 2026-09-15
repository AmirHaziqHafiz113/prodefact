import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../config/property_type.dart';
import 'active_session_providers.dart';

/// The property type of the active inspection session. Null until a
/// session is started or resumed.
///
/// Derived from [activeSessionProvider] — [select] starts a brand new
/// local session (see [ActiveInspectionSession.startNew]) rather than
/// holding its own state, so the property type and the rest of the
/// session's persisted data can never drift apart.
class SelectedPropertyType extends Notifier<PropertyType?> {
  @override
  PropertyType? build() {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return null;
    for (final propertyType in PropertyType.values) {
      if (propertyType.name == session.assetTypeId) return propertyType;
    }
    return null;
  }

  Future<void> select(PropertyType propertyType) {
    return ref.read(activeSessionProvider.notifier).startNew(propertyType);
  }
}

final selectedPropertyTypeProvider =
    NotifierProvider<SelectedPropertyType, PropertyType?>(
      SelectedPropertyType.new,
    );

/// The inspector's configured areas (sections) for the active session:
/// included/excluded state, renames, custom additions, and removals all
/// write through to local storage via [activeSessionProvider].
///
/// [build] re-derives from the active session, so unrelated widget
/// rebuilds never reset the inspector's configuration — only starting
/// or resuming a session changes it.
class ConfiguredAreas extends Notifier<List<Section>> {
  @override
  List<Section> build() {
    return ref.watch(activeSessionProvider)?.sections ?? const [];
  }

  /// Discards all edits and restores the default area list for the
  /// active session's property type.
  void resetToDefaults() {
    ref.read(activeSessionProvider.notifier).resetAreasToDefaults();
  }

  void toggleIncluded(String sectionId) {
    ref.read(activeSessionProvider.notifier).toggleAreaIncluded(sectionId);
  }

  void rename(String sectionId, String newName) {
    ref.read(activeSessionProvider.notifier).renameArea(sectionId, newName);
  }

  void remove(String sectionId) {
    ref.read(activeSessionProvider.notifier).removeArea(sectionId);
  }

  void addCustom(String name) {
    ref.read(activeSessionProvider.notifier).addCustomArea(name);
  }
}

final configuredAreasProvider =
    NotifierProvider<ConfiguredAreas, List<Section>>(ConfiguredAreas.new);
