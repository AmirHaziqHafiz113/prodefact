/// The customer-facing AI quality tier — never a raw provider/model name
/// anywhere in Flutter (that mapping is server-side and configurable;
/// see `functions/src/billing/pricing_config.ts` and
/// docs/commercial_model.md, "AI levels and provider mapping").
enum AiLevel {
  /// Lowest cost — good for obvious defects.
  fast,

  /// Recommended — best balance of cost and accuracy.
  smart,

  /// Best for difficult or unclear findings.
  expert,
}

/// The AI level used when the inspector has not chosen one in Profile →
/// AI Analysis Preference (Smart). Fast and Expert are chosen only there,
/// never per finding, at upload, or in the approval dialog.
const AiLevel kFieldAnalysisAiLevel = AiLevel.smart;
