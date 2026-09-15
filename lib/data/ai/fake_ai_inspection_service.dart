import '../../core/inspection/inspection_domain.dart';

/// Deterministic, offline demo/fake [AiInspectionService].
///
/// This is **not production AI** — it never makes a network call and
/// never talks to a real model. It exists so the AI review workflow can
/// be developed, demoed, and tested without a backend gateway. See
/// `docs/ai_review.md` for the production design this stands in for.
///
/// Suggestions are derived purely from each finding's element name (and
/// whether evidence is attached) via a fixed lookup table — the same
/// finding always produces the same suggestion, which is what makes this
/// safe to assert on in tests.
class FakeAiInspectionService implements AiInspectionService {
  static const providerId = 'fake-demo-v1';

  static const Map<String, (String defectType, String recommendation)>
  _defectsByElementName = {
    'Floor': (
      'Cracked/loose floor tile',
      'Replace the affected tile(s) and reseal grout lines.',
    ),
    'Wall': (
      'Surface crack',
      'Monitor for further movement; patch and repaint if stable.',
    ),
    'Ceiling': (
      'Water staining',
      'Investigate the moisture source above before cosmetic repair.',
    ),
    'Door': ('Misaligned door frame', 'Adjust hinges and re-square the frame.'),
    'Window': (
      'Failed window seal',
      'Replace weatherstripping/sealant to restore the weather seal.',
    ),
    'M&E': (
      'Irregularity in mechanical/electrical/plumbing system',
      'Recommend evaluation by a licensed contractor.',
    ),
  };

  static const _defaultDefect = (
    'General wear and deterioration',
    'Recommend further evaluation during the next scheduled inspection.',
  );

  @override
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request) async {
    final suggestions = request.findings.map(_suggestFor).toList();
    return AiAnalysisResponse(providerId: providerId, suggestions: suggestions);
  }

  AiFindingSuggestion _suggestFor(AiFindingContext finding) {
    final (defectType, recommendation) =
        _defectsByElementName[finding.elementName] ?? _defaultDefect;

    final notesParts = <String>[
      if (finding.sectionIsPlumbing)
        'Plumbing-related area — verify no active leakage before closing out.',
      if (finding.evidenceFilePaths.isNotEmpty)
        '${finding.evidenceFilePaths.length} photo(s) reviewed for this finding.',
      if (finding.description == null || finding.description!.trim().isEmpty) 'No inspector description was provided; suggestion is based on element type only.',
    ];

    return AiFindingSuggestion(
      findingId: finding.findingId,
      elementId: finding.elementId,
      componentId: finding.componentId,
      defectType: defectType,
      recommendation: recommendation,
      notes: notesParts.isEmpty ? null : notesParts.join(' '),
    );
  }
}
