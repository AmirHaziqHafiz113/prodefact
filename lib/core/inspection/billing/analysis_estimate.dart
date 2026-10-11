import '../entities/ai_level.dart';
import '../entities/commercial_mode.dart';

/// Why an [AnalysisEstimate] is not currently eligible — plain-language
/// mapping happens at the UI layer; this stays a closed set so a new
/// backend reason string can never silently fall through as
/// unexplained. See docs/commercial_model.md.
enum EstimateIneligibleReason {
  insufficientTokens,
  housePassAllowanceReached,
  housePassNotActive,

  /// A reason string the backend sent that this build doesn't
  /// recognize yet — never invented, always surfaced as "can't analyse
  /// right now" rather than a specific (possibly wrong) explanation.
  unknown,
}

/// The result of `estimateFindingAnalysis` — a price check only. Never
/// implies AI ran or anything was reserved. `estimatedTokens`/
/// `maximumTokens` are a ceiling ("Up to N Tokens"), never a false-
/// precise exact number, since the real cost is unknowable before the
/// request runs. See docs/commercial_model.md ("The estimate ->
/// approval -> reservation -> settlement protocol").
class AnalysisEstimate {
  const AnalysisEstimate({
    required this.aiLevel,
    required this.estimatedTokens,
    required this.maximumTokens,
    required this.currentBalance,
    required this.paymentMode,
    required this.includedInHousePass,
    required this.surchargeTokens,
    required this.eligible,
    this.reason,
  });

  final AiLevel aiLevel;
  final int estimatedTokens;
  final int maximumTokens;
  final int currentBalance;

  /// The commercial mode this estimate was actually priced under — may
  /// differ from the inspection's own `commercialMode` (e.g. a House
  /// Pass with its allowance reached falls back to `flexCredits` for
  /// this one analysis; never re-derived client-side).
  final CommercialMode paymentMode;
  final bool includedInHousePass;
  final int surchargeTokens;
  final bool eligible;
  final EstimateIneligibleReason? reason;
}
