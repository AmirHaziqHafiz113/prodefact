/// A configurable sub-part of an [Element] that can be individually
/// assessed (e.g. "floor tile", "grouting", "door leaf").
class Component {
  const Component({required this.id, required this.name});

  final String id;
  final String name;

  @override
  String toString() => 'Component($id, $name)';
}
