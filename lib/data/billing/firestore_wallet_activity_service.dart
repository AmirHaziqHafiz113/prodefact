import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../core/inspection/inspection_domain.dart';

/// Reads the real Credits wallet balance and ledger straight from
/// Firestore — `users/{uid}/wallet/main` and
/// `users/{uid}/walletTransactions`, both owner-readable-only per
/// `firestore.rules` and never client-writable. This is the only file
/// that imports `cloud_firestore` for wallet display concerns, mirroring
/// `FirestoreCloudInspectionRepository`'s own "one file owns the SDK
/// type" convention. See docs/commercial_model.md.
class FirestoreWalletActivityService implements WalletActivityService {
  FirestoreWalletActivityService({fs.FirebaseFirestore? firestore})
    : _firestore = firestore ?? fs.FirebaseFirestore.instance;

  final fs.FirebaseFirestore _firestore;

  @override
  Future<int> loadBalance(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('wallet')
        .doc('main')
        .get();
    if (!snap.exists) return 0;
    final data = snap.data();
    final raw = data?['balanceCredits'];
    return raw is num ? raw.toInt() : 0;
  }

  @override
  Future<List<WalletTransactionSummary>> loadRecentTransactions(
    String uid, {
    int limit = 30,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('walletTransactions')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(_parseTransaction).toList();
  }

  WalletTransactionSummary _parseTransaction(
    fs.QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return WalletTransactionSummary(
      id: doc.id,
      type: _parseType(data['type']),
      direction: data['direction'] == 'credit'
          ? LedgerDirection.credit
          : LedgerDirection.debit,
      amountCredits: (data['amountCredits'] as num?)?.toInt() ?? 0,
      description: data['description'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  WalletTransactionType _parseType(Object? raw) {
    return switch (raw) {
      'topup' => WalletTransactionType.topup,
      'reservation' => WalletTransactionType.reservation,
      'usage' => WalletTransactionType.usage,
      'reservationRelease' => WalletTransactionType.reservationRelease,
      'refund' => WalletTransactionType.refund,
      'adjustment' => WalletTransactionType.adjustment,
      'housePassPurchase' => WalletTransactionType.housePassPurchase,
      _ => WalletTransactionType.unknown,
    };
  }

  /// The backend writes `createdAt` as a raw millisecond-epoch number
  /// (`Date.now()`), not a Firestore `Timestamp` — see `wallet.ts`.
  DateTime _parseTimestamp(Object? raw) {
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is fs.Timestamp) return raw.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
