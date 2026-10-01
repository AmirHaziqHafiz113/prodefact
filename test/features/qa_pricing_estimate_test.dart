import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/billing/firebase_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_analysis_approval_dialog.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/test_repository.dart';

/// "Could not check pricing" (2026-10-01). Production logs showed every
/// estimate returning 403 permission-denied: a finding saved with Auto
/// Analyse off was never in Firestore when pricing ran. The app now
/// registers the finding first, and explains a failed check precisely.

/// Prices only findings already registered in the (fake) cloud — what
/// the real backend's ownership check does.
class _OwnershipCheckingBilling extends FakeBillingService {
  _OwnershipCheckingBilling(this.cloud, {this.failWith});

  final FakeCloudInspectionRepository cloud;
  final Object? failWith;
  final List<String> estimatedFindings = [];

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) {
    final error = failWith;
    if (error != null) throw error;
    if (!cloud.pushedFindings.containsKey(findingId)) {
      throw billingCallExceptionFor('permission-denied', {
        'reason': 'findingNotSynced',
      });
    }
    estimatedFindings.add(findingId);
    return super.estimateFindingAnalysis(
      inspectionId: inspectionId,
      findingId: findingId,
      aiLevel: aiLevel,
    );
  }
}

Future<(ProviderContainer, String)> _startWithLocalFinding(
  WidgetTester tester, {
  required FakeCloudInspectionRepository cloud,
  required BillingService billing,
}) async {
  final container = ProviderContainer(
    overrides: testOverridesWithSync(
      billingService: billing,
      authService: FakeAuthService(initialUser: testAuthUser),
      cloudRepository: cloud,
    ),
  );
  addTearDown(container.dispose);
  final notifier = container.read(activeSessionProvider.notifier);
  await notifier.startNew(PropertyType.highRise);
  // Auto Analyse off (the Flex default): the finding stays local-only.
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  final finding = notifier.saveCameraFinding(
    sectionId: container.read(inspectionQueueProvider).first.id,
    photo: photo!,
    note: 'Tile holo',
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump();
  }
  expect(cloud.pushedFindings.containsKey(finding.id), isFalse);
  return (container, finding.id);
}

Future<void> _openDialog(
  WidgetTester tester,
  ProviderContainer container,
  String findingId,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAnalyseApprovalDialog(
                context: context,
                ref: ref,
                findingId: findingId,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 30; i++) {
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1. a newly saved, local-only finding is registered with the '
      'backend before pricing, so the estimate succeeds', (tester) async {
    final cloud = FakeCloudInspectionRepository();
    final billing = _OwnershipCheckingBilling(cloud);
    final (container, findingId) = await _startWithLocalFinding(
      tester,
      cloud: cloud,
      billing: billing,
    );

    await _openDialog(tester, container, findingId);

    expect(cloud.pushedFindings.containsKey(findingId), isTrue);
    expect(billing.estimatedFindings, [findingId]);
    expect(find.text('Smart AI'), findsOneWidget);
    expect(find.text('Could not check pricing'), findsNothing);
    // Only the finding document; no photo upload is needed for pricing.
    expect(cloud.uploadEvidenceCalls, 0);
  });

  testWidgets('3. a permission-denied answer is explained, not hidden '
      'behind "check your connection"', (tester) async {
    final cloud = FakeCloudInspectionRepository();
    final billing = _OwnershipCheckingBilling(
      cloud,
      failWith: billingCallExceptionFor('permission-denied', {
        'reason': 'findingNotSynced',
      }),
    );
    final (container, findingId) = await _startWithLocalFinding(
      tester,
      cloud: cloud,
      billing: billing,
    );

    await _openDialog(tester, container, findingId);

    expect(find.text('Could not check pricing'), findsOneWidget);
    expect(
      find.text(
        "We couldn't verify this finding. Please save/sync the finding and "
        'try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a finding that cannot be registered (offline) says the '
      'pricing service is unavailable', (tester) async {
    final cloud = FakeCloudInspectionRepository();
    final billing = _OwnershipCheckingBilling(cloud);
    final (container, findingId) = await _startWithLocalFinding(
      tester,
      cloud: cloud,
      billing: billing,
    );
    cloud.failEveryCallWith = Exception('no network');

    await _openDialog(tester, container, findingId);

    expect(
      find.text('Pricing service is temporarily unavailable. Try again.'),
      findsOneWidget,
    );
    expect(billing.estimatedFindings, isEmpty);
  });

  test('every failure class maps to its own message', () {
    BillingCallException e(String code) => billingCallExceptionFor(code, null);
    expect(
      pricingErrorMessage(e('permission-denied')),
      startsWith("We couldn't verify this finding"),
    );
    expect(
      pricingErrorMessage(e('unauthenticated')),
      'Your session has expired. Please sign in again.',
    );
    for (final code in ['unavailable', 'deadline-exceeded']) {
      expect(
        pricingErrorMessage(e(code)),
        'Pricing service is temporarily unavailable. Try again.',
      );
    }
    expect(
      pricingErrorMessage(TimeoutException('slow')),
      'Pricing service is temporarily unavailable. Try again.',
    );
    for (final code in ['internal', 'failed-precondition']) {
      expect(
        pricingErrorMessage(e(code)),
        'Pricing is temporarily unavailable.',
      );
    }
    expect(pricingErrorMessage(StateError('?')), 'Could not check pricing.');
    expect(pricingErrorMessage(null), 'Could not check pricing.');
  });

  test('the backend error code and reason survive into the app', () {
    final error = billingCallExceptionFor('permission-denied', {
      'reason': 'findingNotSynced',
    });
    expect(error.code, 'permission-denied');
    expect(error.reason, 'findingNotSynced');
    expect(error.toString(), startsWith('Exception: '));
  });

  test('11. the parser accepts the real backend response, including a '
      'missing reason (omitted from JSON when undefined)', () {
    final estimate = parseAnalysisEstimate({
      'aiLevel': 'smart',
      'estimatedCredits': 2,
      'maximumCredits': 2,
      'currentBalance': 500,
      'paymentMode': 'flexCredits',
      'includedInHousePass': false,
      'surchargeCredits': 0,
      'eligible': true,
    });
    expect(estimate.aiLevel, AiLevel.smart);
    expect(estimate.maximumCredits, 2);
    expect(estimate.paymentMode, CommercialMode.flexCredits);
    expect(estimate.eligible, isTrue);
    expect(estimate.reason, isNull);
  });
}
