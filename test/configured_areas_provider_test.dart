import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';

void main() {
  group('configuredAreasProvider', () {
    test('High Rise loads the correct default sections', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final names = container
          .read(configuredAreasProvider)
          .map((s) => s.name)
          .toSet();

      expect(names.contains('Kitchen'), isTrue);
      expect(names.contains('Master Bathroom'), isTrue);
      expect(names.contains('Staircase'), isFalse);
      expect(names.contains('Roof'), isFalse);
    });

    test(
      'Landed loads the correct default sections including landed-only ones',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(selectedPropertyTypeProvider.notifier)
            .select(PropertyType.landed);

        final names = container
            .read(configuredAreasProvider)
            .map((s) => s.name)
            .toSet();

        expect(names.contains('Kitchen'), isTrue);
        expect(names.contains('Master Bathroom'), isTrue);
        expect(names.contains('Staircase'), isTrue);
        expect(names.contains('Roof'), isTrue);
      },
    );

    test('every default section starts included', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      expect(
        container.read(configuredAreasProvider).every((s) => s.isIncluded),
        isTrue,
      );
    });

    test('toggleIncluded flips a single section without affecting others', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      final kitchenId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Kitchen')
          .id;

      notifier.toggleIncluded(kitchenId);

      final sections = container.read(configuredAreasProvider);
      final kitchen = sections.firstWhere((s) => s.id == kitchenId);
      expect(kitchen.isIncluded, isFalse);
      expect(
        sections.where((s) => s.id != kitchenId).every((s) => s.isIncluded),
        isTrue,
      );

      notifier.toggleIncluded(kitchenId);
      expect(
        container
            .read(configuredAreasProvider)
            .firstWhere((s) => s.id == kitchenId)
            .isIncluded,
        isTrue,
      );
    });

    test('rename updates only the targeted section name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      final bedroomId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Bedroom 2')
          .id;

      notifier.rename(bedroomId, "Son's Room");

      final sections = container.read(configuredAreasProvider);
      expect(sections.firstWhere((s) => s.id == bedroomId).name, "Son's Room");
      expect(sections.any((s) => s.name == 'Bedroom 3'), isTrue);
    });

    test('rename ignores blank input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      final kitchenId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Kitchen')
          .id;

      notifier.rename(kitchenId, '   ');

      expect(
        container
            .read(configuredAreasProvider)
            .firstWhere((s) => s.id == kitchenId)
            .name,
        'Kitchen',
      );
    });

    test('addCustom appends a new included, non-plumbing section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      final beforeCount = container.read(configuredAreasProvider).length;

      notifier.addCustom('Home Office');

      final sections = container.read(configuredAreasProvider);
      expect(sections.length, beforeCount + 1);
      final added = sections.firstWhere((s) => s.name == 'Home Office');
      expect(added.isIncluded, isTrue);
      expect(added.isPlumbing, isFalse);
      expect(added.elements, isNotEmpty);
    });

    test('remove deletes the targeted section entirely', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      final beforeCount = container.read(configuredAreasProvider).length;
      final bedroom4Id = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Bedroom 4')
          .id;

      notifier.remove(bedroom4Id);

      final sections = container.read(configuredAreasProvider);
      expect(sections.length, beforeCount - 1);
      expect(sections.any((s) => s.id == bedroom4Id), isFalse);
    });

    test(
      'plumbing metadata is preserved through include/exclude and rename',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(selectedPropertyTypeProvider.notifier)
            .select(PropertyType.highRise);
        final notifier = container.read(configuredAreasProvider.notifier);
        final masterBathroomId = container
            .read(configuredAreasProvider)
            .firstWhere((s) => s.name == 'Master Bathroom')
            .id;

        notifier.toggleIncluded(masterBathroomId);
        notifier.rename(masterBathroomId, 'Main Bathroom');

        final section = container
            .read(configuredAreasProvider)
            .firstWhere((s) => s.id == masterBathroomId);
        expect(section.isPlumbing, isTrue);
        expect(section.name, 'Main Bathroom');
        expect(section.isIncluded, isFalse);
      },
    );

    test('resetToDefaults discards edits and restores defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(configuredAreasProvider.notifier);
      notifier.addCustom('Home Office');
      final kitchenId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Kitchen')
          .id;
      notifier.remove(kitchenId);

      notifier.resetToDefaults();

      final names = container
          .read(configuredAreasProvider)
          .map((s) => s.name)
          .toSet();
      expect(names.contains('Home Office'), isFalse);
      expect(names.contains('Kitchen'), isTrue);
    });

    test('changing property type re-initializes to the new defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      container.read(configuredAreasProvider.notifier).addCustom('Home Office');

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.landed);

      final names = container
          .read(configuredAreasProvider)
          .map((s) => s.name)
          .toSet();
      expect(names.contains('Home Office'), isFalse);
      expect(names.contains('Staircase'), isTrue);
    });
  });
}
