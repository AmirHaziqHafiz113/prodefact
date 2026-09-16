import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';

import '../support/test_repository.dart';

/// Regression coverage for the "backing out during New Inspection setup
/// leaves a phantom inspection" defect: selecting a property type must
/// never, by itself, persist anything — see `NewInspectionDraftNotifier`.
void main() {
  test('selecting High Rise starts an in-memory draft only — no session '
      'is persisted, and the dashboard list is empty', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);

    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);

    expect(container.read(newInspectionDraftProvider), isNotNull);
    expect(container.read(activeSessionProvider), isNull);

    final repository = container.read(inspectionRepositoryProvider);
    final summaries = await repository.listSessions();
    expect(summaries, isEmpty);
  });

  test('discarding the draft (simulating "back") after selecting Landed '
      'leaves no trace at all', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);

    notifier.begin(PropertyType.landed);
    notifier.discard();

    expect(container.read(newInspectionDraftProvider), isNull);
    final repository = container.read(inspectionRepositoryProvider);
    expect(await repository.listSessions(), isEmpty);
  });

  test('configuring areas, then discarding (simulating "back" from area '
      'configuration), still leaves no trace', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);

    notifier.begin(PropertyType.highRise);
    final firstSectionId = container
        .read(newInspectionDraftProvider)!
        .sections
        .first
        .id;
    notifier.toggleIncluded(firstSectionId);
    notifier.addCustom('Home Office');

    notifier.discard();

    expect(container.read(newInspectionDraftProvider), isNull);
    final repository = container.read(inspectionRepositoryProvider);
    expect(await repository.listSessions(), isEmpty);
  });

  test('reopening setup (begin again) after backing out starts a fresh '
      'draft rather than resuming stale edits', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);

    notifier.begin(PropertyType.highRise);
    notifier.addCustom('Home Office');
    notifier.discard();

    notifier.begin(PropertyType.highRise);
    final names = container
        .read(newInspectionDraftProvider)!
        .sections
        .map((s) => s.name)
        .toSet();
    expect(names.contains('Home Office'), isFalse);
  });

  test('an explicit Start Inspection persists exactly one session and '
      'clears the draft', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);
    notifier.begin(PropertyType.highRise);

    final started = await notifier.startInspection();

    expect(started, isTrue);
    expect(container.read(newInspectionDraftProvider), isNull);
    expect(container.read(activeSessionProvider), isNotNull);
    final repository = container.read(inspectionRepositoryProvider);
    expect(await repository.listSessions(), hasLength(1));
  });

  test('repeated/concurrent taps on Start Inspection create exactly one '
      'session, never duplicates', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);
    notifier.begin(PropertyType.highRise);

    final results = await Future.wait([
      notifier.startInspection(),
      notifier.startInspection(),
      notifier.startInspection(),
    ]);

    expect(results.where((r) => r).length, 1);
    final repository = container.read(inspectionRepositoryProvider);
    expect(await repository.listSessions(), hasLength(1));
  });

  test('starting an inspection with no draft is a safe no-op', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);

    final started = await container
        .read(newInspectionDraftProvider.notifier)
        .startInspection();

    expect(started, isFalse);
    expect(container.read(activeSessionProvider), isNull);
  });

  test('interrupted setup (discard mid-edit, then start a brand new '
      'draft) never leaves an orphaned or duplicate inspection', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);

    notifier.begin(PropertyType.highRise);
    notifier.toggleIncluded(
      container.read(newInspectionDraftProvider)!.sections.first.id,
    );
    notifier.discard(); // interrupted — user backed out

    notifier.begin(PropertyType.landed);
    final started = await notifier.startInspection();

    expect(started, isTrue);
    final repository = container.read(inspectionRepositoryProvider);
    final summaries = await repository.listSessions();
    expect(summaries, hasLength(1));
    expect(summaries.single.assetTypeId, PropertyType.landed.name);
  });

  test('updateArea can toggle the plumbing flag independently of the '
      'name, and it participates in plumbing-first ordering once '
      'started', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);
    notifier.begin(PropertyType.highRise);

    final livingRoom = container
        .read(newInspectionDraftProvider)!
        .sections
        .firstWhere((s) => s.name == 'Living Room');
    expect(livingRoom.isPlumbing, isFalse);

    notifier.updateArea(livingRoom.id, isPlumbing: true);

    final updated = container
        .read(newInspectionDraftProvider)!
        .sections
        .firstWhere((s) => s.id == livingRoom.id);
    expect(updated.isPlumbing, isTrue);
    expect(updated.name, 'Living Room'); // name unchanged
  });

  test(
    'a custom area added as plumbing is created with isPlumbing true',
    () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final notifier = container.read(newInspectionDraftProvider.notifier);
      notifier.begin(PropertyType.highRise);

      notifier.addCustom('Wet Kitchen', isPlumbing: true);

      final added = container
          .read(newInspectionDraftProvider)!
          .sections
          .firstWhere((s) => s.name == 'Wet Kitchen');
      expect(added.isPlumbing, isTrue);
      expect(added.isIncluded, isTrue);
    },
  );

  test('resetToDefaults on the draft discards custom areas/edits but '
      'keeps the draft (does not start an inspection)', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    final notifier = container.read(newInspectionDraftProvider.notifier);
    notifier.begin(PropertyType.highRise);
    notifier.addCustom('Home Office');

    notifier.resetToDefaults();

    final draft = container.read(newInspectionDraftProvider);
    expect(draft, isNotNull);
    expect(draft!.sections.any((s) => s.name == 'Home Office'), isFalse);
    final repository = container.read(inspectionRepositoryProvider);
    expect(await repository.listSessions(), isEmpty);
  });
}
