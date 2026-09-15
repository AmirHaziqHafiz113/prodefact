import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../config/home_inspection_config.dart';
import '../config/property_type.dart';

/// The property type the inspector has chosen for the current inspection.
/// Null until a choice is made on the entry screen.
class SelectedPropertyType extends Notifier<PropertyType?> {
  @override
  PropertyType? build() => null;

  void select(PropertyType propertyType) => state = propertyType;
}

final selectedPropertyTypeProvider =
    NotifierProvider<SelectedPropertyType, PropertyType?>(
      SelectedPropertyType.new,
    );

/// The inspector's configured areas (sections) for the current
/// inspection setup: included/excluded state, renames, custom additions,
/// and removals all live here as mutable state.
///
/// [build] re-initializes to the selected property type's defaults only
/// when the property type actually changes (it watches
/// [selectedPropertyTypeProvider]) — unrelated widget rebuilds do not
/// reset the inspector's configuration.
class ConfiguredAreas extends Notifier<List<Section>> {
  @override
  List<Section> build() {
    final propertyType = ref.watch(selectedPropertyTypeProvider);
    if (propertyType == null) return const [];
    return HomeInspectionConfig.defaultSectionsFor(propertyType);
  }

  /// Discards all edits and restores the default area list for the
  /// currently selected property type.
  void resetToDefaults() {
    final propertyType = ref.read(selectedPropertyTypeProvider);
    if (propertyType == null) return;
    state = HomeInspectionConfig.defaultSectionsFor(propertyType);
  }

  void toggleIncluded(String sectionId) {
    state = [
      for (final section in state)
        if (section.id == sectionId)
          section.copyWith(isIncluded: !section.isIncluded)
        else
          section,
    ];
  }

  void rename(String sectionId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final section in state)
        if (section.id == sectionId)
          section.copyWith(name: trimmed)
        else
          section,
    ];
  }

  void remove(String sectionId) {
    state = state.where((section) => section.id != sectionId).toList();
  }

  void addCustom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [...state, HomeInspectionConfig.customSection(trimmed)];
  }
}

final configuredAreasProvider =
    NotifierProvider<ConfiguredAreas, List<Section>>(ConfiguredAreas.new);
