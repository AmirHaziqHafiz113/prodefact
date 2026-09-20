import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// QA/QC item 10: evidence capture is no longer camera-only. Both
/// sources go through the exact same `EvidenceCaptureService.
/// captureImage` pipeline (same normalization/local persistence/
/// evidence id/eventual upload — see `ImagePickerEvidenceCaptureService`
/// and its fake here), so this proves the *choice* is exposed and that
/// gallery evidence is indistinguishable from camera evidence once
/// captured, not a separate code path.
void main() {
  test('camera evidence still works: captureFindingPhoto with '
      'EvidenceSource.camera produces a normal finding', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    expect(photo, isNotNull);
    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );

    expect(finding.evidence.single.source, EvidenceSource.camera);
  });

  test('gallery evidence enters the exact same capture/persistence path '
      'as camera evidence — same evidence shape, same finding creation, '
      'same AI eligibility', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.gallery,
    );
    expect(photo, isNotNull);
    expect(photo!.source, EvidenceSource.gallery);

    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo,
      note: 'Water stain',
    );

    expect(finding.evidence, hasLength(1));
    expect(finding.evidence.single.source, EvidenceSource.gallery);
    // Same eligibility as camera evidence — nothing about the finding
    // itself records or special-cases where the photo came from.
    expect(finding.isAiEligible, isTrue);
    expect(finding.aiStatus, isNot(AiFindingStatus.notQueued));

    final reloaded = await container
        .read(inspectionRepositoryProvider)
        .loadSession(container.read(activeSessionProvider)!.id);
    final persistedEvidence = reloaded!.findings.single.evidence.single;
    expect(persistedEvidence.source, EvidenceSource.gallery);
    expect(persistedEvidence.filePath, photo.filePath);
  });

  test('"Add another photo" via the gallery attaches a second photo '
      'identically to a camera one', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );

    await notifier.addEvidence(
      findingId: finding.id,
      source: EvidenceSource.gallery,
    );

    final updated = container
        .read(activeSessionProvider)!
        .findings
        .single;
    expect(updated.evidence, hasLength(2));
    expect(updated.evidence.last.source, EvidenceSource.gallery);
  });

  test('cancelling the gallery picker (source returns null) never '
      'creates a finding or any evidence', () async {
    final captureService = FakeEvidenceCaptureService(cancelNextPick: true);
    final container = ProviderContainer(
      overrides: testOverrides(captureService: captureService),
    );
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.gallery,
    );

    expect(photo, isNull);
    expect(container.read(activeSessionProvider)!.findings, isEmpty);
  });

  testWidgets(
    'tapping "Take Defect Photo" offers a Camera / Choose from Gallery '
    'choice, and picking Gallery saves a finding just like Camera does',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(activeSessionProvider.notifier)
          .startNew(PropertyType.highRise);
      final queue = container.read(inspectionQueueProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: AreaInspectionScreen(sectionId: queue.first.id)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Defect Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

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
      expect(finding.evidence.single.source, EvidenceSource.gallery);
    },
  );
}
