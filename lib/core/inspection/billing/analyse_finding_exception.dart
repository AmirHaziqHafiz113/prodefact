/// A failed `analyseFinding` call, classified by whether the backend is
/// known to have reached a final answer.
///
/// [outcomeUnknown] is true when the request may have reached the
/// backend but no response arrived (client timeout, network drop, the
/// app losing the connection mid-call). The backend may still have
/// completed — and charged — that request, so the caller must keep the
/// same idempotency key and replay it rather than start a new,
/// separately charged analysis. See `AiAnalysisAttempt`.
///
/// [outcomeUnknown] is false for a rejection the backend itself returned
/// (insufficient Credits, permission, a provider failure it already
/// refunded, or a replay of an attempt it recorded as failed). The key
/// can then be discarded, and a later inspector Retry safely mints a
/// fresh one.
class AnalyseFindingException implements Exception {
  const AnalyseFindingException(this.message, {required this.outcomeUnknown});

  final String message;
  final bool outcomeUnknown;

  /// Matches `Exception(message).toString()`, which is what every other
  /// billing call throws, so existing message handling is unchanged.
  @override
  String toString() => 'Exception: $message';
}

/// Whether a Cloud Functions error [code] leaves an `analyseFinding`
/// outcome unknown. Anything not clearly a backend-originated rejection
/// is treated as unknown: replaying the same key is always safe, while
/// wrongly treating an unknown outcome as definitive could lead to a
/// second charge on the next Retry.
bool analyseFindingOutcomeUnknownForCode(String code) => switch (code) {
  'invalid-argument' ||
  'permission-denied' ||
  'unauthenticated' ||
  'failed-precondition' ||
  'not-found' ||
  'already-exists' ||
  'resource-exhausted' ||
  'out-of-range' ||
  'unimplemented' ||
  'internal' => false,
  _ => true,
};
