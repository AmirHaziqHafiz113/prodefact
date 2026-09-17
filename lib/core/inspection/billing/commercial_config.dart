import '../entities/ai_level.dart';

/// One Top Up package option — an RM amount and the Credits it buys,
/// both server-computed (see `getCommercialConfig` /
/// docs/commercial_model.md). Flutter never computes the conversion
/// itself.
class TopUpPackage {
  const TopUpPackage({required this.myr, required this.credits});

  final double myr;
  final int credits;
}

/// The customer-safe description of one AI quality tier — a label, a
/// plain-language description, and the "up to N Credits" ceiling for
/// this level under the *current* commercial mode/config. Never a
/// provider name or model id.
class AiLevelInfo {
  const AiLevelInfo({
    required this.level,
    required this.label,
    required this.description,
    required this.maximumCredits,
  });

  final AiLevel level;
  final String label;
  final String description;
  final int maximumCredits;
}

/// The customer-safe House Pass summary.
class HousePassInfo {
  const HousePassInfo({
    required this.enabled,
    required this.priceMyr,
    required this.includedAiLevel,
    required this.allowanceFindings,
    required this.isProductionReady,
  });

  final bool enabled;
  final double priceMyr;
  final AiLevel includedAiLevel;
  final int allowanceFindings;

  /// False means the allowance/pricing behind this House Pass is a
  /// clearly-labeled test value, not a real commercial decision — see
  /// docs/commercial_model.md ("Unfinished decision"). The UI should
  /// visibly flag this rather than presenting House Pass as a finished
  /// commercial product.
  final bool isProductionReady;
}

/// The full customer-safe pricing/AI-level/House Pass configuration —
/// everything Flutter needs to render Wallet/Top Up/Choose AI Plan
/// without ever computing a price itself. Powers `getCommercialConfig`.
class CommercialConfig {
  const CommercialConfig({
    required this.creditsPerMyr,
    required this.lowBalanceThresholdCredits,
    required this.topUpPackages,
    required this.aiLevels,
    required this.housePass,
  });

  final int creditsPerMyr;
  final int lowBalanceThresholdCredits;
  final List<TopUpPackage> topUpPackages;
  final List<AiLevelInfo> aiLevels;
  final HousePassInfo housePass;
}
