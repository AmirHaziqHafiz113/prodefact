import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// The app's concrete-defect terms must match the backend's exactly:
/// both are pinned to the same fixture (generated from
/// `functions/src/ai/defect_terms.ts`).
void main() {
  test('every catalogue entry yields the same terms as the backend', () {
    final fixture =
        (jsonDecode(
          File('functions/src/ai/defect_terms.fixture.json').readAsStringSync(),
        ) as Map<String, dynamic>).map(
          (id, terms) => MapEntry(id, List<String>.from(terms as List)),
        );
    final actual = <String, List<String>>{
      for (final e in DefectCatalogue.instance.entries)
        if (defectTermsFor(e.defectDescription).isNotEmpty)
          e.id: defectTermsFor(e.defectDescription),
    };
    expect(actual, fixture);
  });

  test('a term is only accepted when it is one of the entry\'s own '
      'alternatives; the report reads "Component - term"', () {
    const description =
        'Wall tile inconsistent colour tone/Wall tile is '
        'damaged/chipped/hollow/uneven/not straight';
    expect(matchDefectTerm(description, ' Hollow '), 'hollow');
    expect(matchDefectTerm(description, 'chipped/hollow'), isNull);
    expect(matchDefectTerm(description, 'leaking'), isNull);
    expect(
      defectTermsFor(
        'Door closer produces creaking sound when '
        'opened/closed',
      ),
      isEmpty,
    );
    expect(
      concreteDefectText(
        componentName: 'Wall Tile',
        defectDescription: description,
        term: 'hollow',
      ),
      'Wall Tile - hollow',
    );
    expect(
      concreteDefectText(
        componentName: 'Wall Tile',
        defectDescription: description,
      ),
      description,
    );
  });
}
