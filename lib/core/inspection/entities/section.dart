import 'element.dart';

/// A configurable area/zone of an inspection (e.g. "Master Bathroom",
/// "Kitchen"). Presented to Home Inspection users as an "Area".
///
/// Sections are inspector-configurable per inspection: they can be
/// included, excluded, added, removed, or renamed. [isPlumbing] flags
/// sections that must be inspected first, since leakage/ponding tests
/// need time to run while other sections are inspected.
class Section {
  const Section({
    required this.id,
    required this.name,
    required this.elements,
    this.isPlumbing = false,
  });

  final String id;
  final String name;
  final List<InspectionElement> elements;
  final bool isPlumbing;

  Section copyWith({String? name}) {
    return Section(
      id: id,
      name: name ?? this.name,
      elements: elements,
      isPlumbing: isPlumbing,
    );
  }

  @override
  String toString() => 'Section($id, $name)';
}
