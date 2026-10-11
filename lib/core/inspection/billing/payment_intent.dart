/// What a payment intent is for — distinct from [CommercialMode]
/// (`flexCredits`/`housePass`, an inspection's ongoing payment mode):
/// a `topup` intent grants Tokens, a `housePass` intent activates a
/// pass, and neither is ever assumed to have succeeded until a
/// confirmation call actually says so. See docs/commercial_model.md
/// ("Payment architecture").
enum PaymentPurpose { topup, housePass }

/// The result of `createTopUpIntent` — a `pending` intent; no Tokens
/// have been granted yet. `tokensAmount` is shown to the inspector as
/// "You'll receive N Tokens," never computed client-side.
class TopUpIntent {
  const TopUpIntent({
    required this.intentId,
    required this.amountMyr,
    required this.tokensAmount,
  });

  final String intentId;
  final double amountMyr;
  final int tokensAmount;
}

/// The result of `purchaseHousePass` — a `pending` intent; the pass is
/// not active yet.
class HousePassPurchaseIntent {
  const HousePassPurchaseIntent({
    required this.intentId,
    required this.priceMyr,
  });

  final String intentId;
  final double priceMyr;
}

/// The result of `confirmSandboxPayment` — the only path that can turn
/// a pending intent into granted Tokens/an active pass, and only in a
/// debug/test build talking to a backend deployed with
/// `PAYMENTS_MODE=sandbox`. See docs/commercial_model.md ("The
/// sandbox/production boundary").
class SandboxPaymentConfirmation {
  const SandboxPaymentConfirmation({
    required this.purpose,
    required this.newBalance,
    required this.tokensAdded,
  });

  final PaymentPurpose purpose;
  final int newBalance;
  final int tokensAdded;
}
