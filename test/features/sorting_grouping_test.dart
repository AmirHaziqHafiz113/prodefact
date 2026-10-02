import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// Finding order (default Status: finished, analysing, waiting, failed;
/// newest first within each) and the visual group for one multi-photo
/// gallery pick — each photo still its own finding.

Finding _f(String id, AiFindingStatus status, int minute, {String? batch}) =>
    Finding(
      id: id,
      sectionId: 's',
      createdAt: DateTime(2026, 10, 2, 9, minute),
      updatedAt: DateTime(2026, 10, 2, 9, minute),
      aiStatus: status,
      captureBatchId: batch,
    );

List<String> _ids(List<FindingDisplayUnit> units) => [
  for (final u in units)
    for (final f in u.findings) f.id,
];

void main() {
  final findings = [
    _f('failed_old', AiFindingStatus.failed, 1),
    _f('queued', AiFindingStatus.queued, 2),
    _f('done_old', AiFindingStatus.completed, 3),
    _f('analysing', AiFindingStatus.analyzing, 4),
    _f('done_new', AiFindingStatus.completed, 5),
    _f('review', AiFindingStatus.needsReview, 6),
    _f('uploading', AiFindingStatus.uploading, 7),
  ];

  test('6-9. the default sort is Status: finished, then analysing, then '
      'waiting, then failed — newest first within each', () {
    expect(_ids(orderFindings(findings)), [
      'review',
      'done_new',
      'done_old',
      'uploading',
      'analysing',
      'queued',
      'failed_old',
    ]);
  });

  test('10 + 11. Newest and Oldest order by capture time; sorting never '
      'changes the findings', () {
    final before = [...findings];
    expect(_ids(orderFindings(findings, sort: FindingSort.newest)), [
      'uploading',
      'review',
      'done_new',
      'analysing',
      'done_old',
      'queued',
      'failed_old',
    ]);
    expect(
      _ids(orderFindings(findings, sort: FindingSort.oldest)).first,
      'failed_old',
    );
    expect(findings, before);
  });

  test('a gallery batch stays together as one unit, placed by its best '
      'member', () {
    final units = orderFindings([
      _f('single', AiFindingStatus.completed, 1),
      _f('b1', AiFindingStatus.queued, 2, batch: 'batch_x'),
      _f('b2', AiFindingStatus.completed, 3, batch: 'batch_x'),
      _f('b3', AiFindingStatus.failed, 4, batch: 'batch_x'),
    ]);
    expect(units, hasLength(2));
    expect(units.first.isGroup, isTrue);
    expect(units.first.findings.map((f) => f.id), ['b2', 'b1', 'b3']);
    expect(units.last.findings.single.id, 'single');
  });

  test('12-14. three gallery photos save as three findings sharing one '
      'batch id, each with its own id and photo', () async {
    final capture = FakeEvidenceCaptureService()..galleryPickCount = 3;
    final container = ProviderContainer(
      overrides: testOverrides(captureService: capture),
    );
    addTearDown(container.dispose);
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    final photos = await notifier.captureFindingPhotos(
      source: EvidenceSource.gallery,
    );
    final saved = notifier.saveCameraFindings(
      sectionId: container.read(inspectionQueueProvider).first.id,
      photos: photos,
      notes: ['A', 'B', 'C'],
    );
    expect(saved, hasLength(3));
    expect(saved.map((f) => f.id).toSet(), hasLength(3));
    expect(saved.map((f) => f.captureBatchId).toSet(), hasLength(1));
    expect(saved.first.captureBatchId, isNotNull);
    expect(saved.every((f) => f.evidence.length == 1), isTrue);

    // A single capture is not a batch.
    final single = notifier.saveCameraFindings(
      sectionId: container.read(inspectionQueueProvider).first.id,
      photos: [
        (await notifier.captureFindingPhoto(source: EvidenceSource.camera))!,
      ],
    );
    expect(single.single.captureBatchId, isNull);
  });

  testWidgets('15 + 16. the area shows one bordered group for the batch, '
      'each finding inside with its own note and status, and a Status / '
      'Newest / Oldest sort control', (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      final capture = FakeEvidenceCaptureService()..galleryPickCount = 3;
      container = ProviderContainer(
        overrides: testOverrides(captureService: capture),
      );
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      final photos = await notifier.captureFindingPhotos(
        source: EvidenceSource.gallery,
      );
      notifier.saveCameraFindings(
        sectionId: container.read(inspectionQueueProvider).first.id,
        photos: photos,
        notes: ['Front view', 'Side view', 'Close-up'],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    addTearDown(container.dispose);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AreaInspectionScreen(
            sectionId: container.read(inspectionQueueProvider).first.id,
          ),
        ),
      ),
    );
    await tester.pump();

    final batchId = container
        .read(activeSessionProvider)!
        .findings
        .first
        .captureBatchId;
    final group = find.byKey(ValueKey('capture-batch-$batchId'));
    expect(group, findsOneWidget);
    for (final note in ['Front view', 'Side view', 'Close-up']) {
      expect(
        find.descendant(of: group, matching: find.text(note)),
        findsOneWidget,
      );
    }
    expect(find.text('Uploaded together · 3 findings'), findsOneWidget);
    expect(find.byKey(const ValueKey('finding-sort')), findsOneWidget);
    for (final label in ['Status', 'Newest', 'Oldest']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
