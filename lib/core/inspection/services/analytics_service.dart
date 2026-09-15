/// Product-usage milestones ProDefact may report to Firebase Analytics.
///
/// Deliberately a closed, parameter-free set — there is no way to
/// attach arbitrary properties to an event through this interface, by
/// design: it makes it structurally impossible for a call site to
/// accidentally attach a finding description, inspector note, image
/// path, AI raw output, or email address to an analytics event. See
/// `docs/production_readiness.md` ("Analytics policy").
enum AnalyticsEvent {
  inspectionStarted,
  inspectionCompleted,
  aiReviewStarted,
  aiReviewCompleted,
  reportGenerated,
}

/// Reports coarse product-usage milestones only. Kept optional the same
/// way every other Firebase-backed service is: when Firebase isn't
/// configured, the provider falls back to a no-op implementation rather
/// than the app requiring Analytics to function.
abstract class AnalyticsService {
  Future<void> logEvent(AnalyticsEvent event);
}
