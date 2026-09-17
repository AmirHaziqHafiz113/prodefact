import '../../../../core/logging/app_logger.dart';

/// Maps a caught commercial/billing error (Top Up, House Pass) to a
/// short, customer-safe message — never raw exception text, stack
/// traces, provider/backend implementation details, or Firebase error
/// codes.
///
/// `BillingService` implementations already throw display-ready
/// `Exception`s (see `friendlyMessageForBillingFunctionsError` in
/// `FirebaseBillingService`, and `FakeBillingService`'s own hand-written
/// messages) — this mostly extracts that message. Anything that isn't a
/// plain `Exception` is a genuinely unexpected error type, so it's never
/// shown to the inspector at all: it falls back to a generic message,
/// and the real error is still logged via the existing `AppLogger`
/// path for debugging.
abstract final class CommercialErrorPresentation {
  static const String genericMessage =
      'Something went wrong. Please try again.';

  static String messageFor(
    String context,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      if (message.isNotEmpty) return message;
    }
    AppLogger.error(
      '$context failed with an unexpected error type',
      error,
      stackTrace,
    );
    return genericMessage;
  }
}
