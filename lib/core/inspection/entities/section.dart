import 'element.dart';

/// A configurable area/zone of an inspection (e.g. "Master Bathroom",
/// "Kitchen"). Presented to Home Inspection users as an "Area".
///
/// Sections are inspector-configurable per inspection: they can be
/// included, excluded, added, removed, or renamed. [isPlumbing] flags
/// sections that must be inspected first, since leakage/ponding tests
/// need time to run while other sections are inspected. [isIncluded]
/// tracks whether the inspector has excluded this section from the
/// current inspection without deleting it outright.
class Section {
  const Section({
    required this.id,
    required this.name,
    required this.elements,
    this.isPlumbing = false,
    this.isIncluded = true,
  });

  final String id;
  final String name;
  final List<InspectionElement> elements;
  final bool isPlumbing;
  final bool isIncluded;

  Section copyWith({
    String? name,
    List<InspectionElement>? elements,
    bool? isPlumbing,
    bool? isIncluded,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
      isPlumbing: isPlumbing ?? this.isPlumbing,
      isIncluded: isIncluded ?? this.isIncluded,
    );
  }

  @override
  String toString() => 'Section($id, $name)';
}
