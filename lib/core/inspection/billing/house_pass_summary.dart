import '../entities/ai_level.dart' show AiLevel;

/// The House Pass lifecycle, as Flutter observes it — a strict superset
/// of the backend's own `HousePassStatus` (`active`/`allowanceReached`,
/// the only two statuses a `HousePass` document is ever actually
/// written with) plus states derived from whether a pass exists at all
/// and its associated payment intent's own status. Never exposed to
/// the UI as a raw enum name — see `house_pass_screen.dart`'s
/// `_statusLabel`/`_statusDescription`.
enum HousePassLifecycleStatus {
  /// No House Pass exists for this inspection, and no payment is in
  /// flight — the starting state.
  purchaseRequired,

  /// A payment intent was created but not yet confirmed.
  paymentPending,

  /// The most recent payment intent for this inspection failed —
  /// distinct from [purchaseRequired] so the UI can offer a clear
  /// "try again" rather than looking like nothing was ever attempted.
  paymentFailed,

  /// A `HousePass` document exists with `status: "active"`.
  active,

  /// A `HousePass` document exists with `status: "allowanceReached"`.
  allowanceReached,

  /// Mirrors the backend's `expired`/`cancelled` — not currently
  /// produced by any code path (no subscription/expiry concept exists
  /// yet), but represented here so the UI has a defined, honest label
  /// rather than crashing if one is ever introduced.
  expiredOrCancelled,
}

/// Everything the House Pass screen needs to render — resolved
/// server-side (see `HousePassStatusService`); Flutter never infers
/// this from local/guessed state.
class HousePassSummary {
  const HousePassSummary({
    required this.status,
    required this.priceMyr,
    this.includedAiLevel,
    this.allowanceUsed,
    this.allowanceLimit,
    this.isProductionReady = false,
    this.pendingIntentId,
  });

  final HousePassLifecycleStatus status;

  /// The House Pass's fixed price — always shown, regardless of
  /// status, so "RM30" stays visible on a pending/failed screen too.
  final double priceMyr;

  /// Only set once a pass exists (`active`/`allowanceReached`) or is
  /// known from the customer-safe config (`purchaseRequired`).
  final AiLevel? includedAiLevel;
  final int? allowanceUsed;
  final int? allowanceLimit;

  /// False means the allowance/pricing behind this House Pass is a
  /// clearly-labeled test value, not a real commercial decision — see
  /// docs/commercial_model.md ("House Pass allowance safety"). Shown
  /// as a small badge, never hidden.
  final bool isProductionReady;

  /// Set only when [status] is [HousePassLifecycleStatus.paymentPending]
  /// — lets the UI resume confirming this exact intent (e.g. the debug
  /// sandbox path) rather than creating a duplicate one.
  final String? pendingIntentId;

  bool get hasAllowanceInfo => allowanceUsed != null && allowanceLimit != null;
}
