import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/backup/drive_backup.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/property_details_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/report_details_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/drive_backup_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';

import '../support/test_repository.dart';

/// Residence / Unit Photo flow (2026-10-12): one optional report-cover photo,
/// managed from Report Details, with convenience entry points in setup and
/// Inspection Overview — all writing the SAME underlying state. It is not a
/// defect photo: no finding, no defect AI, no Area Findings / AI Review.

class _CountingBilling extends FakeBillingService {
  _CountingBilling() : super(initialBalanceTokens: 100000000);

  int analyseCalls = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) {
    analyseCalls++;
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<(ProviderContainer, FakeEvidenceCaptureService, _CountingBilling)>
_started({bool withDraftPhoto = false}) async {
  final capture = FakeEvidenceCaptureService();
  final billing = _CountingBilling();
  final container = ProviderContainer(
    overrides: testOverrides(captureService: capture, billingService: billing),
  );
  addTearDown(container.dispose);
  final draft = container.read(newInspectionDraftProvider.notifier)
    ..begin(PropertyType.highRise)
    ..updatePropertyDetails(
      const PropertyDetails(title: 'Residensi Vista', unitNumber: '12-3'),
    );
  if (withDraftPhoto) {
    await draft.chooseResidencePhoto(EvidenceSource.gallery);
  }
  await draft.startInspection();
  return (container, capture, billing);
}

InspectionSession _session(ProviderContainer c) =>
    c.read(activeSessionProvider)!;

String? _photo(ProviderContainer c) =>
    _session(c).reportMetadata?.coverPhotoPath;

void main() {
  group('one underlying photo state', () {
    test('added during setup: the draft photo becomes the inspection\'s '
        'cover photo', () async {
      final (container, capture, _) = await _started(withDraftPhoto: true);
      expect(capture.captureCount, 1);
      expect(_photo(container), isNotNull);
      expect(_photo(container), contains('residence_draft_'));
      expect(container.read(newInspectionDraftProvider), isNull);
    });

    test('added later from Inspection Overview (the notifier both screens '
        'use), replaced and removed — always the same field', () async {
      final (container, _, _) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      expect(_photo(container), isNull);

      expect(await notifier.chooseResidencePhoto(EvidenceSource.camera), true);
      final first = _photo(container);
      expect(first, isNotNull);

      expect(await notifier.chooseResidencePhoto(EvidenceSource.gallery), true);
      final second = _photo(container);
      expect(second, isNotNull);
      expect(second, isNot(first), reason: 'replaced');

      notifier.removeResidencePhoto();
      expect(_photo(container), isNull);
    });

    test('it persists with the inspection (restart / navigation / sync '
        'read it back from the stored report metadata)', () async {
      final (container, _, _) = await _started();
      await container
          .read(activeSessionProvider.notifier)
          .chooseResidencePhoto(EvidenceSource.gallery);
      final id = _session(container).id;
      final path = _photo(container);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final reloaded = await container
          .read(inspectionRepositoryProvider)
          .loadSession(id);
      expect(reloaded!.reportMetadata!.coverPhotoPath, path);
      // The setup details were carried into the metadata untouched.
      expect(reloaded.reportMetadata!.title, 'Residensi Vista');
      expect(reloaded.reportMetadata!.unitNumber, '12-3');
    });
  });

  group('it is NOT a defect photo', () {
    test('no finding is created, no defect AI runs, nothing counts as '
        'evidence', () async {
      final (container, _, billing) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final session = _session(container);
      expect(session.findings, isEmpty, reason: 'no finding row');
      expect(session.aiSuggestions, isEmpty, reason: 'nothing to classify');
      expect(billing.analyseCalls, 0, reason: 'no defect AI call');
      expect(AiReviewProgress.of(session).total, 0, reason: 'not in AI Review');
      expect(
        session.findings.expand((f) => f.evidence),
        isEmpty,
        reason: 'not Area Findings evidence',
      );
    });
  });

  group('report', () {
    test(
      'uses the selected photo; shows the placeholder when absent',
      () async {
        final (container, _, _) = await _started();
        final notifier = container.read(activeSessionProvider.notifier);
        final without = buildReportModel(
          session: _session(container),
          propertyTypeLabel: 'High Rise',
          generatedAt: DateTime(2026, 10, 12),
        );
        expect(without.coverPhotoPath, isNull);
        expect(without.propertyTitle, 'Residensi Vista');
        expect(await PdfReportRenderer().render(without), isNotEmpty);

        await notifier.chooseResidencePhoto(EvidenceSource.gallery);
        final withPhoto = buildReportModel(
          session: _session(container),
          propertyTypeLabel: 'High Rise',
          generatedAt: DateTime(2026, 10, 12),
        );
        expect(withPhoto.coverPhotoPath, _photo(container));
        // A missing file never breaks rendering (placeholder instead).
        expect(await PdfReportRenderer().render(withPhoto), isNotEmpty);
      },
    );

    test(
      'a photo-only metadata snapshot does not change the cover title or '
      'date: blank title falls back, report date stays "generated on"',
      () async {
        final capture = FakeEvidenceCaptureService();
        final container = ProviderContainer(
          overrides: testOverrides(captureService: capture),
        );
        addTearDown(container.dispose);
        await container
            .read(activeSessionProvider.notifier)
            .startNew(PropertyType.highRise);
        await container
            .read(activeSessionProvider.notifier)
            .chooseResidencePhoto(EvidenceSource.gallery);
        final model = buildReportModel(
          session: _session(container),
          propertyTypeLabel: 'High Rise',
          generatedAt: DateTime(2026, 10, 12),
        );
        expect(
          model.propertyTitle,
          isNull,
          reason: 'cover keeps the type label',
        );
        expect(model.reportDate, isNull, reason: 'renderer stamps generatedAt');
      },
    );

    test('changing the photo marks an already-generated report stale '
        '(Regenerate creates the next version)', () async {
      final (container, _, _) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      final before = _session(container).updatedAt;
      final report = Report(
        id: 'r1',
        sessionId: _session(container).id,
        filePath: '/x.pdf',
        fileName: 'x.pdf',
        generatedAt: before,
        sourceUpdatedAt: before,
        syncStatus: SyncStatus.localOnly,
        version: 1,
      );
      expect(report.isStaleRelativeTo(_session(container).updatedAt), false);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      expect(report.isStaleRelativeTo(_session(container).updatedAt), true);

      final afterAdd = _session(container).updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      notifier.removeResidencePhoto();
      expect(_session(container).updatedAt.isAfter(afterAdd), true);
    });
  });

  group('Drive backup', () {
    test('the residence photo is queued as its OWN asset type, never as '
        'finding evidence', () async {
      final (container, _, _) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      final path = _photo(container)!;
      final sessionId = _session(container).id;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final store = container.read(driveBackupStoreProvider);
      final entry = await store.get(residencePhotoBackupId(sessionId, path));
      expect(entry, isNotNull);
      expect(entry!.assetType, DriveAssetType.residencePhoto);
      expect(entry.findingId, kResidencePhotoFindingId);

      // A defect photo's row is a different asset type.
      final finding = notifier.saveCameraFinding(
        sectionId: container.read(activeSessionProvider)!.sections.first.id,
        photo: (await notifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        ))!,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final evidenceEntry = await store.get(finding.evidence.single.id);
      expect(evidenceEntry!.assetType, DriveAssetType.findingEvidence);
    });

    test('replacing the photo drops the old unverified backup row and queues '
        'the new file separately', () async {
      final (container, _, _) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      final sessionId = _session(container).id;
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      final first = _photo(container)!;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      final second = _photo(container)!;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final store = container.read(driveBackupStoreProvider);
      expect(await store.get(residencePhotoBackupId(sessionId, first)), isNull);
      expect(
        await store.get(residencePhotoBackupId(sessionId, second)),
        isNotNull,
      );
    });

    test('backup ids are stable per file and distinct per photo', () {
      expect(
        residencePhotoBackupId('s1', '/a/b/123.jpg'),
        residencePhotoBackupId('s1', '/c/123.jpg'),
      );
      expect(
        residencePhotoBackupId('s1', '/a/123.jpg'),
        isNot(residencePhotoBackupId('s1', '/a/124.jpg')),
      );
    });
  });

  group('completed inspections are read-only', () {
    test('the residence photo cannot be added, replaced or removed', () async {
      final (container, capture, _) = await _started();
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.chooseResidencePhoto(EvidenceSource.gallery);
      final kept = _photo(container);
      final id = _session(container).id;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      await container
          .read(inspectionRepositoryProvider)
          .setSessionStatus(id, InspectionStatus.reported);
      await notifier.resume(id);
      final captures = capture.captureCount;

      expect(
        await notifier.chooseResidencePhoto(EvidenceSource.gallery),
        false,
      );
      notifier.setResidencePhoto('/other.jpg');
      notifier.removeResidencePhoto();
      expect(_photo(container), kept);
      expect(capture.captureCount, captures, reason: 'picker never opened');
      // …but Past Inspection can still show the stored photo.
      expect(_session(container).reportMetadata!.coverPhotoPath, kept);
    });
  });

  group('screens', () {
    Future<void> pump(
      WidgetTester tester,
      ProviderContainer container,
      Widget home,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: home),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('New Inspection setup offers an optional photo (Add, then '
        'Remove)', (tester) async {
      late ProviderContainer container;
      await tester.runAsync(() async {
        container = ProviderContainer(overrides: testOverrides());
        addTearDown(container.dispose);
        container
            .read(newInspectionDraftProvider.notifier)
            .begin(PropertyType.highRise);
      });
      await pump(tester, container, const PropertyDetailsScreen());

      expect(find.text('Residence / Unit Photo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('residence-photo-remove')),
        findsNothing,
      );

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('residence-photo-gallery')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(
        container.read(newInspectionDraftProvider)!.residencePhotoPath,
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey('residence-photo-remove')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('residence-photo-remove')));
      await tester.pumpAndSettle();
      expect(
        container.read(newInspectionDraftProvider)!.residencePhotoPath,
        isNull,
      );
    });

    testWidgets('Inspection Overview has an Add / Change photo entry point '
        'that writes the same state Report Details shows', (tester) async {
      late ProviderContainer container;
      await tester.runAsync(() async {
        (container, _, _) = await _started();
      });
      await pump(tester, container, const InspectionOverviewScreen());

      final entry = find.byKey(const ValueKey('overview-residence-photo'));
      expect(entry, findsOneWidget);
      expect(find.text('Add residence photo'), findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose from Gallery'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(_photo(container), isNotNull);
      expect(find.text('Change residence photo'), findsOneWidget);

      // Report Details shows that very photo and can replace / remove it.
      await pump(tester, container, const ReportDetailsScreen());
      expect(
        find.byKey(const ValueKey('residence-photo-preview')),
        findsOneWidget,
      );
      final before = _photo(container);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('residence-photo-gallery')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(_photo(container), isNot(before), reason: 'replaced');

      await tester.tap(find.byKey(const ValueKey('residence-photo-remove')));
      await tester.pumpAndSettle();
      expect(_photo(container), isNull);
      expect(
        find.byKey(const ValueKey('residence-photo-preview')),
        findsNothing,
      );
      expect(_session(container).findings, isEmpty);
    });
  });
}
