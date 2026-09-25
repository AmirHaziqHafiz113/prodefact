/// Submits newly discovered areas as candidates and reads back the
/// reviewed, approved names (QA #12). Candidates never change the
/// suggested-area catalogue by themselves.
abstract class AreaCandidateService {
  /// Records [rawName] for [propertyType]. Throws if it can't be
  /// delivered right now (offline, signed out, no backend); the caller
  /// keeps it queued and retries later.
  Future<void> submit({required String rawName, required String propertyType});

  /// Approved area names for [propertyType], most-used first. Empty when
  /// none exist or they can't be fetched.
  Future<List<String>> approvedSuggestions(String propertyType);
}
