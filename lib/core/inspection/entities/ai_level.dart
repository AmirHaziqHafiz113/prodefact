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

/// The AI level every normal field analysis uses in V1. Fast and Expert
/// stay fully supported (pricing, provider mappings, backend) but are
/// never offered per finding — the inspector saves a finding and Smart
/// AI runs. See the QA/QC pass (QA #24).
const AiLevel kFieldAnalysisAiLevel = AiLevel.smart;
