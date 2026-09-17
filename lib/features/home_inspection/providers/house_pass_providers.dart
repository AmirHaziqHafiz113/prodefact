import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/billing/billing_providers.dart';
import '../../../data/remote/remote_providers.dart';

/// One inspection's House Pass lifecycle — real, server-derived state
/// (see `HousePassStatusService`), never inferred client-side. Keyed by
/// `inspectionId` so switching inspections never shows a stale pass's
/// status.
final housePassStatusProvider = FutureProvider.autoDispose
    .family<HousePassSummary, String>((ref, inspectionId) async {
      final uid = ref.watch(authStateProvider).value?.uid ?? '';
      final summary = await ref
          .watch(housePassStatusServiceProvider)
          .loadHousePassStatus(uid, inspectionId);
      if (summary.status != HousePassLifecycleStatus.purchaseRequired &&
          summary.includedAiLevel != null) {
        return summary;
      }
      // Enrich a not-yet-purchased/pending pass with the customer-safe
      // config's included level and production-readiness flag, so the
      // screen can show "Included AI: Smart" even before a pass exists.
      final config = await ref
          .watch(billingServiceProvider)
          .getCommercialConfig();
      return HousePassSummary(
        status: summary.status,
        priceMyr: config.housePass.priceMyr,
        includedAiLevel:
            summary.includedAiLevel ?? config.housePass.includedAiLevel,
        allowanceUsed: summary.allowanceUsed,
        allowanceLimit:
            summary.allowanceLimit ?? config.housePass.allowanceFindings,
        isProductionReady: config.housePass.isProductionReady,
        pendingIntentId: summary.pendingIntentId,
      );
    });
