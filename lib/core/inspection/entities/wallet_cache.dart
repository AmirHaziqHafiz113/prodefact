/// A local, on-device cache of the last-known Credits wallet balance —
/// purely so the Wallet/Home UI has something to show instantly and
/// offline. **Never authoritative**: the backend ledger
/// (`users/{uid}/walletTransactions`) is always the source of truth for
/// any pricing/charging decision; this cache exists only for display,
/// refreshed opportunistically whenever a commercial callable returns a
/// fresh balance. See docs/commercial_model.md.
class WalletCache {
  const WalletCache({required this.balanceCredits, required this.updatedAt});

  final int balanceCredits;
  final DateTime updatedAt;
}
