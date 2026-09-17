/// Which way an inspection pays for AI analysis — chosen once via the
/// "Choose AI Plan" step in New Inspection and persisted on the
/// [InspectionSession] for its whole lifetime; never re-derived from the
/// wallet later. See docs/commercial_model.md ("Flex Credits vs. House
/// Pass").
enum CommercialMode {
  /// Pay-per-use: every AI analysis reserves and charges its real
  /// usage-based cost in Credits, with no included allowance.
  flexCredits,

  /// A fixed-price (RM30) product for exactly one inspection: one AI
  /// level included up to a fair-use allowance, with any level above
  /// that surcharged in Credits.
  housePass,
}
