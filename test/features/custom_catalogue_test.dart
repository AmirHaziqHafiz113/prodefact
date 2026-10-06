import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/custom_catalogue_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/test_repository.dart';

/// Company custom catalogue: added by the inspector, searchable and
/// selectable at once, saved to (and restorable from) their own account
/// only, and never touching the ProDefact master catalogue.

const _floorTrapArgs = (
  element: 'Floor',
  component: 'Floor Trap',
  description: 'Floor trap cover is loose',
  action: 'Re-fix the floor trap cover securely.',
);

Future<AddCustomDefectResult> _addFloorTrap(ProviderContainer c) => c
    .read(customCatalogueProvider.notifier)
    .add(
      element: _floorTrapArgs.element,
      component: _floorTrapArgs.component,
      description: _floorTrapArgs.description,
      correctiveAction: _floorTrapArgs.action,
    );

ProviderContainer _container({
  required FakeAuthService auth,
  required FakeCloudInspectionRepository cloud,
}) {
  final c = ProviderContainer(
    overrides: testOverridesWithSync(authService: auth, cloudRepository: cloud),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final masterCount = DefectCatalogue.instance.masterEntries.length;

  tearDown(() => DefectCatalogue.instance.replaceCustomEntries(const []));

  group('validation', () {
    final existing = DefectCatalogue.instance.entries;

    test('blank fields are refused (whitespace-only counts as blank)', () {
      CustomDefectProblem? problemOf({
        String element = 'Floor',
        String component = 'Floor Trap',
        String description = 'Loose cover',
        String action = 'Re-fix',
      }) => validateCustomDefect(
        element: element,
        component: component,
        description: description,
        correctiveAction: action,
        existing: existing,
      ).problem;

      expect(problemOf(element: '  '), CustomDefectProblem.blankElement);
      expect(problemOf(component: ''), CustomDefectProblem.blankComponent);
      expect(
        problemOf(description: ' \n '),
        CustomDefectProblem.blankDescription,
      );
      expect(problemOf(action: ''), CustomDefectProblem.blankCorrectiveAction);
      expect(problemOf(), isNull);
    });

    test('text is trimmed, whitespace collapsed and markup characters '
        'stripped', () {
      final v = validateCustomDefect(
        element: '  Floor ',
        component: 'Floor   Trap',
        description: '<script>alert(1)</script> Cover   loose',
        correctiveAction: 'Fix <b>it</b>',
        existing: existing,
      );
      expect(v.element, 'Floor');
      expect(v.component, 'Floor Trap');
      expect(v.description, 'scriptalert(1)/script Cover loose');
      expect(v.correctiveAction, 'Fix bit/b');
      expect(v.description, isNot(contains('<')));
    });

    test('an exact duplicate of a master entry is refused (case/space '
        'insensitive)', () {
      final master = existing.first;
      final v = validateCustomDefect(
        element: ' ${master.mainElementName.toUpperCase()} ',
        component: master.componentName,
        description: master.defectDescription.toLowerCase(),
        correctiveAction: 'x',
        existing: existing,
      );
      expect(v.problem, CustomDefectProblem.exactDuplicate);
    });

    test('a near-duplicate is flagged but allowed', () {
      final master = existing.firstWhere(
        (e) => e.defectDescription.split(' ').length >= 5,
      );
      final v = validateCustomDefect(
        element: master.mainElementName,
        component: master.componentName,
        description: '${master.defectDescription}.',
        correctiveAction: 'x',
        existing: existing,
      );
      expect(v.isValid, isTrue);
      expect(v.nearDuplicate?.id, master.id);
    });

    test(
      'master element/component ids are reused; new names get custom ids',
      () {
        final master = existing.first;
        final reused = resolveCustomIds(
          element: master.mainElementName,
          component: master.componentName,
          existing: existing,
        );
        expect(reused.elementId, master.mainElementId);
        expect(reused.componentId, master.componentId);
        final fresh = resolveCustomIds(
          element: 'Floor',
          component: 'Floor Trap',
          existing: existing,
        );
        expect(fresh.componentId, startsWith('custom_component.'));
      },
    );
  });

  group('overlay', () {
    test('custom entries are searchable and valid ids at once; the master '
        'catalogue is unchanged; clearing removes them', () {
      final entry = CustomDefect(
        id: 'custom.1',
        ownerUid: 'u',
        elementId: 'custom_element.floor',
        elementName: 'Floor',
        componentId: 'custom_component.floor.floor_trap',
        componentName: 'Floor Trap',
        defectDescription: 'Floor trap cover is loose',
        correctiveAction: 'Re-fix.',
        createdAt: DateTime(2026, 10, 6),
      ).toEntry();
      DefectCatalogue.instance.replaceCustomEntries([entry]);

      expect(DefectCatalogue.instance.isValidEntryId('custom.1'), isTrue);
      expect(DefectCatalogue.instance.masterEntries.length, masterCount);
      expect(DefectCatalogue.instance.entries.length, masterCount + 1);
      final ranked = rankRelatedDefects(const RelatedDefectContext());
      final found = searchRelatedDefects(ranked: ranked, query: 'floor trap');
      expect(found.map((e) => e.id), contains('custom.1'));
      // "flo trap" (shorthand) and the BM phrase reach it too.
      expect(
        searchRelatedDefects(
          ranked: ranked,
          query: 'perangkap lantai',
        ).map((e) => e.id),
        contains('custom.1'),
      );

      DefectCatalogue.instance.replaceCustomEntries(const []);
      expect(DefectCatalogue.instance.isValidEntryId('custom.1'), isFalse);
      expect(DefectCatalogue.instance.entries.length, masterCount);
    });

    test('a custom entry can never shadow a master id', () {
      final master = DefectCatalogue.instance.masterEntries.first;
      DefectCatalogue.instance.replaceCustomEntries([
        DefectCatalogueEntry(
          id: master.id,
          mainElementId: 'x',
          mainElementName: 'X',
          componentId: 'x',
          componentName: 'X',
          defectId: master.id,
          defectDescription: 'hijacked',
          correctiveAction: 'hijacked',
          isCustom: true,
        ),
      ]);
      expect(
        DefectCatalogue.instance.byId(master.id)!.defectDescription,
        master.defectDescription,
      );
    });
  });

  group('provider: company scoping, persistence and cloud restore', () {
    test('adding saves under the owner, is selectable at once, survives a '
        'fresh device (cloud restore), and Company B never sees it', () async {
      final cloud = FakeCloudInspectionRepository();
      final authA = FakeAuthService(
        initialUser: const AuthUser(uid: 'company-a'),
      );
      final a = _container(auth: authA, cloud: cloud);
      await a.read(customCatalogueProvider.future);

      final result = await _addFloorTrap(a);
      expect(result.saved, isTrue);
      expect(DefectCatalogue.instance.isValidEntryId(result.entry!.id), isTrue);
      expect(result.entry!.isCustom, isTrue);
      expect(result.entry!.correctiveAction, _floorTrapArgs.action);
      expect(cloud.pushedCustomDefects['company-a']!.keys, [result.entry!.id]);
      expect(cloud.pushedCustomDefects.containsKey('company-b'), isFalse);

      // An exact duplicate is refused and nothing more is pushed.
      final again = await _addFloorTrap(a);
      expect(again.saved, isFalse);
      expect(again.validation!.problem, CustomDefectProblem.exactDuplicate);
      expect(cloud.pushedCustomDefects['company-a']!.length, 1);

      // Fresh device: new empty local database, same account.
      DefectCatalogue.instance.replaceCustomEntries(const []);
      final fresh = _container(
        auth: FakeAuthService(initialUser: const AuthUser(uid: 'company-a')),
        cloud: cloud,
      );
      final restored = await fresh.read(customCatalogueProvider.future);
      expect(restored.map((d) => d.defectDescription), [
        _floorTrapArgs.description,
      ]);
      expect(DefectCatalogue.instance.byId(result.entry!.id), isNotNull);

      // Company B on the same cloud sees nothing of A's, and A's entry is
      // gone from the shared overlay.
      final b = _container(
        auth: FakeAuthService(initialUser: const AuthUser(uid: 'company-b')),
        cloud: cloud,
      );
      expect(await b.read(customCatalogueProvider.future), isEmpty);
      expect(DefectCatalogue.instance.byId(result.entry!.id), isNull);
      expect(DefectCatalogue.instance.entries.length, masterCount);
    });

    test('signing out clears the overlay; archiving hides the entry', () async {
      final cloud = FakeCloudInspectionRepository();
      final auth = FakeAuthService(initialUser: const AuthUser(uid: 'co'));
      final c = _container(auth: auth, cloud: cloud);
      await c.read(customCatalogueProvider.future);
      final entry = (await _addFloorTrap(c)).entry!;

      await c.read(customCatalogueProvider.notifier).archive(entry.id);
      expect(DefectCatalogue.instance.byId(entry.id), isNull);
      expect(cloud.pushedCustomDefects['co']![entry.id]!.archived, isTrue);

      final entry2 =
          (await c
                  .read(customCatalogueProvider.notifier)
                  .add(
                    element: 'Floor',
                    component: 'Floor Trap',
                    description: 'Floor trap blocked',
                    correctiveAction: 'Clear it.',
                  ))
              .entry!;
      expect(DefectCatalogue.instance.byId(entry2.id), isNotNull);
      // Keep the provider watched, as the app root does.
      c.listen(customCatalogueProvider, (_, _) {});
      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.read(customCatalogueProvider.future);
      expect(DefectCatalogue.instance.byId(entry2.id), isNull);
    });

    test('a custom defect can be chosen for a finding and reaches the '
        'report with its own corrective action', () async {
      final cloud = FakeCloudInspectionRepository();
      final c = _container(
        auth: FakeAuthService(initialUser: const AuthUser(uid: 'co')),
        cloud: cloud,
      );
      await c.read(customCatalogueProvider.future);
      final entry = (await _addFloorTrap(c)).entry!;

      final notifier = c.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      final finding = notifier.saveCameraFinding(
        sectionId: c.read(inspectionQueueProvider).first.id,
        photo: photo!,
        note: 'floor trap loose',
      );
      // Wait out the (fake) analysis, then choose the custom defect.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (aiFindingStatusIsInFlight(
        c.read(activeSessionProvider)!.findings.single.aiStatus,
      )) {
        if (DateTime.now().isAfter(deadline)) fail('analysis timed out');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(notifier.selectDefectForFinding(finding.id, entry.id), isTrue);

      final session = c.read(activeSessionProvider)!;
      final report = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 10, 6),
      ).areas.expand((a) => a.findings).single;
      expect(report.componentName, 'Floor Trap');
      expect(report.recommendation, _floorTrapArgs.action);
      expect(ReportReadiness.of(session).isReady, isTrue);
    });
  });
}
