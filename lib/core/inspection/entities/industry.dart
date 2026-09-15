/// Identifies which industry vertical an [AssetType] and its inspections
/// belong to (e.g. home inspection today, automotive/industrial later).
///
/// Phase 1 only ships [homeInspection]. New industries are added here as
/// the platform grows, without changing the generic inspection engine.
enum Industry {
  homeInspection;

  String get label {
    switch (this) {
      case Industry.homeInspection:
        return 'Home Inspection';
    }
  }
}
