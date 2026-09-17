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
    this.note,
  });

  final String id;
  final String name;
  final List<InspectionElement> elements;
  final bool isPlumbing;
  final bool isIncluded;

  /// An optional, contextual note about this area — e.g. "Ponding test
  /// started at 10:15 AM." or "Area inaccessible behind cabinet." Not a
  /// defect, never sent through AI classification; surfaced under this
  /// area's heading in the generated report when present.
  final String? note;

  /// [clearNote] explicitly sets [note] back to null — needed because
  /// the `??` pattern used for every other optional field here can't
  /// distinguish "leave unchanged" from "clear it".
  Section copyWith({
    String? name,
    List<InspectionElement>? elements,
    bool? isPlumbing,
    bool? isIncluded,
    String? note,
    bool clearNote = false,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
      isPlumbing: isPlumbing ?? this.isPlumbing,
      isIncluded: isIncluded ?? this.isIncluded,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  String toString() => 'Section($id, $name)';
}
