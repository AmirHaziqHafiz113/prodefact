/// A failed billing callable (pricing, top-up, House Pass), keeping the
/// backend's error [code] (e.g. `permission-denied`) and optional
/// [reason] so the app can explain what actually went wrong instead of
/// one generic message. [message] is already customer-safe.
class BillingCallException implements Exception {
  const BillingCallException(this.code, this.message, {this.reason});

  final String code;
  final String message;
  final String? reason;

  /// Matches `Exception(message).toString()`, which billing errors used
  /// before, so existing message handling is unchanged.
  @override
  String toString() => 'Exception: $message';
}
