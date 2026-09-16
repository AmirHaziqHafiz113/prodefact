import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';

/// The on-device inspector profile — see `UserProfile`. Loaded once and
/// manually invalidated after a save (the same pattern
/// `sessionSummariesProvider` uses elsewhere), since the underlying
/// Drift row isn't watched reactively.
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(inspectionRepositoryProvider).loadUserProfile();
});
