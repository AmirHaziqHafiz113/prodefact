import 'component.dart';

/// A configurable physical element inspected within a [Section] (e.g.
/// "Floor", "Wall", "Door"), made up of one or more [Component]s.
class InspectionElement {
  const InspectionElement({
    required this.id,
    required this.name,
    required this.components,
  });

  final String id;
  final String name;
  final List<Component> components;

  @override
  String toString() => 'InspectionElement($id, $name)';
}
