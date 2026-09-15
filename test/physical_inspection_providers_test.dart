import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

ProviderContainer _highRiseContainer() {
  final container = ProviderContainer();
  container
      .read(selectedPropertyTypeProvider.notifier)
      .select(PropertyType.highRise);
  return container;
}

void main() {
  group('inspectionQueueProvider', () {
    test('excluded areas do not enter the inspection queue', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final configuredNotifier = container.read(
        configuredAreasProvider.notifier,
      );
      final kitchenId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Kitchen')
          .id;
      configuredNotifier.toggleIncluded(kitchenId);

      final queue = container.read(inspectionQueueProvider);
      expect(queue.any((s) => s.id == kitchenId), isFalse);
    });

    test('plumbing areas are ordered first', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final queue = container.read(inspectionQueueProvider);
      final firstNonPlumbingIndex = queue.indexWhere((s) => !s.isPlumbing);
      final lastPlumbingIndex = queue.lastIndexWhere((s) => s.isPlumbing);

      expect(queue.any((s) => s.isPlumbing), isTrue);
      expect(lastPlumbingIndex, lessThan(firstNonPlumbingIndex));
    });

    test('remaining (non-plumbing) areas follow after plumbing ones', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final queue = container.read(inspectionQueueProvider);
      final names = queue.map((s) => s.name).toList();

      expect(names.contains('Living Room'), isTrue);
      final kitchenIndex = names.indexOf('Kitchen');
      final livingRoomIndex = names.indexOf('Living Room');
      expect(kitchenIndex, lessThan(livingRoomIndex));
    });

    test('configuration from Phase 2 is respected (rename, exclude, add)', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final notifier = container.read(configuredAreasProvider.notifier);
      final bedroom2Id = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Bedroom 2')
          .id;
      notifier.rename(bedroom2Id, "Son's Room");

      final livingRoomId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Living Room')
          .id;
      notifier.toggleIncluded(livingRoomId);

      notifier.addCustom('Home Office');

      final queueNames = container
          .read(inspectionQueueProvider)
          .map((s) => s.name)
          .toList();

      expect(queueNames.contains("Son's Room"), isTrue);
      expect(queueNames.contains('Bedroom 2'), isFalse);
      expect(queueNames.contains('Living Room'), isFalse);
      expect(queueNames.contains('Home Office'), isTrue);
    });
  });

  group('sectionStatusesProvider', () {
    test('area status transitions correctly', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final sectionId = container.read(inspectionQueueProvider).first.id;
      final notifier = container.read(sectionStatusesProvider.notifier);

      expect(notifier.statusOf(sectionId), SectionStatus.notStarted);

      notifier.setStatus(sectionId, SectionStatus.inProgress);
      expect(notifier.statusOf(sectionId), SectionStatus.inProgress);

      notifier.setStatus(sectionId, SectionStatus.completed);
      expect(notifier.statusOf(sectionId), SectionStatus.completed);
    });
  });

  group('isPhysicalInspectionCompleteProvider', () {
    test('cannot complete while an included area remains unfinished', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue.skip(1)) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }
      // The first section is deliberately left not-completed.

      expect(container.read(isPhysicalInspectionCompleteProvider), isFalse);
    });

    test('can complete once every included area is completed', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }

      expect(container.read(isPhysicalInspectionCompleteProvider), isTrue);
    });

    test('excluded areas do not block completion', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final configuredNotifier = container.read(
        configuredAreasProvider.notifier,
      );
      final kitchenId = container
          .read(configuredAreasProvider)
          .firstWhere((s) => s.name == 'Kitchen')
          .id;
      configuredNotifier.toggleIncluded(kitchenId);

      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }

      expect(container.read(isPhysicalInspectionCompleteProvider), isTrue);
    });
  });

  group('inspectionFindingsProvider', () {
    test('a finding can be added and references area/element/component', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final component = element.components.first;
      final notifier = container.read(inspectionFindingsProvider.notifier);

      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: element.id,
        componentId: component.id,
        description: 'Crack in tile',
        notes: 'Near the drain',
      );

      expect(finding.sectionId, section.id);
      expect(finding.elementId, element.id);
      expect(finding.componentId, component.id);
      expect(finding.description, 'Crack in tile');
      expect(finding.notes, 'Near the drain');
      expect(finding.status, FindingStatus.draft);
      expect(
        container.read(inspectionFindingsProvider).contains(finding),
        isTrue,
      );
    });

    test('a finding can be added without a component (element-level)', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final notifier = container.read(inspectionFindingsProvider.notifier);

      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: element.id,
        description: 'General wear',
      );

      expect(finding.componentId, isNull);
    });

    test('a finding can be edited', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final notifier = container.read(inspectionFindingsProvider.notifier);

      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: element.id,
        description: 'Initial description',
      );

      notifier.updateFinding(
        findingId: finding.id,
        description: 'Updated description',
        notes: 'New note',
      );

      final updated = container
          .read(inspectionFindingsProvider)
          .firstWhere((f) => f.id == finding.id);
      expect(updated.description, 'Updated description');
      expect(updated.notes, 'New note');
      expect(updated.sectionId, section.id);
      expect(updated.elementId, element.id);
    });

    test('a finding can be removed', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      final notifier = container.read(inspectionFindingsProvider.notifier);

      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: element.id,
        description: 'To be removed',
      );
      expect(container.read(inspectionFindingsProvider), isNotEmpty);

      notifier.removeFinding(finding.id);

      expect(
        container
            .read(inspectionFindingsProvider)
            .any((f) => f.id == finding.id),
        isFalse,
      );
    });

    test('findings reset when the property type changes', () {
      final container = _highRiseContainer();
      addTearDown(container.dispose);

      final section = container.read(inspectionQueueProvider).first;
      final element = section.elements.first;
      container
          .read(inspectionFindingsProvider.notifier)
          .addFinding(sectionId: section.id, elementId: element.id);

      container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.landed);

      expect(container.read(inspectionFindingsProvider), isEmpty);
    });
  });
}
