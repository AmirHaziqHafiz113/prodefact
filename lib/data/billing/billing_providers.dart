import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../remote/remote_providers.dart';
import 'fake_billing_service.dart';
import 'firebase_billing_service.dart';
import 'firestore_house_pass_status_service.dart';
import 'firestore_wallet_activity_service.dart';

/// The commercial/billing backend. Production builds (Firebase
/// configured) use the real callables in `functions/src/billing/` —
/// see docs/commercial_model.md. When Firebase isn't configured
/// (local-only mode, or most tests), this falls back to the
/// deterministic fake so the commercial UI stays fully usable/testable
/// offline — mirrors `aiInspectionServiceProvider` in `ai_providers.dart`.
///
/// A single shared instance (this is a plain, non-autoDispose
/// `Provider`) — important in local-only mode, where the same
/// `FakeBillingService` also backs [walletActivityServiceProvider], so
/// a charge made through one is reflected in the other.
final billingServiceProvider = Provider<BillingService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return FakeBillingService();
  return FirebaseBillingService();
});

/// Read-only wallet balance/ledger access — see
/// `WalletActivityService`'s doc comment for why this is separate from
/// [billingServiceProvider].
final walletActivityServiceProvider = Provider<WalletActivityService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) {
    return ref.watch(billingServiceProvider) as WalletActivityService;
  }
  return FirestoreWalletActivityService();
});

/// Read-only House Pass lifecycle access — see
/// `HousePassStatusService`'s doc comment for why this is separate from
/// [billingServiceProvider].
final housePassStatusServiceProvider = Provider<HousePassStatusService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) {
    return ref.watch(billingServiceProvider) as HousePassStatusService;
  }
  return FirestoreHousePassStatusService();
});

/// The customer-safe pricing/AI-level/House Pass config that powers
/// Wallet/Top Up/Choose AI Plan — see `getCommercialConfig`.
final commercialConfigProvider = FutureProvider.autoDispose<CommercialConfig>((
  ref,
) {
  return ref.watch(billingServiceProvider).getCommercialConfig();
});
