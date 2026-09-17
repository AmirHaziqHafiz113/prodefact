import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/theme/design_system.dart';

import '../support/test_repository.dart';

/// Property Type Selection: exactly two options (High Rise, Landed),
/// the step-1 stepper, and tap-to-select-and-continue (no separate
/// Continue button — see the screen's own doc comment).
void main() {
  testWidgets('shows exactly two property type options and the step-1 stepper, '
      'and tapping one continues to Property Details', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
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

    expect(find.text('High Rise'), findsOneWidget);
    expect(find.text('Landed'), findsOneWidget);
    expect(find.byType(AppWizardStepper), findsOneWidget);

    await tester.tap(find.text('Landed'));
    await tester.pumpAndSettle();

    expect(find.text('Property Details'), findsOneWidget);
  });
}
