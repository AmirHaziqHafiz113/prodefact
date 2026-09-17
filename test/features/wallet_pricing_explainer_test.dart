import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';

import '../support/test_repository.dart';

/// The redesign pass explicitly must never copy the reference mockup's
/// illustrative sample numbers (e.g. "RM39/month" for House Pass, or an
/// invented Credits-per-Ringgit rate) — every price shown must come
/// from the real, server-computed `CommercialConfig`. See
/// docs/commercial_model.md ("House Pass ... RM30 per property, not
/// unlimited") and docs/ui_design_system.md.
void main() {
  testWidgets('the Wallet pricing explainer shows the real House Pass rule '
      '("RM30 / property", never a fabricated monthly subscription '
      'price) and the real Flex Credits rate from CommercialConfig', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Wallet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WalletScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Choose the right plan for you'),
      300,
      scrollable: find.byType(Scrollable),
    );

    // The real business rule — see FakeBillingService's
    // `_housePassPriceMyr = 30.0` — never the mockup's illustrative
    // "RM39/month" or any "/month" wording at all (House Pass is a
    // fixed price per property, not a subscription).
    expect(find.text('RM30 / property'), findsOneWidget);
    expect(find.textContaining('/month'), findsNothing);
    expect(find.textContaining('RM39'), findsNothing);

    // The real Credits-per-Ringgit rate — see FakeBillingService's
    // `_creditsPerMyr = 100` (i.e. RM0.01/credit) — never a
    // fabricated "RM0.50/credit" copied verbatim from the mockup.
    expect(find.text('RM0.01 / credit'), findsOneWidget);
    expect(find.textContaining('RM0.50'), findsNothing);
  });
}
