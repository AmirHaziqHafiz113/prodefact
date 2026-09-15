import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/config/home_inspection_config.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';

void main() {
  group('HomeInspectionConfig.defaultSectionsFor', () {
    test('landed properties include landed-only areas', () {
      final highRise = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.highRise,
      );
      final landed = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.landed,
      );

      final highRiseNames = highRise.map((s) => s.name).toSet();
      final landedNames = landed.map((s) => s.name).toSet();

      expect(highRiseNames.contains('Staircase'), isFalse);
      expect(landedNames.contains('Staircase'), isTrue);
      expect(landedNames.contains('Roof'), isTrue);
      expect(landed.length, greaterThan(highRise.length));
    });

    test('plumbing areas are sorted before non-plumbing areas', () {
      final sections = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.highRise,
      );

      final firstNonPlumbingIndex = sections.indexWhere((s) => !s.isPlumbing);
      final lastPlumbingIndex = sections.lastIndexWhere((s) => s.isPlumbing);

      expect(sections.any((s) => s.isPlumbing), isTrue);
      expect(lastPlumbingIndex, lessThan(firstNonPlumbingIndex));
    });

    test('plumbing-first areas are exactly the bathrooms plus kitchen', () {
      final sections = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.highRise,
      );

      final plumbingNames = sections
          .where((s) => s.isPlumbing)
          .map((s) => s.name)
          .toSet();

      expect(plumbingNames, {
        'Master Bathroom',
        'Bathroom 2',
        'Bathroom 3',
        'Studio Bathroom',
        'Kitchen',
      });
    });

    test('every default section has the standard element set', () {
      final sections = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.highRise,
      );

      for (final section in sections) {
        final elementNames = section.elements.map((e) => e.name).toSet();
        expect(elementNames, {
          'Floor',
          'Wall',
          'Ceiling',
          'Door',
          'Window',
          'M&E',
        });
      }
    });

    test('section ids are unique', () {
      final sections = HomeInspectionConfig.defaultSectionsFor(
        PropertyType.landed,
      );
      final ids = sections.map((s) => s.id).toSet();
      expect(ids.length, sections.length);
    });
  });
}
