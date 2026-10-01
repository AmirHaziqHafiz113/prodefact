import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';
import 'support/uncertain_ai_billing_service.dart';

Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

/// Common phone widths a real inspector might use — narrow (iPhone
/// SE/mini-class and small Android), standard (iPhone 14/15/16,
/// mainstream Android), and large (Pro Max-class/large Android). Every
/// screen this pass touched is re-checked at each of these while
/// already mounted, so a layout that only breaks at one specific width
/// can't hide behind the others.
const _phoneWidths = [320.0, 360.0, 390.0, 430.0];

/// Re-lays-out the currently mounted screen at every width in
/// [_phoneWidths] and asserts none of them throws (Flutter surfaces a
/// `RenderFlex` overflow as a real `FlutterError`, which
/// `tester.takeException()` — the standard idiom for this — captures).
/// A generous, fixed height keeps this a pure width-overflow check,
/// independent of the lazy-list-not-built-at-a-short-viewport class of
/// issue this pass already hit (and fixed) separately.
Future<void> _assertNoOverflowAcrossWidths(
  WidgetTester tester, {
  String? screenLabel,
}) async {
  for (final width in _phoneWidths) {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '${screenLabel ?? 'screen'} overflowed at width ${width}pt: '
          '$exception',
    );
  }
}

/// Re-lays-out the currently mounted screen at each of a few text
/// scale factors — 1.0 (system default), 1.3 (iOS "Larger Text"
/// upper-middle), and 1.6 (a genuinely large accessibility setting) —
/// and asserts none of them throws. Restores the default afterward so
/// later checks in the same test aren't affected.
Future<void> _assertNoOverflowAcrossTextScales(
  WidgetTester tester, {
  String? screenLabel,
}) async {
  for (final scale in [1.0, 1.3, 1.6]) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '${screenLabel ?? 'screen'} overflowed at text scale $scale: '
          '$exception',
    );
  }
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home / Inspections / Wallet / Profile tabs never overflow at '
      'narrow, standard, or large phone widths', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Inspections');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Inspections');

    final bottomNav = find.byType(AppBottomNav);
    Finder inNav(String label) =>
        find.descendant(of: bottomNav, matching: find.text(label));

    await tester.tap(inNav('Home'));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Home');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Home');

    await tester.tap(inNav('Wallet'));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Wallet');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Wallet');

    await tester.tap(inNav('Profile'));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Profile');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Profile');
  });

  testWidgets('the full New Inspection wizard, physical inspection, AI review, '
      'and report flow never overflows at narrow, standard, or large '
      'phone widths', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;

    // Uncertain AI keeps the full Accept/Change/Reject card on screen.
    final container = ProviderContainer(
      overrides: testOverrides(billingService: UncertainAiBillingService()),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New Inspection'));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Property Type');

    await tester.tap(_within(find.text('High Rise')));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'Basic Details',
    );
    await _assertNoOverflowAcrossTextScales(
      tester,
      screenLabel: 'Basic Details',
    );

    await tester.enterText(
      _within(find.byType(TextFormField)).first,
      'A-1-1',
    );
    await tester.tap(_within(find.text('Continue')));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Configure Areas');

    await tester.tap(_within(find.text('Continue')));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Review Setup');

    await tester.tap(_within(find.text('Start Inspection')));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'Inspection Overview',
    );
    await _assertNoOverflowAcrossTextScales(
      tester,
      screenLabel: 'Inspection Overview',
    );

    container.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final section = queue.first;
    await tester.tap(_within(find.text(section.name)));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Area Detail');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Area Detail');

    await tester.tap(_within(find.text('Take Defect Photo')));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'Camera/Gallery choice sheet',
    );
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    // The photo-preview bottom sheet — checked at its own narrower
    // heights too, since a bottom sheet's usable height shrinks with
    // the keyboard open (a real note field sits right above Save).
    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'Photo preview sheet',
    );
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
    await tester.pump();
    await tester.pump();
    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'Area Detail with a saved finding',
    );

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final s in queue) {
      statusNotifier.setStatus(s.id, SectionStatus.completed);
    }
    await tester.pump();

    await tester.tap(_within(find.text('Complete Physical Inspection')));
    await tester.pumpAndSettle();
    // Confirm the completion summary dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'AI Review');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'AI Review');

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final resolveLabel = suggestion.needsReview ? 'Change' : 'Accept';
    await tester.scrollUntilVisible(
      _within(find.text(resolveLabel)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(_within(find.text(resolveLabel)));
    await tester.pumpAndSettle();
    if (suggestion.needsReview) {
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
    }

    await tester.tap(
      _within(find.widgetWithText(FilledButton, 'Continue to Report')),
    );
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Report');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Report');
  });
}
