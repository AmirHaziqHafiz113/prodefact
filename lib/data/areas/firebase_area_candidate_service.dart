import 'package:cloud_functions/cloud_functions.dart';

import '../../core/inspection/areas/area_candidate_service.dart';
import '../../core/logging/app_logger.dart';

/// Production [AreaCandidateService]: the `submitAreaCandidate` and
/// `getAreaSuggestions` callables in `functions/src/areas/`.
class FirebaseAreaCandidateService implements AreaCandidateService {
  FirebaseAreaCandidateService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
  );

  @override
  Future<void> submit({
    required String rawName,
    required String propertyType,
  }) async {
    await _callable('submitAreaCandidate').call<Map<String, dynamic>>({
      'rawName': rawName,
      'propertyType': propertyType,
    });
  }

  @override
  Future<List<String>> approvedSuggestions(String propertyType) async {
    try {
      final result = await _callable('getAreaSuggestions')
          .call<Map<String, dynamic>>({'propertyType': propertyType});
      final names = result.data['names'];
      return names is List ? names.whereType<String>().toList() : const [];
    } catch (error) {
      AppLogger.warning('Could not load area suggestions', error);
      return const [];
    }
  }
}

/// Used when Firebase isn't configured (local-only/demo mode): nothing
/// can be delivered, so candidates stay queued on the device.
class UnavailableAreaCandidateService implements AreaCandidateService {
  const UnavailableAreaCandidateService();

  @override
  Future<void> submit({
    required String rawName,
    required String propertyType,
  }) async {
    throw StateError('Area suggestions are unavailable offline.');
  }

  @override
  Future<List<String>> approvedSuggestions(String propertyType) async =>
      const [];
}
