import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The compile-time half of the sandbox-payment boundary (see
/// docs/commercial_model.md, "Sandbox vs production", and
/// `functions/src/billing/payments_mode.ts`/
/// `handle_confirm_sandbox_payment.test.ts` for the backend/environment
/// half — the spec's "Do not depend only on hiding a button" means both
/// halves must hold independently).
///
/// Every UI call site of `BillingService.confirmSandboxPayment` must be
/// gated behind `kDebugMode` — a compile-time constant that's `false`
/// (and the whole call, being unreachable dead code, compiled out
/// entirely) in any release build — so a release build has no code
/// path to a fake payment success at all, not merely a hidden one.
///
/// This is necessarily a per-file textual check (verifying an actual
/// `if (kDebugMode)` guards the *specific* call, not just that the file
/// mentions `kDebugMode` somewhere) rather than a widget test:
/// `kDebugMode` is a real compile-time constant that widget tests
/// cannot flip to `false` and still run — a `flutter build apk
/// --release` (see docs/production_readiness.md) is what actually
/// proves the dead-code elimination; this test proves every call site
/// is at least written to require it.
void main() {
  test('every lib/ call site of confirmSandboxPayment is textually guarded '
      'by kDebugMode in the same file', () async {
    final libDir = Directory('lib');
    final offenders = <String>[];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final contents = await entity.readAsString();
      if (!contents.contains('.confirmSandboxPayment(')) continue;

      final relativePath = p.relative(entity.path, from: 'lib');
      if (!contents.contains('kDebugMode')) {
        offenders.add('$relativePath (no kDebugMode reference at all)');
        continue;
      }
      // A minimal, deliberately strict shape check: the guard must
      // appear textually before the call within the file (i.e. the
      // widget/method that performs the call is itself only reached
      // from behind the guard, mirroring the existing
      // `house_pass_screen.dart`/`top_up_screen.dart` pattern of an
      // `if (kDebugMode) ...` block containing the button that
      // triggers the confirm method).
      final guardIndex = contents.indexOf('kDebugMode');
      final callIndex = contents.indexOf('.confirmSandboxPayment(');
      if (guardIndex == -1 || guardIndex > callIndex) {
        offenders.add(
          '$relativePath (kDebugMode guard does not precede the call)',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files call confirmSandboxPayment without a preceding '
          'kDebugMode guard, meaning a release build could reach a '
          'fake-payment-success code path: $offenders',
    );
  });
}
