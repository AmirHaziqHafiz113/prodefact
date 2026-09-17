import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../remote/remote_providers.dart';
import 'fake_billing_service.dart';
import 'firebase_billing_service.dart';

/// The commercial/billing backend. Production builds (Firebase
/// configured) use the real callables in `functions/src/billing/` —
/// see docs/commercial_model.md. When Firebase isn't configured
/// (local-only mode, or most tests), this falls back to the
/// deterministic fake so the commercial UI stays fully usable/testable
/// offline — mirrors `aiInspectionServiceProvider` in `ai_providers.dart`.
final billingServiceProvider = Provider<BillingService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return FakeBillingService();
  return FirebaseBillingService();
});

/// The customer-safe pricing/AI-level/House Pass config that powers
/// Wallet/Top Up/Choose AI Plan — see `getCommercialConfig`.
final commercialConfigProvider = FutureProvider.autoDispose<CommercialConfig>((
  ref,
) {
  return ref.watch(billingServiceProvider).getCommercialConfig();
});
