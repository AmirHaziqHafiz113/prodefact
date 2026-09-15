import 'dart:convert';

import '../../core/inspection/inspection_domain.dart';

/// JSON (de)serialization for a section's element/component template.
/// Kept out of `core/inspection` so the domain entities stay free of
/// persistence-format concerns.
String encodeElements(List<InspectionElement> elements) {
  return jsonEncode(elements.map(_elementToJson).toList());
}

List<InspectionElement> decodeElements(String json) {
  final decoded = jsonDecode(json) as List<dynamic>;
  return decoded
      .map((e) => _elementFromJson(e as Map<String, dynamic>))
      .toList();
}

Map<String, dynamic> _elementToJson(InspectionElement element) => {
  'id': element.id,
  'name': element.name,
  'components': element.components.map(_componentToJson).toList(),
};

InspectionElement _elementFromJson(Map<String, dynamic> json) {
  return InspectionElement(
    id: json['id'] as String,
    name: json['name'] as String,
    components: (json['components'] as List<dynamic>)
        .map((c) => _componentFromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _componentToJson(Component component) => {
  'id': component.id,
  'name': component.name,
};

Component _componentFromJson(Map<String, dynamic> json) {
  return Component(id: json['id'] as String, name: json['name'] as String);
}
