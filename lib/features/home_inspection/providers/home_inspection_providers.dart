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

/// The default areas (sections) for the currently selected property type,
/// ordered with plumbing areas first. Empty until a property type is
/// selected.
final defaultSectionsProvider = Provider<List<Section>>((ref) {
  final propertyType = ref.watch(selectedPropertyTypeProvider);
  if (propertyType == null) return const [];
  return HomeInspectionConfig.defaultSectionsFor(propertyType);
});
