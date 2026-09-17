import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../core/inspection/inspection_domain.dart';

/// Reads one inspection's House Pass lifecycle straight from Firestore
/// — `users/{uid}/housePasses` (owner-read-only, never client-writable)
/// and, when no pass exists yet, `users/{uid}/paymentIntents` (same
/// protection) to distinguish "never attempted" from "payment pending"
/// from "payment failed". Mirrors
/// `FirestoreWalletActivityService`'s "one file owns the SDK type"
/// convention. See docs/commercial_model.md.
class FirestoreHousePassStatusService implements HousePassStatusService {
  FirestoreHousePassStatusService({fs.FirebaseFirestore? firestore})
    : _firestore = firestore ?? fs.FirebaseFirestore.instance;

  final fs.FirebaseFirestore _firestore;

  @override
  Future<HousePassSummary> loadHousePassStatus(
    String uid,
    String inspectionId,
  ) async {
    final passSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('housePasses')
        .where('inspectionId', isEqualTo: inspectionId)
        .limit(1)
        .get();

    if (passSnap.docs.isNotEmpty) {
      final data = passSnap.docs.first.data();
      return HousePassSummary(
        status: _parsePassStatus(data['status']),
        priceMyr: (data['priceMyr'] as num?)?.toDouble() ?? 30,
        includedAiLevel: _parseAiLevel(data['includedAiLevel']),
        allowanceUsed: (data['allowanceUsed'] as num?)?.toInt(),
        allowanceLimit: (data['allowanceLimit'] as num?)?.toInt(),
      );
    }

    // No pass yet — check for an in-flight or failed payment intent.
    final intentSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('paymentIntents')
        .where('inspectionId', isEqualTo: inspectionId)
        .where('purpose', isEqualTo: 'housePass')
        .get();

    if (intentSnap.docs.isEmpty) {
      return const HousePassSummary(
        status: HousePassLifecycleStatus.purchaseRequired,
        priceMyr: 30,
      );
    }

    // Most-recently-created intent wins — sorted client-side so this
    // never needs a composite Firestore index (see
    // docs/production_readiness.md, "Required indexes").
    final intents = intentSnap.docs.map((d) => d.data()).toList()
      ..sort(
        (a, b) => (b['createdAt'] as num? ?? 0).compareTo(
          a['createdAt'] as num? ?? 0,
        ),
      );
    final latest = intents.first;
    final intentStatus = latest['status'] as String?;
    final isPending = intentStatus != 'failed' && intentStatus != 'succeeded';

    return HousePassSummary(
      status: intentStatus == 'failed'
          ? HousePassLifecycleStatus.paymentFailed
          : HousePassLifecycleStatus.paymentPending,
      priceMyr: (latest['amountMyr'] as num?)?.toDouble() ?? 30,
      pendingIntentId: isPending
          ? (latest['id'] as String? ?? intentSnap.docs.first.id)
          : null,
    );
  }

  HousePassLifecycleStatus _parsePassStatus(Object? raw) {
    return switch (raw) {
      'active' => HousePassLifecycleStatus.active,
      'allowanceReached' => HousePassLifecycleStatus.allowanceReached,
      'expired' || 'cancelled' => HousePassLifecycleStatus.expiredOrCancelled,
      _ => HousePassLifecycleStatus.active,
    };
  }

  AiLevel? _parseAiLevel(Object? raw) {
    return switch (raw) {
      'fast' => AiLevel.fast,
      'smart' => AiLevel.smart,
      'expert' => AiLevel.expert,
      _ => null,
    };
  }
}
