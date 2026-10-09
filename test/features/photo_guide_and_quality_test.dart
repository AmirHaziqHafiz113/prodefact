import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/photo_guide_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// Photo guidance (shown once per NEW inspection, reopenable) and soft,
/// local photo-quality hints that never block saving (2026-10-04).

Finder _scaffold(Finder f) =>
    find.descendant(of: find.byType(Scaffold).last, matching: f);

/// Drives the setup wizard up to (not past) the photo guide.
Future<ProviderContainer> _startNewInspection(
  WidgetTester tester, {
  FakeImageQualityService? quality,
  FakeEvidenceCaptureService? capture,
}) async {
  final container = ProviderContainer(
    overrides: testOverrides(
      imageQualityService: quality,
      captureService: capture,
    ),
  );
  addTearDown(container.dispose);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProDefactApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Capture'));
  await tester.pumpAndSettle();
  await tester.tap(_scaffold(find.text('High Rise')));
  await tester.pumpAndSettle();
  await tester.enterText(
    _scaffold(find.byType(TextFormField)).first,
    'Guide Test',
  );
  await tester.tap(_scaffold(find.text('Continue')));
  await tester.pumpAndSettle();
  await tester.tap(_scaffold(find.text('Continue')));
  await tester.pumpAndSettle();
  await tester.tap(_scaffold(find.text('Start Inspection')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _continueFromGuide(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Start Inspection'));
  await tester.pumpAndSettle();
}

Future<void> _openFirstArea(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.tap(
    _scaffold(find.text(container.read(inspectionQueueProvider).first.name)),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data == 'Take Defect Photo' ||
              w.data == 'Take Another Defect Photo'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Camera'));
  await tester.pumpAndSettle();
}

Future<void> _saveFromPreview(WidgetTester tester, String note) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    ),
    note,
  );
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Save Finding'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('photo guide', () {
    testWidgets('1 + 3 + 4. a NEW inspection shows the guide once; taking '
        'photos never shows it again; it can be reopened manually', (
      tester,
    ) async {
      final container = await _startNewInspection(tester);

      expect(find.byType(PhotoGuideScreen), findsOneWidget);
      expect(find.text('How to capture a good defect photo'), findsOneWidget);
      for (final line in PhotoGuideScreen.guidelines) {
        expect(find.text(line), findsOneWidget);
      }
      expect(find.textContaining('These are guidance only'), findsOneWidget);
      expect(find.textContaining('no required angle'), findsOneWidget);

      await _continueFromGuide(tester);
      expect(find.text('Inspection Overview'), findsOneWidget);
      expect(find.byType(PhotoGuideScreen), findsNothing);

      await _openFirstArea(tester, container);
      for (var i = 0; i < 2; i++) {
        await _capture(tester);
        expect(find.byType(PhotoGuideScreen), findsNothing);
        await _saveFromPreview(tester, 'Crack $i');
      }
      expect(container.read(activeSessionProvider)!.findings, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('photo-guide-action')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGuideScreen), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);
      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGuideScreen), findsNothing);
      expect(container.read(activeSessionProvider)!.findings, hasLength(2));
    });
  });

  group('soft quality check', () {
    testWidgets('a clear photo goes straight to the preview, marked "Photo '
        'looks clear"', (tester) async {
      final quality = FakeImageQualityService();
      final container = await _startNewInspection(tester, quality: quality);
      await _continueFromGuide(tester);
      await _openFirstArea(tester, container);
      await _capture(tester);

      expect(find.text('Photo may be difficult to analyse'), findsNothing);
      expect(find.text('Photo looks clear'), findsOneWidget);
      expect(quality.checks, 1);
    });

    testWidgets('5 + 6 + 7. a poor photo gets an advisory warning; Use '
        'Anyway continues and the finding is saved', (tester) async {
      final quality = FakeImageQualityService(
        issuesForAll: [LocalImageIssue.blurry, LocalImageIssue.tooDark],
      );
      final container = await _startNewInspection(tester, quality: quality);
      await _continueFromGuide(tester);
      await _openFirstArea(tester, container);
      await _capture(tester);

      expect(find.text('Photo may be difficult to analyse'), findsOneWidget);
      expect(find.text('• Image appears blurry'), findsOneWidget);
      expect(find.text('• Image appears too dark'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);

      await tester.tap(find.text('Use Anyway'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Possible issues: image appears blurry'),
        findsOneWidget,
      );
      await _saveFromPreview(tester, 'Hairline crack');

      final finding = container.read(activeSessionProvider)!.findings.single;
      expect(finding.description, 'Hairline crack');
      expect(finding.evidence, hasLength(1));
    });

    testWidgets('Retake discards the photo and captures again; nothing is '
        'saved until the inspector chooses', (tester) async {
      final quality = FakeImageQualityService(
        issuesForAll: [LocalImageIssue.blurry],
      );
      final capture = FakeEvidenceCaptureService();
      final container = await _startNewInspection(
        tester,
        quality: quality,
        capture: capture,
      );
      await _continueFromGuide(tester);
      await _openFirstArea(tester, container);
      await _capture(tester);

      // The retaken photo looks fine.
      quality.issuesForAll = const [];
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();

      expect(capture.captureCount, 2);
      expect(find.text('Photo may be difficult to analyse'), findsNothing);
      expect(find.text('Photo looks clear'), findsOneWidget);
      expect(container.read(activeSessionProvider)!.findings, isEmpty);
    });
  });

  group('local heuristics (assessPixels)', () {
    Uint8List rgba(int w, int h, int Function(int x, int y) luma) {
      final out = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final v = luma(x, y);
          final i = (y * w + x) * 4;
          out[i] = v;
          out[i + 1] = v;
          out[i + 2] = v;
          out[i + 3] = 255;
        }
      }
      return out;
    }

    ImageQualityAssessment assess(
      int Function(int x, int y) luma, {
      int sourceShortSide = 3000,
    }) => assessPixels(
      sourceWidth: 4000,
      sourceHeight: sourceShortSide,
      width: 64,
      height: 48,
      rgba: rgba(64, 48, luma),
    );

    test('a sharp, well-lit photo looks clear', () {
      expect(
        assess((x, y) => ((x ~/ 4) + (y ~/ 4)).isEven ? 40 : 220).looksClear,
        isTrue,
      );
    });

    test('a plain, evenly lit surface (e.g. a wall) is NOT called blurry', () {
      expect(assess((x, y) => 180).looksClear, isTrue);
    });

    test('dark, overexposed, soft and low-resolution photos are flagged', () {
      expect(assess((x, y) => 10).issues, contains(LocalImageIssue.tooDark));
      expect(
        assess((x, y) => 255).issues,
        contains(LocalImageIssue.overexposed),
      );
      // A smooth left-to-right gradient: contrast, but no sharp edges.
      expect(
        assess((x, y) => 30 + x * 3).issues,
        contains(LocalImageIssue.blurry),
      );
      expect(
        assess(
          (x, y) => ((x ~/ 4) + (y ~/ 4)).isEven ? 40 : 220,
          sourceShortSide: 300,
        ).issues,
        [LocalImageIssue.lowResolution],
      );
    });
  });

  group('AI image usability (same request)', () {
    test('10. imageUsable, qualityIssues and isRelevantInspectionImage are '
        'saved with the suggestion and survive a reload', () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      final session = container.read(activeSessionProvider)!;
      final repository = container.read(inspectionRepositoryProvider);
      final now = DateTime(2026, 10, 4);
      await repository.saveFinding(
        session.id,
        Finding(
          id: 'f',
          sectionId: session.sections.first.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.saveAiSuggestion(
        AiSuggestion(
          id: 's',
          sessionId: session.id,
          findingId: 'f',
          providerId: 'ai',
          generatedAt: now,
          isRelevantInspectionImage: true,
          imageUsable: false,
          qualityIssues: const ['blur', 'unclear'],
        ),
      );
      final stored = (await repository.loadSession(session.id))!
          .aiSuggestions
          .single;
      expect(stored.isRelevantInspectionImage, isTrue);
      expect(stored.imageUsable, isFalse);
      expect(stored.qualityIssues, ['blur', 'unclear']);
    });

    test('the AI\'s photo remarks become a helpful, optional line', () {
      AiSuggestion s({
        bool? relevant,
        bool? usable,
        List<String> issues = const [],
      }) => AiSuggestion(
        id: 's',
        sessionId: 'x',
        findingId: 'f',
        providerId: 'ai',
        generatedAt: DateTime(2026),
        isRelevantInspectionImage: relevant,
        imageUsable: usable,
        qualityIssues: issues,
      );
      expect(aiImageQualityNote(s()), isNull);
      expect(aiImageQualityNote(s(relevant: true, usable: true)), isNull);
      expect(
        aiImageQualityNote(s(relevant: true, usable: false, issues: ['blur'])),
        'Image quality warning: Photo is blurry. Consider retaking if a '
        'clearer image is available.',
      );
      expect(
        aiImageQualityNote(s(relevant: false, issues: ['unrelated'])),
        'Image appears unrelated to the inspection.',
      );
    });

    testWidgets('AI Review shows the photo warning without forcing a '
        'retake (Change/Reject still offered)', (tester) async {
      late ProviderContainer container;
      await tester.runAsync(() async {
        container = ProviderContainer(
          overrides: testOverrides(billingService: _UnclearPhotoBilling()),
        );
        final notifier = container.read(activeSessionProvider.notifier);
        await notifier.startNew(PropertyType.highRise);
        final photo = await notifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        );
        notifier.saveCameraFinding(
          sectionId: container.read(inspectionQueueProvider).first.id,
          photo: photo!,
          note: 'Crack',
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      addTearDown(container.dispose);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AiReviewOverviewScreen()),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Image quality warning: Photo is blurry'),
        findsOneWidget,
      );
      expect(find.text('Change'), findsOneWidget);
      expect(
        container.read(activeSessionProvider)!.findings,
        hasLength(1),
        reason: 'the finding is kept — nothing forces a retake',
      );
    });
  });
}

/// The AI answers with a usable-but-blurry photo assessment.
class _UnclearPhotoBilling extends FakeBillingService {
  _UnclearPhotoBilling() : super(initialBalanceCredits: 10000);

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final r = await super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
    final c = r.classification;
    return AnalyseFindingResult(
      aiLevel: r.aiLevel,
      creditsCharged: r.creditsCharged,
      newBalance: r.newBalance,
      paymentMode: r.paymentMode,
      classification: AiFindingClassification(
        findingId: c.findingId,
        needsReview: true,
        catalogueEntryId: c.catalogueEntryId,
        defectTerm: c.defectTerm,
        confidence: 0.4,
        isRelevantInspectionImage: true,
        imageUsable: false,
        qualityIssues: const ['blur'],
      ),
    );
  }
}
