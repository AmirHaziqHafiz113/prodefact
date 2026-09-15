import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/services/analytics_service.dart';
import '../remote/remote_providers.dart';
import 'firebase_analytics_service.dart';

/// No-op [AnalyticsService] used whenever Firebase isn't configured —
/// analytics is purely optional instrumentation and must never be a
/// precondition for using the app.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> logEvent(AnalyticsEvent event) async {}
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return const NoOpAnalyticsService();
  return FirebaseAnalyticsService();
});
