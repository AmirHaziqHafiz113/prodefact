import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/presentation/widgets/commercial_error_presentation.dart';

/// `BillingService` implementations always throw display-ready
/// `Exception`s (see `friendlyMessageForBillingFunctionsError` and
/// `FakeBillingService`'s own messages) — this mapper trusts that for
/// `Exception`s, but never trusts anything else, so a genuinely
/// unexpected error type (a raw platform/Firebase exception that
/// somehow reached the UI un-wrapped) can never leak its `.toString()`
/// to the inspector.
void main() {
  test('a known Exception message is passed through, minus the "Exception: " '
      'prefix', () {
    final message = CommercialErrorPresentation.messageFor(
      'House Pass purchase',
      Exception('Payment could not be confirmed.'),
    );
    expect(message, 'Payment could not be confirmed.');
  });

  test('a non-Exception error (e.g. a raw platform/Firebase exception) never '
      'has its toString() shown — falls back to the generic message', () {
    final message = CommercialErrorPresentation.messageFor(
      'Top-up intent creation',
      StateError('Bad state: [FirebaseFunctionsException] internal detail'),
    );
    expect(message, CommercialErrorPresentation.genericMessage);
    expect(message, isNot(contains('FirebaseFunctionsException')));
    expect(message, isNot(contains('Bad state')));
  });

  test('an Exception with an empty message falls back to the generic '
      'message rather than showing nothing useful', () {
    final message = CommercialErrorPresentation.messageFor(
      'House Pass purchase',
      Exception(''),
    );
    expect(message, CommercialErrorPresentation.genericMessage);
  });
}
