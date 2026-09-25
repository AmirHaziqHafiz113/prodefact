import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Final re-verification of QA #11 (background AI) after the QA/QC
/// closure pass. QA #26 (connectivity wording, restart recovery, no
/// duplicate charge or House Pass use) is covered by
/// `ai_job_recovery_test.dart` and the Functions idempotency tests.

Future<void> _captureAndSave(WidgetTester tester, String note) async {
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Camera'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, note);
  await tester.tap(find.widgetWithText(FilledButton, 'Save Finding'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('QA #11: save a finding, leave the area, inspect the next '
      'area; AI keeps running in the background and finishes for both', (
    tester,
  ) async {
    final billing = ScriptedBillingService()..gate = Completer<void>();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container
          .read(activeSessionProvider.notifier)
          .startNew(PropertyType.highRise);
    });
    container.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<void> openArea(String sectionId) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: ValueKey(sectionId),
          home: AreaInspectionScreen(sectionId: sectionId),
        ),
      ),
    );

    await openArea(queue[0].id);
    await tester.pumpAndSettle();
    await _captureAndSave(tester, 'Tile holo');
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
    expect(billing.calls, hasLength(1), reason: 'AI started in area 1');

    // Leave area 1 (its screen is disposed) and inspect area 2.
    await openArea(queue[1].id);
    await tester.pumpAndSettle();
    await _captureAndSave(tester, 'Win frem gap');
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }

    var findings = container.read(activeSessionProvider)!.findings;
    expect(findings, hasLength(2));
    expect(
      findings.every((f) => aiFindingStatusIsInFlight(f.aiStatus)),
      isTrue,
      reason: 'both analyses are running independently',
    );
    expect(billing.calls, hasLength(2));

    billing.gate!.complete();
    for (var i = 0; i < 40; i++) {
      await tester.pump();
    }

    findings = container.read(activeSessionProvider)!.findings;
    for (final finding in findings) {
      expect(
        finding.aiStatus,
        isIn([AiFindingStatus.completed, AiFindingStatus.needsReview]),
      );
    }
    expect(billing.providerRuns, 2, reason: 'one charge per finding');
  });
}
