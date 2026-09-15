import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../local/database_providers.dart';
import 'default_ai_review_coordinator.dart';
import 'fake_ai_inspection_service.dart';

/// The AI backend. This is the fake/demo implementation until a real
/// backend gateway exists — see `docs/ai_review.md`. Swapping in a real
/// backend later only means overriding this provider; nothing else in
/// the app depends on which implementation is behind it.
final aiInspectionServiceProvider = Provider<AiInspectionService>((ref) {
  return FakeAiInspectionService();
});

final aiReviewCoordinatorProvider = Provider<AiReviewCoordinator>((ref) {
  return DefaultAiReviewCoordinator(
    localRepository: ref.watch(inspectionRepositoryProvider),
    aiService: ref.watch(aiInspectionServiceProvider),
  );
});
