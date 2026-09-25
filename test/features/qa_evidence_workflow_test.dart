import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/photo_annotation_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/photo_viewer_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_report_services.dart';
import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Checkpoint 2 of the QA/QC closure pass: the defect evidence workflow.
/// QA #14 annotation, #16 quick defect note, #17 shorthand, #18
/// portrait/landscape, #19 original quality, #20 multiple angles.

Future<(ProviderContainer, FakeEvidenceFileStore, ScriptedBillingService)>
_started({bool autoAnalyse = true}) async {
  final store = FakeEvidenceFileStore();
  final billing = ScriptedBillingService();
  final container = ProviderContainer(
    overrides: testOverrides(evidenceFileStore: store, billingService: billing),
  );
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  container
      .read(activeSessionProvider.notifier)
      .setAutoAnalyseEnabled(autoAnalyse);
  return (container, store, billing);
}

Future<Finding> _save(
  ProviderContainer container, {
  String? note,
  EvidenceSource source = EvidenceSource.camera,
}) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final photo = await notifier.captureFindingPhoto(source: source);
  return notifier.saveCameraFinding(
    sectionId: container.read(inspectionQueueProvider).first.id,
    photo: photo!,
    note: note,
  );
}

Finding _current(ProviderContainer container, String findingId) => container
    .read(activeSessionProvider)!
    .findings
    .singleWhere((f) => f.id == findingId);

Future<Size> _pngSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return size;
}

Future<ui.Image> _solidImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.black,
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  group('camera and gallery share one pipeline', () {
    test('both sources create the same kind of finding and evidence', () async {
      final (container, _, _) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);

      final fromCamera = await _save(container, note: 'Crack');
      final fromGallery = await _save(
        container,
        note: 'Crack',
        source: EvidenceSource.gallery,
      );
      await pumpEventQueue();

      final camera = _current(container, fromCamera.id).evidence.single;
      final gallery = _current(container, fromGallery.id).evidence.single;
      expect(camera.source, EvidenceSource.camera);
      expect(gallery.source, EvidenceSource.gallery);
      expect(camera.annotatedFilePath, isNull);
      expect(gallery.annotatedFilePath, isNull);
    });
  });

  group('QA #14: annotation keeps the original', () {
    test('marking up a saved photo stores a separate copy; the original '
        'path is unchanged and never deleted', () async {
      final (container, store, _) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);
      final finding = await _save(container, note: 'Hollow tile');
      await pumpEventQueue();
      final original = _current(container, finding.id).evidence.single;

      await container
          .read(activeSessionProvider.notifier)
          .saveEvidenceAnnotation(
            findingId: finding.id,
            evidenceId: original.id,
            pngBytes: const [9, 9, 9],
          );
      await pumpEventQueue();

      final marked = _current(container, finding.id).evidence.single;
      expect(marked.filePath, original.filePath);
      expect(marked.annotatedFilePath, isNotNull);
      expect(marked.displayFilePath, marked.annotatedFilePath);
      expect(store.savedAnnotations[marked.annotatedFilePath], [9, 9, 9]);
      expect(store.deletedPaths, isNot(contains(original.filePath)));

      // The same state reloads from storage.
      final reloaded = await container
          .read(activeSessionProvider.notifier)
          .resume(container.read(activeSessionProvider)!.id);
      expect(reloaded, isTrue);
      final stored = _current(container, finding.id).evidence.single;
      expect(stored.filePath, original.filePath);
      expect(stored.annotatedFilePath, marked.annotatedFilePath);

      // Re-marking replaces the old copy, still never the original.
      final firstCopy = marked.annotatedFilePath!;
      await container
          .read(activeSessionProvider.notifier)
          .saveEvidenceAnnotation(
            findingId: finding.id,
            evidenceId: original.id,
            pngBytes: const [7],
          );
      await pumpEventQueue();
      expect(store.deletedPaths, contains(firstCopy));
      expect(store.deletedPaths, isNot(contains(original.filePath)));
    });

    test('a photo marked up before saving carries its copy into the '
        'finding', () async {
      final (container, _, _) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      final annotated = await notifier.annotateCapturedPhoto(photo!, const [1]);

      final finding = notifier.saveCameraFinding(
        sectionId: container.read(inspectionQueueProvider).first.id,
        photo: annotated,
        note: 'Tile holo',
      );
      await pumpEventQueue();

      final evidence = _current(container, finding.id).evidence.single;
      expect(evidence.filePath, photo.filePath);
      expect(evidence.annotatedFilePath, annotated.annotatedFilePath);
    });

    testWidgets('three or more colours can each be selected and drawn; undo '
        'removes the last stroke; clear resets; save returns the markup', (
      tester,
    ) async {
      Uint8List? saved;
      final image = await tester.runAsync(() => _solidImage(400, 300));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) => PhotoAnnotationScreen(
                      filePath: '/unused.jpg',
                      imageLoader: () async => image!,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey('annotation-canvas'));
      expect(annotationColors.length, greaterThanOrEqualTo(3));
      for (final pen in annotationColors.take(3)) {
        await tester.tap(find.byKey(ValueKey('pen-${pen.name}')));
        await tester.pump();
        await tester.drag(canvas, const Offset(60, 20));
        await tester.pump();
      }

      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.widgetWithIcon(
          IconButton,
          tooltip == 'Undo' ? Icons.undo : Icons.layers_clear_outlined,
        ),
      );
      expect(button('Undo').onPressed, isNotNull);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(button('Undo').onPressed, isNull, reason: 'nothing left');

      await tester.tap(find.byKey(const ValueKey('pen-Red')));
      await tester.drag(canvas, const Offset(40, 40));
      await tester.pump();
      final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(save.onPressed, isNotNull, reason: 'markup exists to save');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      // Rendering the PNG is real GPU/codec work the fake clock can't
      // advance; give it real time, then let the route pop.
      for (var i = 0; i < 20 && saved == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
    });

    test('the drawing model records each colour and undoes in order', () {
      final drawing = AnnotationDrawing();
      for (final pen in annotationColors.take(3)) {
        drawing.selectColor(pen.color);
        drawing.startStroke(const Offset(1, 1));
        drawing.extendStroke(const Offset(5, 5));
        drawing.endStroke();
      }
      expect(
        drawing.strokes.map((s) => s.color),
        annotationColors.take(3).map((p) => p.color),
      );
      drawing.undo();
      expect(drawing.strokes, hasLength(2));
      drawing.clear();
      expect(drawing.isEmpty, isTrue);
    });
  });

  group('QA #18 / #19: orientation and quality', () {
    test('portrait and landscape markups keep their exact size and aspect '
        'ratio — never cropped or stretched', () async {
      for (final (w, h) in [(300, 400), (400, 300)]) {
        final image = await _solidImage(w, h);
        final png = await renderAnnotatedPng(image, [
          AnnotationStroke(
            color: annotationColors.first.color,
            points: const [Offset(10, 10), Offset(100, 100)],
          ),
        ]);
        expect(await _pngSize(png), Size(w.toDouble(), h.toDouble()));
      }
    });

    test(
      'a very large photo is scaled down proportionally, not cropped',
      () async {
        final image = await _solidImage(3000, 4000);
        final png = await renderAnnotatedPng(image, const []);
        final size = await _pngSize(png);
        expect(size.height, kAnnotatedCopyMaxEdge.toDouble());
        expect(size.width / size.height, closeTo(3000 / 4000, 0.001));
      },
    );

    test('the report renders portrait and landscape photos (and a marked-up '
        'copy) without failing', () async {
      final dir = await Directory.systemTemp.createTemp('qa_evidence');
      addTearDown(() => dir.delete(recursive: true));
      final paths = <String>[];
      for (final (w, h) in [(300, 400), (400, 300)]) {
        final png = await renderAnnotatedPng(await _solidImage(w, h), const []);
        final file = File('${dir.path}/${w}x$h.png');
        await file.writeAsBytes(png);
        paths.add(file.path);
      }
      final model = ReportModel(
        sessionId: 's',
        propertyTypeLabel: 'High Rise',
        inspectionDate: DateTime(2026, 9, 25),
        generatedAt: DateTime(2026, 9, 25),
        totalAreas: 1,
        completedAreas: 1,
        totalFindings: 1,
        totalEvidence: 2,
        areas: [
          ReportAreaSection(
            name: 'Kitchen',
            isPlumbing: false,
            findings: [
              ReportFinding(
                number: 1,
                elementName: 'Wall',
                componentName: 'Tiles',
                defectType: 'Hollow tile',
                evidenceFilePaths: paths,
              ),
            ],
          ),
        ],
      );
      final bytes = await PdfReportRenderer().render(model);
      expect(bytes, isNotEmpty);
    });

    test('the report uses the marked-up copy when a photo has one', () async {
      final (container, _, _) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);
      final finding = await _save(container, note: 'Hollow tile');
      await pumpEventQueue();
      final photo = _current(container, finding.id).evidence.single;
      await container
          .read(activeSessionProvider.notifier)
          .saveEvidenceAnnotation(
            findingId: finding.id,
            evidenceId: photo.id,
            pngBytes: const [1],
          );
      await pumpEventQueue();

      final model = buildReportModel(
        session: container.read(activeSessionProvider)!,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 9, 25),
      );
      final reportPhoto = model.areas.single.findings.single.evidenceFilePaths;
      expect(reportPhoto, [
        _current(container, finding.id).evidence.single.annotatedFilePath,
      ]);
    });
  });

  group('QA #16 / #17: quick defect note', () {
    test('a finding saves without a note, but AI waits for one; adding the '
        'note starts AI with the verbatim text', () async {
      final (container, _, billing) = await _started();
      addTearDown(container.dispose);

      final finding = await _save(container);
      await pumpEventQueue(times: 100);
      expect(
        _current(container, finding.id).aiStatus,
        AiFindingStatus.awaitingApproval,
      );
      expect(billing.calls, isEmpty, reason: 'no note, no AI');

      container
          .read(inspectionFindingsProvider.notifier)
          .updateFinding(
            findingId: finding.id,
            description: 'win frem gap',
            notes: null,
          );
      await pumpEventQueue(times: 200);

      expect(billing.calls.single.note, 'win frem gap');
      expect(_current(container, finding.id).description, 'win frem gap');
    });

    test('approving analysis is refused while the note is missing', () async {
      final (container, _, billing) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);
      final finding = await _save(container);
      await pumpEventQueue();

      await container
          .read(activeSessionProvider.notifier)
          .approveAndRunAnalysis(finding.id);
      await pumpEventQueue(times: 100);

      expect(billing.calls, isEmpty);
    });
  });

  group('QA #20: multiple angles of one defect', () {
    test('three photos attach to one finding and AI receives all of them '
        '(the originals)', () async {
      final (container, _, billing) = await _started(autoAnalyse: false);
      addTearDown(container.dispose);
      final finding = await _save(container, note: 'Wall tile hollow');
      await pumpEventQueue();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.camera,
      );
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.gallery,
      );
      await pumpEventQueue();
      final photos = _current(container, finding.id).evidence;
      expect(photos, hasLength(3));
      expect(container.read(activeSessionProvider)!.findings, hasLength(1));

      await notifier.saveEvidenceAnnotation(
        findingId: finding.id,
        evidenceId: photos.first.id,
        pngBytes: const [1],
      );
      await pumpEventQueue();
      await notifier.approveAndRunAnalysis(finding.id);
      await pumpEventQueue(times: 200);

      final call = billing.calls.single;
      expect(call.evidenceIds, photos.map((p) => p.id).toList());
      expect(
        call.evidenceFilePaths,
        photos.map((p) => p.filePath).toList(),
        reason: 'AI analyses the originals, not the markup',
      );
    });

    testWidgets('the photo viewer shows every photo, removes one without '
        'touching the finding, and keeps the last one', (tester) async {
      final (container, _, _) =
          await tester.runAsync(() => _started(autoAnalyse: false)) ??
          (throw StateError('setup failed'));
      addTearDown(container.dispose);
      late Finding finding;
      await tester.runAsync(() async {
        finding = await _save(container, note: 'Crack');
        await container
            .read(activeSessionProvider.notifier)
            .addEvidence(findingId: finding.id, source: EvidenceSource.camera);
        await pumpEventQueue();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: PhotoViewerScreen(findingId: finding.id)),
        ),
      );
      await tester.pump();
      expect(find.text('Photo 1 of 2'), findsOneWidget);

      await tester.tap(find.text('Remove Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Photo 1 of 1'), findsOneWidget);
      expect(container.read(activeSessionProvider)!.findings, hasLength(1));
      final removeButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Remove Photo'),
      );
      expect(removeButton.onPressed, isNull);
    });
  });
}
