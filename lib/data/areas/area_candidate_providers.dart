import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/areas/area_candidate_service.dart';
import '../remote/remote_providers.dart';
import 'firebase_area_candidate_service.dart';

final areaCandidateServiceProvider = Provider<AreaCandidateService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) {
    return const UnavailableAreaCandidateService();
  }
  return FirebaseAreaCandidateService();
});

/// Reviewed, approved area names for a property type (QA #12) — offered
/// as quick picks when adding a newly discovered area. Empty offline.
final approvedAreaSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, propertyType) {
      return ref
          .watch(areaCandidateServiceProvider)
          .approvedSuggestions(propertyType);
    });
