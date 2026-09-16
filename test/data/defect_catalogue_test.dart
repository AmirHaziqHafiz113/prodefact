import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/entities/defect_catalogue.dart';

void main() {
  final catalogue = DefectCatalogue.instance;

  test('has the expected number of main elements/components/entries', () {
    // Locks in the transcription from tool/generate_defect_catalogue.py
    // against silent accidental loss/duplication on a future edit.
    expect(catalogue.mainElements, hasLength(11));
    expect(catalogue.components, hasLength(34));
    expect(catalogue.entries, hasLength(222));
  });

  test('every entry id is unique', () {
    final ids = catalogue.entries.map((e) => e.id).toSet();
    expect(ids, hasLength(catalogue.entries.length));
  });

  test('every entry belongs to a component that belongs to a main element', () {
    for (final entry in catalogue.entries) {
      expect(entry.componentId, startsWith('${entry.mainElementId}.'));
      expect(entry.defectId, startsWith('${entry.componentId}.'));
      expect(
        catalogue.mainElements.any((m) => m.id == entry.mainElementId),
        isTrue,
        reason: 'orphaned mainElementId ${entry.mainElementId}',
      );
      expect(
        catalogue.components.any((c) => c.id == entry.componentId),
        isTrue,
        reason: 'orphaned componentId ${entry.componentId}',
      );
    }
  });

  test('corrective action mapping is deterministic — same id always '
      'resolves to the same text', () {
    for (final entry in catalogue.entries) {
      final resolved = catalogue.byId(entry.id);
      expect(resolved, isNotNull);
      expect(resolved!.correctiveAction, entry.correctiveAction);
      expect(resolved.defectDescription, entry.defectDescription);
    }
  });

  test('no duplicate component ids', () {
    final ids = catalogue.components.map((c) => c.id).toSet();
    expect(ids, hasLength(catalogue.components.length));
  });

  test('no duplicate main element ids', () {
    final ids = catalogue.mainElements.map((m) => m.id).toSet();
    expect(ids, hasLength(catalogue.mainElements.length));
  });

  test('isValidEntryId rejects an unknown/hallucinated id', () {
    expect(catalogue.isValidEntryId('door.door_bell_switch.01'), isTrue);
    expect(catalogue.isValidEntryId('made_up.entry.99'), isFalse);
    expect(catalogue.isValidEntryId(''), isFalse);
  });

  test('Furniture and Others exist as main elements with no components '
      '(preserved as genuinely blank, not invented)', () {
    expect(catalogue.mainElements.map((m) => m.id), contains('furniture'));
    expect(catalogue.mainElements.map((m) => m.id), contains('others'));
    expect(catalogue.forMainElement('furniture'), isEmpty);
    expect(catalogue.forMainElement('others'), isEmpty);
  });

  test('a defect with a genuinely blank source corrective action keeps '
      'correctiveAction null rather than a fabricated value', () {
    final missingShowerHead = catalogue.entries.firstWhere(
      (e) => e.defectDescription == 'Missing shower head',
    );
    expect(missingShowerHead.correctiveAction, isNull);
  });

  test('forComponent returns only entries under that component', () {
    final entries = catalogue.forComponent('door.door_bell_switch');
    expect(entries, isNotEmpty);
    expect(
      entries.every((e) => e.componentId == 'door.door_bell_switch'),
      isTrue,
    );
  });

  test('search matches by defect description, component, or main '
      'element name, case-insensitively', () {
    expect(
      catalogue.search('leaking/dripping').map((e) => e.componentId),
      contains('sanitary_fitting.water_tap'),
    );
    expect(catalogue.search('WATER TAP'), isNotEmpty);
    expect(catalogue.search('sanitary fitting'), isNotEmpty);
    expect(catalogue.search(''), catalogue.entries);
  });

  test('componentsForMainElement scopes correctly', () {
    final doorComponents = catalogue.componentsForMainElement('door');
    expect(doorComponents, hasLength(13));
    expect(doorComponents.every((c) => c.mainElementId == 'door'), isTrue);
  });
}
