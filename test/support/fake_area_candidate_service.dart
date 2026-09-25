import 'package:prodefact/core/inspection/areas/area_candidate_service.dart';

/// In-memory [AreaCandidateService] for tests.
class FakeAreaCandidateService implements AreaCandidateService {
  FakeAreaCandidateService({this.approved = const []});

  /// Approved names returned by [approvedSuggestions].
  List<String> approved;

  /// When true, [submit] fails as if offline.
  bool offline = false;

  final List<({String rawName, String propertyType})> submitted = [];

  @override
  Future<void> submit({
    required String rawName,
    required String propertyType,
  }) async {
    if (offline) throw StateError('offline');
    submitted.add((rawName: rawName, propertyType: propertyType));
  }

  @override
  Future<List<String>> approvedSuggestions(String propertyType) async =>
      approved;
}
