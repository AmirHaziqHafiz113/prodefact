import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_analysis_approval_dialog.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// AI Analysis Preference (2026-10-01): the inspector picks Fast / Smart
/// / Expert once, in Profile; every analysis path uses it silently.
/// There is no level choice at upload or in the approval dialog.

/// Records the level every estimate and analysis is asked for.
class _RecordingBilling extends FakeBillingService {
  _RecordingBilling() : super(initialBalanceCredits: 5000);

  final List<AiLevel> estimated = [];
  final List<AiLevel> analysed = [];

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) {
    estimated.add(aiLevel);
    return super.estimateFindingAnalysis(
      inspectionId: inspectionId,
      findingId: findingId,
      aiLevel: aiLevel,
    );
  }

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) {
    analysed.add(aiLevel);
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<void> _savePreference(ProviderContainer container, AiLevel? level) =>
    container
        .read(inspectionRepositoryProvider)
        .saveUserProfile(
          UserProfile(
            companyName: 'Acme Inspect',
            inspectorName: 'Aina',
            defaultAiLevel: level,
          ),
        );

Future<String> _saveFinding(ProviderContainer container) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  return notifier
      .saveCameraFinding(
        sectionId: container.read(inspectionQueueProvider).first.id,
        photo: photo!,
        note: 'Hollow tile',
      )
      .id;
}

Future<void> _openProfile(WidgetTester tester, ProviderContainer c) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const ProDefactApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Profile'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('3 + 4. tapping Expert saves it, keeps the saved names, and it '
      'is still selected when Profile is reopened', (tester) async {
    final repository = createInMemoryRepository();
    final container = ProviderContainer(
      overrides: testOverrides(repository: repository),
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => _savePreference(container, null));

    await _openProfile(tester, container);
    await tester.tap(find.byKey(const ValueKey('ai-pref-expert')));
    await tester.pumpAndSettle();
    expect(find.text('AI analysis set to Expert.'), findsOneWidget);

    final stored = (await tester.runAsync(repository.loadUserProfile))!;
    expect(stored.defaultAiLevel, AiLevel.expert);
    expect(stored.companyName, 'Acme Inspect');
    expect(stored.inspectorName, 'Aina');

    // A fresh app on the same database shows the saved choice.
    final reopened = ProviderContainer(
      overrides: testOverrides(repository: repository),
    );
    addTearDown(reopened.dispose);
    await _openProfile(tester, reopened);
    final expert = tester.widget<ListTile>(
      find.byKey(const ValueKey('ai-pref-expert')),
    );
    expect(expert.selected, isTrue);
    // Let the confirmation snackbar's timer run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  test(
    '5. background (Auto Analyse) analysis uses the saved preference',
    () async {
      final billing = _RecordingBilling();
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      await _savePreference(container, AiLevel.fast);
      await container
          .read(activeSessionProvider.notifier)
          .startNew(PropertyType.highRise);
      container
          .read(activeSessionProvider.notifier)
          .setAutoAnalyseEnabled(true);

      await _saveFinding(container);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(billing.analysed, [AiLevel.fast]);
    },
  );

  test('6. with no saved preference, analysis uses Smart', () async {
    final billing = _RecordingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    container.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(true);

    await _saveFinding(container);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(billing.analysed, [AiLevel.smart]);
  });

  test('7. pricing estimates use the saved preference', () async {
    final billing = _RecordingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await _savePreference(container, AiLevel.expert);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    final findingId = await _saveFinding(container);

    final estimate = await container
        .read(activeSessionProvider.notifier)
        .estimateFindingAnalysis(findingId);

    expect(estimate!.aiLevel, AiLevel.expert);
    expect(billing.estimated, [AiLevel.expert]);
  });

  testWidgets('8 + 9. the approval dialog shows the saved level, offers no '
      'level choice, and Analyse runs at that level', (tester) async {
    final billing = _RecordingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await _savePreference(container, AiLevel.fast);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(PropertyType.highRise);
    final findingId = await _saveFinding(container);
    for (var i = 0; i < 30; i++) {
      await tester.pump();
    }

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

    expect(find.text('Fast AI'), findsOneWidget);
    expect(find.byType(SegmentedButton<AiLevel>), findsNothing);
    expect(find.text('Smart'), findsNothing);
    expect(find.text('Expert'), findsNothing);

    await tester.tap(find.text('Analyse'));
    for (var i = 0; i < 30; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(billing.analysed, [AiLevel.fast]);
  });
}
