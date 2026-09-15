import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';

import '../support/fault_injecting_repository.dart';
import '../support/test_repository.dart';

/// Durable write safety (Phase 8): when the underlying database write
/// for a mutation fails, the UI must never be left believing the change
/// was saved — [ActiveInspectionSession] rolls the in-memory state back
/// to what's actually durable and surfaces the failure via
/// `activeSessionErrorProvider`, rather than silently swallowing it. See
/// `docs/production_readiness.md` ("Durable write safety").
void main() {
  test('a failed local write is surfaced via activeSessionErrorProvider, '
      'not silently swallowed', () async {
    final faultyRepository = FaultInjectingRepository(
      createInMemoryRepository(),
    );
    final container = ProviderContainer(
      overrides: testOverrides(repository: faultyRepository),
    );
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    expect(container.read(activeSessionErrorProvider), isNull);

    faultyRepository.failNextCallTo = 'saveFinding';
    final notifier = container.read(activeSessionProvider.notifier);
    final section = container.read(activeSessionProvider)!.sections.first;
    notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Cracked tile',
    );

    // The write-through is fire-and-forget by design (responsiveness);
    // give the failed Future a turn to run and roll the state back.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(activeSessionErrorProvider), isNotNull);
  });

  test('a failed finding save does not leave the UI showing a finding the '
      'database never actually has — the in-memory state rolls back to '
      'match what was durably persisted', () async {
    final faultyRepository = FaultInjectingRepository(
      createInMemoryRepository(),
    );
    final container = ProviderContainer(
      overrides: testOverrides(repository: faultyRepository),
    );
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final section = container.read(activeSessionProvider)!.sections.first;

    faultyRepository.failNextCallTo = 'saveFinding';
    notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Cracked tile',
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // In-memory state was rolled back...
    final inMemory = container.read(activeSessionProvider)!;
    expect(inMemory.findings, isEmpty);

    // ...and that matches what the database actually has: reloading
    // from scratch shows the same (empty) picture, not a finding that
    // only ever existed in memory.
    final reloaded = await faultyRepository.loadSession(inMemory.id);
    expect(reloaded!.findings, isEmpty);
  });

  test(
    'a subsequent successful write clears a previously-surfaced error',
    () async {
      final faultyRepository = FaultInjectingRepository(
        createInMemoryRepository(),
      );
      final container = ProviderContainer(
        overrides: testOverrides(repository: faultyRepository),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(activeSessionProvider.notifier);
      final section = container.read(activeSessionProvider)!.sections.first;

      faultyRepository.failNextCallTo = 'saveFinding';
      notifier.addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
        description: 'First (fails)',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(activeSessionErrorProvider), isNotNull);

      notifier.addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
        description: 'Second (succeeds)',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeSessionErrorProvider), isNull);
    },
  );
}
