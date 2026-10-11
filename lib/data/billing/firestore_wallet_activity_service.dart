import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../core/inspection/inspection_domain.dart';

/// Reads the real Tokens wallet balance and ledger straight from
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
    return tokenBalanceOf(snap.data());
  }

  @override
  Future<List<UsageRecordSummary>> loadUsageRecords(
    String uid, {
    int limit = 100,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('usageRecords')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final doc in snap.docs) parseUsageRecord(doc.id, doc.data())];
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
      // A legacy entry (written in Credits, before Tokens) keeps its
      // original Credits figure and is never re-priced as Tokens.
      amountTokens: (data['amountTokens'] as num?)?.toInt() ?? 0,
      legacyAmountCredits: data['amountTokens'] == null
          ? (data['amountCredits'] as num?)?.toInt()
          : null,
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
      'legacyMigration' => WalletTransactionType.legacyMigration,
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

/// The legacy Credits-per-RM rate (100 Credits = RM1) — how a wallet
/// written before Tokens converts: 1 Credit = 10,000 Tokens, the same RM
/// value the backend's one-off migration uses.
const kLegacyTokensPerCredit = 10000;

/// A wallet document's balance in Tokens. A wallet the backend hasn't
/// migrated yet (only `balanceCredits`) reads at its Token value, so the
/// inspector never sees a Credits figure labelled as Tokens.
int tokenBalanceOf(Map<String, dynamic>? data) {
  final tokens = data?['balanceTokens'];
  if (tokens is num) return tokens.toInt();
  final credits = data?['balanceCredits'];
  return credits is num ? credits.toInt() * kLegacyTokensPerCredit : 0;
}

/// Parses one `usageRecords` document — only the client-safe summary.
UsageRecordSummary parseUsageRecord(String id, Map<String, dynamic> data) {
  final split = data['tokensByCategory'];
  int part(String key) =>
      split is Map && split[key] is num ? (split[key] as num).toInt() : 0;
  final created = data['createdAt'];
  return UsageRecordSummary(
    id: id,
    operationType: data['operationType'] as String? ?? 'other',
    tokensCharged: (data['tokensCharged'] as num?)?.toInt() ?? 0,
    aiAnalysisTokens: part('aiAnalysis'),
    storageTokens: part('storage'),
    processingTokens: part('processing'),
    otherTokens: part('other'),
    createdAt: created is num
        ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
        : created is fs.Timestamp
        ? created.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0),
    inspectionId: data['inspectionId'] as String?,
    findingId: data['findingId'] as String?,
  );
}
