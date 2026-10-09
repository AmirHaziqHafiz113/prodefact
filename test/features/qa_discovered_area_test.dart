import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/features/home_inspection/config/home_inspection_config.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/areas_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../support/fake_area_candidate_service.dart';
import '../support/test_repository.dart';

/// Checkpoint 3 of the QA/QC closure pass: newly discovered areas
/// (QA #12).

Future<(ProviderContainer, DriftInspectionRepository, FakeAreaCandidateService)>
_started({bool offline = false, List<String> approved = const []}) async {
  final repo = createInMemoryRepository();
  final service = FakeAreaCandidateService(approved: approved)
    ..offline = offline;
  final container = ProviderContainer(
    overrides: testOverrides(repository: repo, areaCandidateService: service),
  );
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  return (container, repo, service);
}

void main() {
  test('a discovered area joins the current inspection immediately, is '
      'saved, and can hold findings that reach the report', () async {
    final (container, repo, _) = await _started();
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);

    final area = notifier.addDiscoveredArea('Laundry Loft')!;
    expect(
      container.read(inspectionQueueProvider).map((s) => s.name),
      contains('Laundry Loft'),
    );

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: area.id,
      photo: photo!,
      note: 'Hollow tile',
    );
    await pumpEventQueue();

    final sessionId = container.read(activeSessionProvider)!.id;
    final stored = (await repo.loadSession(sessionId))!;
    expect(stored.sections.map((s) => s.name), contains('Laundry Loft'));
    expect(stored.findings.single.sectionId, area.id);

    final model = buildReportModel(
      session: stored,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 9, 25),
    );
    expect(model.areas.map((a) => a.name), ['Laundry Loft']);
  });

  test('the global suggested-area catalogue is never changed by a '
      'discovery', () async {
    final (container, _, _) = await _started();
    addTearDown(container.dispose);
    final before = HomeInspectionConfig.defaultSectionsFor(
      PropertyType.highRise,
    ).map((s) => s.name).toList();

    container
        .read(activeSessionProvider.notifier)
        .addDiscoveredArea('Laundry Loft');
    await pumpEventQueue();

    final after = HomeInspectionConfig.defaultSectionsFor(PropertyType.highRise)
        .map((s) => s.name)
        .toList();
    expect(after, before);
    expect(after, isNot(contains('Laundry Loft')));

    // A new inspection starts from the unchanged suggestions.
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    expect(
      container.read(inspectionQueueProvider).map((s) => s.name),
      isNot(contains('Laundry Loft')),
    );
  });

  test('offline, the candidate is stored on the device with its raw name, '
      'and is delivered once the connection allows', () async {
    final (container, repo, service) = await _started(offline: true);
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);

    notifier.addDiscoveredArea('  Laundry   Loft ');
    await pumpEventQueue();

    final pending = await repo.pendingAreaCandidates();
    expect(pending.single.rawName, 'Laundry Loft');
    expect(pending.single.normalizedName, 'laundry loft');
    expect(pending.single.propertyType, PropertyType.highRise.name);
    expect(service.submitted, isEmpty);
    // The area is usable regardless.
    expect(
      container.read(inspectionQueueProvider).map((s) => s.name),
      contains('Laundry Loft'),
    );

    service.offline = false;
    await notifier.flushAreaCandidates();

    expect(service.submitted.single.rawName, 'Laundry Loft');
    expect(await repo.pendingAreaCandidates(), isEmpty);

    // Nothing is sent twice.
    await notifier.flushAreaCandidates();
    expect(service.submitted, hasLength(1));
  });

  test('areas added during setup are recorded as candidates when the '
      'inspection starts', () async {
    final repo = createInMemoryRepository();
    final service = FakeAreaCandidateService();
    final container = ProviderContainer(
      overrides: testOverrides(repository: repo, areaCandidateService: service),
    );
    addTearDown(container.dispose);

    await container
        .read(activeSessionProvider.notifier)
        .startNew(
          PropertyType.highRise,
          initialSections: [
            ...HomeInspectionConfig.defaultSectionsFor(PropertyType.highRise),
            HomeInspectionConfig.customSection('Bilik Stor'),
          ],
        );
    await pumpEventQueue();

    expect(service.submitted.map((c) => c.rawName), ['Bilik Stor']);
  });

  testWidgets('"Add Newly Discovered Area" on the inspection screen adds the '
      'area to the list at once, with approved names as quick picks', (
    tester,
  ) async {
    final (container, _, _) = await _started(approved: ['Laundry Loft']);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AreasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Newly Discovered Area'));
    await tester.pumpAndSettle();
    expect(find.text('Add newly discovered area'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Laundry Loft'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Area'));
    await tester.pumpAndSettle();

    expect(find.text('Laundry Loft'), findsOneWidget);
    expect(find.text('Laundry Loft added to this inspection'), findsOneWidget);
  });

  test('existing saved custom areas still load after the v13 upgrade, and '
      'the candidate queue exists', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('qa_areas');
    addTearDown(() => dir.delete(recursive: true));
    final dbFile = File('${dir.path}/v12.sqlite');

    final seedDb = AppDatabase(NativeDatabase(dbFile));
    final seedRepo = DriftInspectionRepository(seedDb);
    final session = await seedRepo.createSession(
      industry: Industry.homeInspection,
      assetTypeId: PropertyType.highRise.name,
      initialSections: [
        ...HomeInspectionConfig.defaultSectionsFor(PropertyType.highRise),
        HomeInspectionConfig.customSection('Laundry Loft'),
      ],
    );
    await seedDb.close();

    // v13 only added area_candidate_rows: drop it to get a true v12 file.
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('DROP TABLE area_candidate_rows');
    raw.execute('PRAGMA user_version = 12');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    final repo = DriftInspectionRepository(db);
    final loaded = (await repo.loadSession(session.id))!;
    expect(loaded.sections.map((s) => s.name), contains('Laundry Loft'));
    expect(await repo.pendingAreaCandidates(), isEmpty);
  });
}
