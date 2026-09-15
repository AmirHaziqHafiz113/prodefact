import 'package:firebase_analytics/firebase_analytics.dart' as fa;

import '../../core/inspection/services/analytics_service.dart';
import '../../core/logging/app_logger.dart';

/// [AnalyticsService] backed by Firebase Analytics. This is the only
/// file that imports `package:firebase_analytics` — everything else
/// depends on the [AnalyticsService] interface.
///
/// A logging failure (offline, Analytics disabled at the OS level,
/// etc.) is caught and swallowed — analytics is inherently best-effort
/// and must never surface an error to the inspector or interrupt their
/// workflow.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({fa.FirebaseAnalytics? analytics})
    : _analytics = analytics ?? fa.FirebaseAnalytics.instance;

  final fa.FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    try {
      await _analytics.logEvent(name: event.name);
    } catch (error) {
      AppLogger.warning('Analytics event failed to log', error);
    }
  }
}
