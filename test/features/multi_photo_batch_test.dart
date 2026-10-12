import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/image_picker_evidence_capture_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/finding_job_gate.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// Scalable multi-photo capture (2026-10-12): no 3-photo product limit,
/// one photo = one finding, keyboard stays open while moving between
/// photos, and uploads/AI start progressively with bounded concurrency.

class _TrackingBilling extends FakeBillingService {
  _TrackingBilling() : super(initialBalanceTokens: 900000000);

  final List<String> started = [];
  int running = 0;
  int maxRunning = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    started.add(request.findingId);
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return await super.analyseFinding(
        request: request,
        aiLevel: aiLevel,
        idempotencyKey: idempotencyKey,
      );
    } finally {
      running--;
    }
  }
}

Future<(ProviderContainer, FakeEvidenceCaptureService)> _start({
  required int pick,
  FakeBillingService? billing,
}) async {
  final capture = FakeEvidenceCaptureService()..galleryPickCount = pick;
  final container = ProviderContainer(
    overrides: testOverrides(captureService: capture, billingService: billing),
  );
  addTearDown(container.dispose);
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  return (container, capture);
}

String _firstArea(ProviderContainer c) =>
    c.read(inspectionQueueProvider).first.id;

void main() {
  group('no 3-photo product limit', () {
    test('the technical ceiling is generous, configurable and not 3', () {
      expect(kMaxGalleryPhotosPerSelection, greaterThanOrEqualTo(50));
    });

    test('12 selected photos create 12 independent draft findings, each '
        'with its own note, photo and ids — nothing merged, nothing '
        'dropped, no duplicates', () async {
      final (container, capture) = await _start(pick: 12);
      final notifier = container.read(activeSessionProvider.notifier);
      final photos = await notifier.captureFindingPhotos(
        source: EvidenceSource.gallery,
      );
      expect(photos, hasLength(12));
      expect(capture.captureCount, 12);

      final notes = [for (var i = 0; i < 12; i++) 'Note ${i + 1}'];
      final saved = notifier.saveCameraFindings(
        sectionId: _firstArea(container),
        photos: photos,
        notes: notes,
      );
      expect(saved, hasLength(12));
      expect(saved.map((f) => f.description).toList(), notes);
      expect(saved.map((f) => f.id).toSet(), hasLength(12));
      expect(saved.map((f) => f.evidence.single.id).toSet(), hasLength(12));
      expect(
        saved.map((f) => f.evidence.single.filePath).toSet(),
        hasLength(12),
      );
      expect(saved.every((f) => f.evidence.length == 1), isTrue);
      expect(
        container.read(activeSessionProvider)!.findings,
        hasLength(12),
        reason: 'no duplicate findings',
      );
    });

    test('100 photos in one selection are accepted whole (no silent '
        'truncation)', () async {
      final (container, capture) = await _start(pick: 100);
      final photos = await container
          .read(activeSessionProvider.notifier)
          .captureFindingPhotos(source: EvidenceSource.gallery);
      expect(photos, hasLength(100));
      expect(capture.captureCount, 100);
    });

    test('a selection over the ceiling is refused whole with a clear '
        'message — never trimmed', () {
      expect(() => ensureWithinGalleryCeiling(100, 100), returnsNormally);
      expect(
        () => ensureWithinGalleryCeiling(101, 100),
        throwsA(
          isA<EvidenceCaptureException>().having(
            (e) => e.message,
            'message',
            allOf(contains('up to 100'), contains('picked 101')),
          ),
        ),
      );
    });
  });

  group('bounded, progressive upload / AI queue', () {
    test('FindingJobGate runs at most N jobs, FIFO, handing slots on as '
        'jobs finish', () async {
      final gate = FindingJobGate(maxConcurrent: 3);
      final order = <int>[];
      final releases = <int, Completer<void>>{};
      var running = 0;
      var maxRunning = 0;
      final done = <Future<void>>[];
      for (var i = 0; i < 8; i++) {
        releases[i] = Completer<void>();
        done.add(() async {
          await gate.acquire();
          order.add(i);
          running++;
          if (running > maxRunning) maxRunning = running;
          await releases[i]!.future;
          running--;
          gate.release();
        }());
      }
      await Future<void>.delayed(Duration.zero);
      expect(order, [0, 1, 2], reason: 'only 3 start; the rest wait');
      expect(gate.waiting, 5);

      releases[0]!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, [0, 1, 2, 3], reason: 'a slot frees → the next starts');

      for (var i = 1; i < 8; i++) {
        releases[i]!.complete();
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(done);
      expect(order, [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(maxRunning, 3);
      expect(gate.active, 0);
      expect(gate.waiting, 0);
    });

    test('12 saved findings all get classified, one AI job each, with at '
        'most 3 in flight at once, and saving never waits for them', () async {
      final billing = _TrackingBilling();
      final (container, _) = await _start(pick: 12, billing: billing);
      final notifier = container.read(activeSessionProvider.notifier);
      final photos = await notifier.captureFindingPhotos(
        source: EvidenceSource.gallery,
      );
      final stopwatch = Stopwatch()..start();
      final saved = notifier.saveCameraFindings(
        sectionId: _firstArea(container),
        photos: photos,
        notes: [for (var i = 0; i < 12; i++) 'Hollow wall tile $i'],
      );
      // Returned synchronously: the UI is never blocked by uploads or AI.
      expect(saved, hasLength(12));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(billing.started.length, lessThan(12), reason: 'progressive');

      for (var i = 0; i < 100 && billing.started.toSet().length < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(billing.started.toSet(), saved.map((f) => f.id).toSet());
      expect(
        billing.started,
        hasLength(12),
        reason: 'exactly one AI job per finding — no duplicates',
      );
      expect(billing.maxRunning, lessThanOrEqualTo(kMaxConcurrentFindingJobs));
      expect(
        container.read(activeSessionProvider)!.aiSuggestions,
        hasLength(12),
      );
    });
  });

  group('keyboard stays open while switching photos', () {
    Future<ProviderContainer> pumpSheet(WidgetTester tester, int pick) async {
      late ProviderContainer container;
      await tester.runAsync(() async {
        (container, _) = await _start(pick: pick);
      });
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AreaInspectionScreen(sectionId: _firstArea(container)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Defect Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      return container;
    }

    Finder noteField() => find.byKey(const ValueKey('preview-note'));
    bool noteHasFocus(WidgetTester tester) =>
        tester.widget<TextField>(noteField()).focusNode!.hasFocus;

    testWidgets('tapping thumbnails, Next and Previous keeps the note field '
        'focused and the keyboard visible; each photo keeps its own note', (
      tester,
    ) async {
      await pumpSheet(tester, 12);
      expect(find.textContaining('Photo 1 of 12'), findsOneWidget);
      expect(find.text('Upload 12 Findings'), findsOneWidget);

      await tester.tap(noteField());
      await tester.pump();
      await tester.enterText(noteField(), 'wal por skim');
      expect(noteHasFocus(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const ValueKey('preview-thumb-1')));
      await tester.pump();
      expect(noteHasFocus(tester), isTrue, reason: 'thumb tap keeps focus');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.textContaining('Photo 2 of 12'), findsOneWidget);
      expect(find.text('wal por skim'), findsNothing, reason: 'own note');

      await tester.enterText(noteField(), 'frem dent');
      await tester.tap(find.byKey(const ValueKey('preview-next')));
      await tester.pump();
      expect(noteHasFocus(tester), isTrue, reason: 'Next keeps focus');
      expect(find.textContaining('Photo 3 of 12'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preview-previous')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('preview-previous')));
      await tester.pump();
      expect(noteHasFocus(tester), isTrue, reason: 'Previous keeps focus');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('wal por skim'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preview-thumb-1')));
      await tester.pump();
      expect(find.text('frem dent'), findsOneWidget, reason: 'remembered');
    });

    testWidgets('the keyboard is dismissed by Done', (tester) async {
      await pumpSheet(tester, 3);
      await tester.tap(noteField());
      await tester.pump();
      expect(noteHasFocus(tester), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(noteHasFocus(tester), isFalse);
    });

    testWidgets('the keyboard is dismissed by tapping outside the input '
        'area', (tester) async {
      await pumpSheet(tester, 3);
      await tester.tap(noteField());
      await tester.pump();
      expect(noteHasFocus(tester), isTrue);

      // Tapping the batch controls is "inside" — focus stays …
      await tester.tap(find.byKey(const ValueKey('preview-photo-count')));
      await tester.pump();
      expect(noteHasFocus(tester), isTrue);

      // … but tapping the photo itself (outside the input area) closes it.
      await tester.tap(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      await tester.pump();
      expect(noteHasFocus(tester), isFalse);
    });

    testWidgets('memory: previews and thumbnails are decoded at reduced '
        'size from file paths, never as full-resolution originals', (
      tester,
    ) async {
      await pumpSheet(tester, 12);
      final images = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Image),
            ),
          )
          .toList();
      expect(images, isNotEmpty);
      for (final image in images) {
        expect(
          image.image,
          isA<ResizeImage>(),
          reason: 'bounded decode (cacheWidth), not the full original',
        );
      }
    });

    testWidgets('a batch saves one finding per photo with its own note', (
      tester,
    ) async {
      final container = await pumpSheet(tester, 4);
      Future<void> typeFor(int i, String text) async {
        await tester.tap(find.byKey(ValueKey('preview-thumb-$i')));
        await tester.pump();
        await tester.enterText(noteField(), text);
      }

      for (var i = 0; i < 4; i++) {
        await typeFor(i, 'Defect ${i + 1}');
      }
      await tester.tap(find.text('Upload 4 Findings'));
      await tester.pumpAndSettle();

      final findings = container.read(activeSessionProvider)!.findings;
      expect(findings.map((f) => f.description).toSet(), {
        'Defect 1',
        'Defect 2',
        'Defect 3',
        'Defect 4',
      });
      expect(findings, hasLength(4));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
