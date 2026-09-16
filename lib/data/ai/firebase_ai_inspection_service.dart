import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/inspection/inspection_domain.dart';
import '../../core/logging/app_logger.dart';

/// Region the `analyzeInspection` callable is deployed to — must match
/// `functions/src/index.ts` and `firebase.json`.
const _kFunctionsRegion = 'asia-southeast1';

/// Production [AiInspectionService]: calls the `analyzeInspection`
/// Firebase callable function, which itself depends on a
/// provider-neutral backend gateway (DeepSeek today) — see
/// `docs/ai_provider_architecture.md`.
///
/// This is the only file that imports `cloud_functions` — no Firebase
/// SDK type leaks past it; [analyze] only ever returns/throws plain
/// Dart types the rest of the app already understands. The request/
/// response mapping is factored into top-level, side-effect-free
/// functions below so it can be unit-tested without a live callable —
/// see `test/data/firebase_ai_inspection_service_test.dart`.
class FirebaseAiInspectionService implements AiInspectionService {
  FirebaseAiInspectionService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request) async {
    final callable = _functions.httpsCallable(
      'analyzeInspection',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final Map<String, dynamic> rawResult;
    try {
      final result = await callable.call<Map<String, dynamic>>(
        buildAnalyzeInspectionPayload(request),
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

    return parseAnalyzeInspectionResponse(rawResult, request);
  }
}

/// Builds the JSON payload the `analyzeInspection` callable expects.
/// Only redacted inspection context — no account/user data.
@visibleForTesting
Map<String, dynamic> buildAnalyzeInspectionPayload(AiAnalysisRequest request) {
  return {
    'inspectionId': request.sessionId,
    'propertyType': request.assetTypeId,
    'findings': request.findings
        .map(
          (finding) => {
            'findingId': finding.findingId,
            'area': finding.sectionName,
            'isPlumbingArea': finding.sectionIsPlumbing,
            'element': finding.elementName,
            if (finding.componentName != null)
              'component': finding.componentName,
            if (finding.description != null) 'description': finding.description,
            if (finding.notes != null) 'notes': finding.notes,
            'evidenceCount': finding.evidenceFilePaths.length,
          },
        )
        .toList(),
  };
}

/// Maps the callable's JSON into the app's typed AI domain objects.
/// Never trusts the shape blindly — a malformed response is surfaced
/// as a clear failure (a thrown [Exception]) rather than a crash.
///
/// The backend's `suggestedElement`/`suggestedComponent` are
/// human-readable names, not the app's internal element/component ids
/// — this app deliberately keeps each finding pinned to the element/
/// component the inspector originally logged it against (AI is
/// advisory on the defect/recommendation, never on where the finding
/// structurally lives), so the response is matched back to the
/// original request's element/component ids by findingId. A
/// suggestion for a findingId that wasn't in the original request is
/// silently dropped — defense in depth on top of the backend
/// gateway's own validation.
@visibleForTesting
AiAnalysisResponse parseAnalyzeInspectionResponse(
  Map<String, dynamic> rawResult,
  AiAnalysisRequest request,
) {
  final rawSuggestions = rawResult['suggestions'];
  if (rawSuggestions is! List) {
    throw Exception('AI returned an unexpected response shape.');
  }

  final findingsById = {
    for (final finding in request.findings) finding.findingId: finding,
  };

  final suggestions = <AiFindingSuggestion>[];
  for (final raw in rawSuggestions) {
    if (raw is! Map) continue;
    final findingId = raw['findingId'];
    if (findingId is! String || findingId.isEmpty) continue;
    final originalFinding = findingsById[findingId];
    if (originalFinding == null) continue;
    suggestions.add(
      AiFindingSuggestion(
        findingId: findingId,
        elementId: originalFinding.elementId,
        componentId: originalFinding.componentId,
        defectType: _asStringOrNull(raw['defectType']),
        recommendation: _asStringOrNull(raw['recommendation']),
        notes: _asStringOrNull(raw['notes']),
      ),
    );
  }

  return AiAnalysisResponse(
    providerId: 'firebase-callable',
    suggestions: suggestions,
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
      return 'This inspection could not be analyzed (invalid data).';
    default:
      return 'AI analysis failed. Please try again.';
  }
}
