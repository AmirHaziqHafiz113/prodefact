import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../billing/billing_providers.dart';
import '../local/database_providers.dart';
import '../remote/remote_providers.dart';
import 'fake_ai_inspection_service.dart';
import 'firebase_ai_inspection_service.dart';
import 'priced_ai_classification_coordinator.dart';

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

/// The priced coordinator — every AI run since the commercial pass
/// reserves/settles real Credits server-side (see
/// docs/commercial_model.md). The older, unpriced
/// `DefaultAiClassificationCoordinator` (backed by
/// [aiInspectionServiceProvider]) still exists and is still tested, but
/// nothing in the app wires it up as the live pipeline any more.
final aiClassificationCoordinatorProvider =
    Provider<AiClassificationCoordinator>((ref) {
      return PricedAiClassificationCoordinator(
        localRepository: ref.watch(inspectionRepositoryProvider),
        billingService: ref.watch(billingServiceProvider),
      );
    });
