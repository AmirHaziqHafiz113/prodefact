/// Mirrors `WalletTransactionType` in `functions/src/billing/types.ts` —
/// see docs/commercial_model.md ("The wallet ledger").
enum WalletTransactionType {
  topup,
  reservation,
  usage,
  reservationRelease,
  refund,
  adjustment,
  housePassPurchase,

  /// A ledger entry type this build doesn't recognize yet — never
  /// invented; the raw type string is preserved separately for display
  /// if needed.
  unknown,
}

enum LedgerDirection { credit, debit }

/// One read-only, client-safe ledger entry — the Wallet screen's
/// activity feed reads these directly from Firestore (owner-read-only;
/// see `firestore.rules`), never writes them. See
/// docs/commercial_model.md ("The wallet ledger").
class WalletTransactionSummary {
  const WalletTransactionSummary({
    required this.id,
    required this.type,
    required this.direction,
    required this.amountCredits,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final WalletTransactionType type;
  final LedgerDirection direction;
  final int amountCredits;
  final String description;
  final DateTime createdAt;
}
