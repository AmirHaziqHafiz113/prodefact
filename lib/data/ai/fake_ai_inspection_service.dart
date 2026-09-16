import 'package:collection/collection.dart';

import '../../core/inspection/inspection_domain.dart';

/// Deterministic, offline demo/fake [AiInspectionService].
///
/// This is **not production AI** — it never makes a network call and
/// never talks to a real model. It exists so the camera-first workflow
/// can be developed, demoed, and tested without a backend gateway. See
/// `docs/ai_provider_architecture.md` for the production design this
/// stands in for.
///
/// Classification is derived purely from the area name (and, as a
/// tie-breaker, the inspector's note) via a fixed lookup into the real
/// [DefectCatalogue] — the same finding always produces the same
/// classification, which is what makes this safe to assert on in
/// tests, and it always resolves to a genuinely valid catalogue entry
/// id (never a fabricated one), exactly like the real backend must.
class FakeAiInspectionService implements AiInspectionService {
  static const providerId = 'fake-demo-v2';

  /// Area-name keyword -> main element id, in priority order. The
  /// first match wins; an area matching none of these (or a note
  /// containing no useful signal either) is a deliberate `needsReview`
  /// case, not a forced guess.
  static const List<(String keyword, String mainElementId)> _byAreaKeyword = [
    ('bathroom', 'sanitary_fitting'),
    ('toilet', 'sanitary_fitting'),
    ('kitchen', 'plumbing'),
    ('yard', 'floor'),
    ('balcony', 'floor'),
  ];

  @override
  Future<AiFindingClassification> classifyFinding(
    AiFindingClassificationRequest request,
  ) async {
    final catalogue = DefectCatalogue.instance;
    final areaLower = request.sectionName.toLowerCase();
    final noteLower = request.note?.toLowerCase() ?? '';

    String? mainElementId;
    for (final (keyword, id) in _byAreaKeyword) {
      if (areaLower.contains(keyword)) {
        mainElementId = id;
        break;
      }
    }
    // A plumbing-flagged area with no other keyword match still gets a
    // plumbing-flavored guess rather than falling straight to
    // needsReview, mirroring how a real vision model would weigh
    // context alongside the photo.
    mainElementId ??= request.sectionIsPlumbing ? 'plumbing' : null;

    if (mainElementId == null) {
      return AiFindingClassification(
        findingId: request.findingId,
        needsReview: true,
        shortReason:
            'Could not confidently match this area to a '
            'catalogue main element.',
      );
    }

    final candidates = catalogue.forMainElement(mainElementId);
    if (candidates.isEmpty) {
      return AiFindingClassification(
        findingId: request.findingId,
        needsReview: true,
        shortReason:
            'No catalogue entries exist for this main element '
            'yet.',
      );
    }

    // Deterministic pick: prefer an entry whose defect description
    // shares a word with the inspector's note, else the first entry
    // for that main element.
    final noteWords = noteLower
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    final matched = noteWords.isEmpty
        ? null
        : candidates
              .where(
                (e) => noteWords.any(
                  (w) => e.defectDescription.toLowerCase().contains(w),
                ),
              )
              .firstOrNull;
    final chosen = matched ?? candidates.first;

    return AiFindingClassification(
      findingId: request.findingId,
      needsReview: false,
      catalogueEntryId: chosen.id,
      confidence: matched != null ? 0.82 : 0.55,
      shortReason: matched != null
          ? 'Note mentions symptoms matching this catalogue defect.'
          : 'Best guess based on the area alone; no strong signal in '
                'the note.',
      candidateEntryIds: candidates
          .where((e) => e.id != chosen.id)
          .take(2)
          .map((e) => e.id)
          .toList(),
    );
  }
}
