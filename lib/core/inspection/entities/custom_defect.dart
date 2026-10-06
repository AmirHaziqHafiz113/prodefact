import 'defect_catalogue.dart';

/// A defect a company added to its OWN catalogue because the ProDefact
/// master catalogue lacked it. Stored under the creating account only and
/// never merged into the master catalogue.
class CustomDefect {
  const CustomDefect({
    required this.id,
    required this.ownerUid,
    required this.elementId,
    required this.elementName,
    required this.componentId,
    required this.componentName,
    required this.defectDescription,
    required this.correctiveAction,
    required this.createdAt,
    this.note,
    this.archived = false,
  });

  /// Always `custom.<ownerUid-independent unique id>`; never collides with
  /// a master id.
  final String id;
  final String ownerUid;
  final String elementId;
  final String elementName;
  final String componentId;
  final String componentName;
  final String defectDescription;
  final String correctiveAction;
  final String? note;
  final DateTime createdAt;
  final bool archived;

  DefectCatalogueEntry toEntry() => DefectCatalogueEntry(
    id: id,
    mainElementId: elementId,
    mainElementName: elementName,
    componentId: componentId,
    componentName: componentName,
    defectId: id,
    defectDescription: defectDescription,
    correctiveAction: correctiveAction,
    isCustom: true,
  );

  CustomDefect copyWith({bool? archived}) => CustomDefect(
    id: id,
    ownerUid: ownerUid,
    elementId: elementId,
    elementName: elementName,
    componentId: componentId,
    componentName: componentName,
    defectDescription: defectDescription,
    correctiveAction: correctiveAction,
    note: note,
    createdAt: createdAt,
    archived: archived ?? this.archived,
  );
}

enum CustomDefectProblem {
  blankElement,
  blankComponent,
  blankDescription,
  blankCorrectiveAction,
  exactDuplicate,
}

class CustomDefectValidation {
  const CustomDefectValidation({
    this.problem,
    this.nearDuplicate,
    this.element,
    this.component,
    this.description,
    this.correctiveAction,
    this.note,
  });

  /// Non-null means the entry must not be saved.
  final CustomDefectProblem? problem;

  /// A similar existing entry — worth warning about, never blocking.
  final DefectCatalogueEntry? nearDuplicate;

  final String? element;
  final String? component;
  final String? description;
  final String? correctiveAction;
  final String? note;

  bool get isValid => problem == null;
}

/// Trims, collapses whitespace and strips markup characters, so a custom
/// entry can never carry HTML/script into the app or the report.
String cleanCustomText(String? raw) => (raw ?? '')
    .replaceAll(RegExp(r'[<>]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _key(String s) => cleanCustomText(s).toLowerCase();

Set<String> _words(String s) => {
  for (final w in _key(s).split(RegExp(r'[^a-z0-9]+')))
    if (w.length > 2) w,
};

/// Validates a would-be custom defect against [existing] (master + the
/// account's own custom entries).
CustomDefectValidation validateCustomDefect({
  required String element,
  required String component,
  required String description,
  required String correctiveAction,
  String? note,
  required Iterable<DefectCatalogueEntry> existing,
}) {
  final e = cleanCustomText(element);
  final c = cleanCustomText(component);
  final d = cleanCustomText(description);
  final a = cleanCustomText(correctiveAction);
  final n = cleanCustomText(note);
  CustomDefectValidation fail(CustomDefectProblem p) => CustomDefectValidation(
    problem: p,
    element: e,
    component: c,
    description: d,
    correctiveAction: a,
  );
  if (e.isEmpty) return fail(CustomDefectProblem.blankElement);
  if (c.isEmpty) return fail(CustomDefectProblem.blankComponent);
  if (d.isEmpty) return fail(CustomDefectProblem.blankDescription);
  if (a.isEmpty) return fail(CustomDefectProblem.blankCorrectiveAction);

  DefectCatalogueEntry? near;
  final dWords = _words(d);
  for (final x in existing) {
    if (_key(x.mainElementName) == _key(e) &&
        _key(x.componentName) == _key(c) &&
        _key(x.defectDescription) == _key(d)) {
      return fail(CustomDefectProblem.exactDuplicate);
    }
    if (near == null && _key(x.componentName) == _key(c)) {
      final xWords = _words(x.defectDescription);
      if (dWords.isNotEmpty && xWords.isNotEmpty) {
        final overlap = dWords.intersection(xWords).length;
        final union = dWords.union(xWords).length;
        if (overlap / union >= 0.8) near = x;
      }
    }
  }
  return CustomDefectValidation(
    nearDuplicate: near,
    element: e,
    component: c,
    description: d,
    correctiveAction: a,
    note: n.isEmpty ? null : n,
  );
}

String _slug(String s) =>
    _key(s)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

/// Reuses the master element/component ids when the (cleaned) names match
/// one; otherwise mints custom ones.
({String elementId, String componentId}) resolveCustomIds({
  required String element,
  required String component,
  required Iterable<DefectCatalogueEntry> existing,
}) {
  String? elementId;
  String? componentId;
  for (final x in existing) {
    if (_key(x.mainElementName) == _key(element)) {
      elementId ??= x.mainElementId;
      if (_key(x.componentName) == _key(component)) {
        componentId ??= x.componentId;
      }
    }
  }
  return (
    elementId: elementId ?? 'custom_element.${_slug(element)}',
    componentId:
        componentId ?? 'custom_component.${_slug(element)}.${_slug(component)}',
  );
}
