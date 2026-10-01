import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// Gallery multi-select: up to 3 photos of one defect in a single pick,
/// all attached to ONE finding (2026-10-01 pass). Camera stays a single
/// shot.
void main() {
  Future<(ProviderContainer, FakeEvidenceCaptureService)> start({
    int galleryPickCount = 3,
  }) async {
    final capture = FakeEvidenceCaptureService()
      ..galleryPickCount = galleryPickCount;
    final container = ProviderContainer(
      overrides: testOverrides(captureService: capture),
    );
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    return (container, capture);
  }

  test('10. one gallery pick of 3 photos creates ONE finding holding all '
      '3, persisted', () async {
    final (container, _) = await start();
    final notifier = container.read(activeSessionProvider.notifier);
    final photos = await notifier.captureFindingPhotos(
      source: EvidenceSource.gallery,
    );
    expect(photos, hasLength(3));
    expect(photos.map((p) => p.pendingFindingId).toSet(), hasLength(1));

    final finding = notifier.saveCameraFinding(
      sectionId: container.read(inspectionQueueProvider).first.id,
      photo: photos.first,
      additionalPhotos: photos.skip(1).toList(),
      note: 'Hollow tile',
    );

    final session = container.read(activeSessionProvider)!;
    expect(session.findings, hasLength(1));
    expect(finding.evidence, hasLength(3));
    expect(finding.evidence.map((e) => e.id).toSet(), hasLength(3));
    expect(
      finding.evidence.map((e) => e.filePath),
      photos.map((p) => p.filePath),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final reloaded = await container
        .read(inspectionRepositoryProvider)
        .loadSession(session.id);
    expect(reloaded!.findings.single.evidence, hasLength(3));
  });

  test('11. the gallery pick is capped at 3 photos', () async {
    final (container, capture) = await start(galleryPickCount: 7);
    final photos = await container
        .read(activeSessionProvider.notifier)
        .captureFindingPhotos(source: EvidenceSource.gallery);
    expect(photos, hasLength(3));
    expect(capture.captureCount, 3);
  });

  test('12. the camera stays a single shot', () async {
    final (container, _) = await start();
    final photos = await container
        .read(activeSessionProvider.notifier)
        .captureFindingPhotos(source: EvidenceSource.camera);
    expect(photos, hasLength(1));
    expect(photos.single.source, EvidenceSource.camera);
  });

  test('13. a 1-photo gallery pick still works exactly as before', () async {
    final (container, _) = await start(galleryPickCount: 1);
    final notifier = container.read(activeSessionProvider.notifier);
    final photos = await notifier.captureFindingPhotos(
      source: EvidenceSource.gallery,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: container.read(inspectionQueueProvider).first.id,
      photo: photos.single,
      note: 'Crack',
    );
    expect(finding.evidence, hasLength(1));
  });

  test('14. Add angle still works on a multi-photo finding, and the report '
      'carries every photo', () async {
    final (container, capture) = await start(galleryPickCount: 2);
    final notifier = container.read(activeSessionProvider.notifier);
    final photos = await notifier.captureFindingPhotos(
      source: EvidenceSource.gallery,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: container.read(inspectionQueueProvider).first.id,
      photo: photos.first,
      additionalPhotos: photos.skip(1).toList(),
      note: 'Hollow tile',
    );
    capture.galleryPickCount = 1;
    await notifier.addEvidence(
      findingId: finding.id,
      source: EvidenceSource.camera,
    );
    final session = container.read(activeSessionProvider)!;
    expect(session.findings.single.evidence, hasLength(3));

    final model = buildReportModel(
      session: session,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 10, 1),
    );
    final reported = model.areas.expand((a) => a.findings).single;
    expect(reported.evidenceFilePaths, hasLength(3));
  });

  testWidgets('15 + 16. the preview shows a thumbnail per photo, removes one, '
      'never removes the last, and saves the rest on one finding', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      (container, _) = await start();
    });
    final queue = container.read(inspectionQueueProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AreaInspectionScreen(sectionId: queue.first.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take Defect Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('3 photos of this defect'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('preview-thumb-$i')), findsOneWidget);
    }
    // No AI level choice at upload — that lives only in Profile.
    expect(find.text('Expert'), findsNothing);
    expect(find.text('Fast'), findsNothing);

    Future<void> removeFirst() async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('preview-thumb-0')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
    }

    await removeFirst();
    expect(find.text('2 photos of this defect'), findsOneWidget);
    await removeFirst();
    // One left: the strip (and every remove button) is gone.
    expect(find.byKey(const ValueKey('preview-thumb-0')), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'Cracked tile',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Save Finding'),
      ),
    );
    await tester.pumpAndSettle();

    final finding = container.read(activeSessionProvider)!.findings.single;
    expect(finding.evidence, hasLength(1));
    // The photo kept is the last one picked.
    expect(finding.evidence.single.filePath, endsWith('/3.jpg'));
  });
}
