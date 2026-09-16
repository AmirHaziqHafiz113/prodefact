import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../local/database_providers.dart';
import '../remote/remote_providers.dart';
import 'default_ai_review_coordinator.dart';
import 'fake_ai_inspection_service.dart';
import 'firebase_ai_inspection_service.dart';

/// The AI backend. Production builds (Firebase configured) use the
/// real `analyzeInspection` callable — see
/// `docs/ai_provider_architecture.md`. When Firebase isn't configured
/// (local-only mode, or most tests), this falls back to the
/// deterministic fake so AI review stays fully usable/testable
/// offline. Swapping in a different real backend later only means
/// changing what this provider returns; nothing else in the app
/// depends on which implementation is behind it.
final aiInspectionServiceProvider = Provider<AiInspectionService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return FakeAiInspectionService();
  return FirebaseAiInspectionService();
});

final aiReviewCoordinatorProvider = Provider<AiReviewCoordinator>((ref) {
  return DefaultAiReviewCoordinator(
    localRepository: ref.watch(inspectionRepositoryProvider),
    aiService: ref.watch(aiInspectionServiceProvider),
  );
});
