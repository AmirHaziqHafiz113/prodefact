import '../ai/ai_analysis_response.dart';
import '../entities/ai_level.dart';
import '../entities/commercial_mode.dart';

/// The result of `analyseFinding` — the priced AI classification. Only
/// ever produced after a reservation was made (or, for an included
/// House Pass tier, explicitly skipped) and settled/released
/// server-side; see docs/commercial_model.md.
class AnalyseFindingResult {
  const AnalyseFindingResult({
    required this.aiLevel,
    required this.creditsCharged,
    required this.newBalance,
    required this.paymentMode,
    required this.classification,
  });

  final AiLevel aiLevel;

  /// The real Credits charged for this analysis — 0 for a finding fully
  /// within an active House Pass's included tier.
  final int creditsCharged;
  final int newBalance;
  final CommercialMode paymentMode;
  final AiFindingClassification classification;
}
