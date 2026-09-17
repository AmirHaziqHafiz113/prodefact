import 'wallet_transaction.dart';

/// Read-only access to the wallet's real balance and ledger history —
/// separate from [BillingService], which is the *mutating* surface
/// (callables only). Firestore's own rules make `users/{uid}/wallet`
/// and `users/{uid}/walletTransactions` owner-readable directly (never
/// writable by any client — see `firestore.rules`), so the Wallet/Home
/// screens read them straight from Firestore rather than through a
/// callable. See docs/commercial_model.md.
abstract class WalletActivityService {
  /// The real, authoritative current balance — never the local display
  /// cache (`WalletCache`), which exists only for instant/offline
  /// display before this resolves.
  Future<int> loadBalance(String uid);

  /// Most-recent-first ledger entries, for the activity feed and usage
  /// graphs.
  Future<List<WalletTransactionSummary>> loadRecentTransactions(
    String uid, {
    int limit = 30,
  });
}
