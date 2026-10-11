/// One read-only Token cost record — what one operation (e.g. one AI
/// analysis) cost, split into the categories the Usage screen shows.
/// Mirrors `UsageRecord` in `functions/src/billing/usage_cost.ts`; the
/// raw Firebase/OpenAI figures stay server-side.
class UsageRecordSummary {
  const UsageRecordSummary({
    required this.id,
    required this.operationType,
    required this.tokensCharged,
    required this.aiAnalysisTokens,
    required this.storageTokens,
    required this.processingTokens,
    required this.otherTokens,
    required this.createdAt,
    this.inspectionId,
    this.findingId,
  });

  final String id;

  /// `aiAnalysis`, `storage`, `pdfGeneration` or `other`.
  final String operationType;

  /// Whole Tokens actually charged (0 when included in a House Pass).
  final int tokensCharged;

  /// [tokensCharged] split by category — always sums to it.
  final int aiAnalysisTokens;
  final int storageTokens;
  final int processingTokens;
  final int otherTokens;
  final DateTime createdAt;
  final String? inspectionId;
  final String? findingId;
}
