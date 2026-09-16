import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/inspection/inspection_domain.dart';
import '../../core/logging/app_logger.dart';

/// Region the `classifyFinding` callable is deployed to — must match
/// `functions/src/index.ts` and `firebase.json`.
const _kFunctionsRegion = 'asia-southeast1';

/// Production [AiInspectionService]: calls the `classifyFinding`
/// Firebase callable function once per finding — a provider-neutral
/// backend gateway (DeepSeek today) classifies it against the
/// controlled defect catalogue and returns a catalogue entry id (or
/// `needsReview`) — see `docs/ai_provider_architecture.md`.
///
/// This is the only file that imports `cloud_functions` — no Firebase
/// SDK type leaks past it; [classifyFinding] only ever returns/throws
/// plain Dart types the rest of the app already understands. The
/// request/response mapping is factored into top-level, side-effect-
/// free functions below so it can be unit-tested without a live
/// callable — see `test/data/firebase_ai_inspection_service_test.dart`.
class FirebaseAiInspectionService implements AiInspectionService {
  FirebaseAiInspectionService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<AiFindingClassification> classifyFinding(
    AiFindingClassificationRequest request,
  ) async {
    final callable = _functions.httpsCallable(
      'classifyFinding',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final Map<String, dynamic> rawResult;
    try {
      final result = await callable.call<Map<String, dynamic>>(
        buildClassifyFindingPayload(request),
      );
      rawResult = result.data;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      AppLogger.error('AI callable failed (${error.code})', error, stackTrace);
      throw Exception(friendlyMessageForFunctionsError(error.code));
    } catch (error, stackTrace) {
      AppLogger.error('AI callable failed unexpectedly', error, stackTrace);
      throw Exception(
        'Could not reach AI analysis. Check your connection and try again.',
      );
    }

    return parseClassifyFindingResponse(rawResult, request);
  }
}

/// Builds the JSON payload the `classifyFinding` callable expects. Only
/// redacted inspection context — no account/user data, and no evidence
/// file paths/bytes/URLs, only opaque evidence *ids*: the callable
/// resolves each one to an actual image itself, server-side, scoped to
/// the authenticated caller's own cloud storage — see
/// `docs/ai_provider_architecture.md`. An id with no matching synced
/// evidence is simply skipped server-side rather than failing the
/// request, so this works the same whether or not the finding's
/// photos have been synced to the cloud yet.
@visibleForTesting
Map<String, dynamic> buildClassifyFindingPayload(
  AiFindingClassificationRequest request,
) {
  return {
    'inspectionId': request.sessionId,
    'findingId': request.findingId,
    'area': request.sectionName,
    'isPlumbingArea': request.sectionIsPlumbing,
    if (request.note != null && request.note!.isNotEmpty) 'note': request.note,
    if (request.evidenceIds.isNotEmpty) 'evidenceIds': request.evidenceIds,
  };
}

/// Maps the callable's JSON into the app's typed AI domain object.
/// Never trusts the shape blindly — a malformed response is surfaced
/// as a clear failure (a thrown [Exception]) rather than a crash, and
/// a `findingId` mismatch (the response referring to a different
/// finding than what was requested) is treated the same way: defense
/// in depth on top of the backend gateway's own validation.
@visibleForTesting
AiFindingClassification parseClassifyFindingResponse(
  Map<String, dynamic> rawResult,
  AiFindingClassificationRequest request,
) {
  final findingId = rawResult['findingId'];
  if (findingId != request.findingId) {
    throw Exception('AI response did not match the requested finding.');
  }

  final needsReview = rawResult['needsReview'] == true;
  final catalogueEntryId = _asStringOrNull(rawResult['catalogueEntryId']);
  final rawCandidates = rawResult['candidateEntryIds'];

  return AiFindingClassification(
    findingId: request.findingId,
    needsReview: needsReview || catalogueEntryId == null,
    catalogueEntryId: catalogueEntryId,
    confidence: (rawResult['confidence'] as num?)?.toDouble(),
    shortReason: _asStringOrNull(rawResult['shortReason']),
    candidateEntryIds: rawCandidates is List
        ? rawCandidates.whereType<String>().toList()
        : const [],
  );
}

String? _asStringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A user-facing message for a [FirebaseFunctionsException.code] —
/// never the raw provider/backend error detail.
@visibleForTesting
String friendlyMessageForFunctionsError(String code) {
  switch (code) {
    case 'unauthenticated':
      return 'Sign in to use AI analysis.';
    case 'deadline-exceeded':
      return 'AI analysis timed out. Please try again.';
    case 'resource-exhausted':
      return 'AI analysis is temporarily rate-limited. Please try again '
          'shortly.';
    case 'unavailable':
      return 'AI analysis is unavailable right now. Check your connection '
          'and try again.';
    case 'invalid-argument':
      return 'This finding could not be analyzed (invalid data).';
    default:
      return 'AI analysis failed. Please try again.';
  }
}
