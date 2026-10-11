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

  /// The one-off conversion of a legacy Credits balance to Tokens of the
  /// same RM value. Informational — it moves no balance itself.
  legacyMigration,

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
    required this.amountTokens,
    required this.description,
    required this.createdAt,
    this.legacyAmountCredits,
  });

  final String id;
  final WalletTransactionType type;
  final LedgerDirection direction;

  /// Whole Tokens. For a legacy entry written in Credits this is 0 —
  /// historical Token usage is never invented; see [legacyAmountCredits].
  final int amountTokens;
  final String description;
  final DateTime createdAt;

  /// Set for an entry written before Tokens existed: its original
  /// Credits amount, shown as-is ("1,000 Credits"), never re-priced.
  final int? legacyAmountCredits;

  bool get isLegacyCredits => legacyAmountCredits != null;
}
