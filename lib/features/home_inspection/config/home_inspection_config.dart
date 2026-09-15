import '../../../core/inspection/inspection_domain.dart';
import 'property_type.dart';

/// Home Inspection specific configuration, expressed in terms of the
/// generic inspection domain (`Section`, `InspectionElement`, `Component`).
///
/// This is the only place that knows about "High Rise", "Landed", or
/// Malaysian home-inspection terminology — the engine in `core/` stays
/// industry-agnostic. Inspectors can still include/exclude/add/remove/
/// rename areas at inspection time; these are just the starting defaults.
abstract final class HomeInspectionConfig {
  /// Areas common to every property type.
  static const List<String> _commonAreaNames = [
    'Entrance / Foyer',
    'Kitchen',
    'Living Room',
    'Dining Room',
    'Yard',
    'Balcony',
    'Master Bedroom',
    'Bedroom 2',
    'Bedroom 3',
    'Bedroom 4',
    'Maid Room / Powder Room',
    'Utility / Store',
    'Master Bathroom',
    'Bathroom 2',
    'Bathroom 3',
    'AC Ledge',
    'Serambi',
    'Studio Unit',
    'Studio Bathroom',
  ];

  /// Additional areas only offered for landed properties.
  static const List<String> _landedOnlyAreaNames = [
    'Staircase',
    'Backyard',
    'External Unit Wall',
    'Porch',
    'Main Gate',
    'Mailbox / Parcel Box / Trash Bin',
    'Roof',
  ];

  /// Default areas (sections) offered for a given property type, ordered
  /// so that plumbing areas (e.g. bathrooms) come first — they must be
  /// inspected earliest since leakage/ponding tests need time to run
  /// while the inspector covers the remaining areas.
  static List<Section> defaultSectionsFor(PropertyType propertyType) {
    final names = [
      ..._commonAreaNames,
      if (propertyType == PropertyType.landed) ..._landedOnlyAreaNames,
    ];

    final sections = [
      for (final name in names)
        Section(
          id: _slugify(name),
          name: name,
          elements: defaultElements(),
          isPlumbing: _isPlumbingArea(name),
        ),
    ];

    sections.sort((a, b) {
      if (a.isPlumbing == b.isPlumbing) return 0;
      return a.isPlumbing ? -1 : 1;
    });
    return sections;
  }

  /// Areas that must be inspected first because they involve plumbing
  /// checks (leakage/ponding tests) that need time to run while the
  /// inspector covers the remaining areas. Kitchen is included because
  /// its inspection starts by opening the sink tap and monitoring for
  /// leakage, same as the bathrooms.
  static bool _isPlumbingArea(String name) {
    final lower = name.toLowerCase();
    return lower.contains('bathroom') || lower == 'kitchen';
  }

  /// The standard element/component set applied to a default area.
  /// Inspectors can still add/remove/reconfigure elements per area later;
  /// this is the Phase 1 starting configuration.
  static List<InspectionElement> defaultElements() {
    return [
      const InspectionElement(
        id: 'floor',
        name: 'Floor',
        components: [
          Component(id: 'floor_tile', name: 'Floor tile'),
          Component(id: 'cement_slab', name: 'Cement slab'),
          Component(id: 'grouting', name: 'Grouting'),
          Component(id: 'skirting', name: 'Skirting'),
          Component(id: 'timber_board', name: 'Timber board'),
        ],
      ),
      const InspectionElement(
        id: 'wall',
        name: 'Wall',
        components: [
          Component(id: 'wall', name: 'Wall'),
          Component(id: 'wall_tile', name: 'Wall tile'),
        ],
      ),
      const InspectionElement(
        id: 'ceiling',
        name: 'Ceiling',
        components: [Component(id: 'ceiling_board', name: 'Ceiling board')],
      ),
      const InspectionElement(
        id: 'door',
        name: 'Door',
        components: [
          Component(id: 'door_frame', name: 'Door frame'),
          Component(id: 'door_leaf', name: 'Door leaf'),
          Component(id: 'hinge', name: 'Hinge'),
          Component(id: 'lock', name: 'Lock'),
          Component(id: 'closer', name: 'Closer'),
          Component(id: 'other_door_component', name: 'Other components'),
        ],
      ),
      const InspectionElement(
        id: 'window',
        name: 'Window',
        components: [
          Component(id: 'frame', name: 'Frame'),
          Component(id: 'glass', name: 'Glass'),
          Component(id: 'panel', name: 'Panel'),
          Component(id: 'window_lock', name: 'Lock'),
          Component(id: 'sealant', name: 'Sealant'),
          Component(id: 'rubber_seal', name: 'Rubber seal'),
          Component(id: 'other_window_component', name: 'Other components'),
        ],
      ),
      const InspectionElement(
        id: 'm_and_e',
        name: 'M&E',
        components: [
          Component(id: 'plumbing', name: 'Plumbing'),
          Component(id: 'mechanical', name: 'Mechanical'),
          Component(id: 'electrical', name: 'Electrical'),
        ],
      ),
    ];
  }

  /// Builds a section for a custom area the inspector adds at setup time.
  /// Custom areas start included, non-plumbing, and with the same
  /// standard element set as default areas so they can participate in
  /// findings/evidence/AI review/reporting the same way.
  static Section customSection(String name) {
    return Section(
      id: 'custom_${_slugify(name)}_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      elements: defaultElements(),
    );
  }

  static String _slugify(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
