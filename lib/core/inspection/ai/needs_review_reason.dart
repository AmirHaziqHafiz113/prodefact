/// Plain-language wording for why a result needs the inspector (the
/// backend's controlled `needsReviewReason`), or null for an unknown or
/// absent reason — technical codes are never shown as-is.
String? needsReviewReasonText(String? reason) => switch (reason) {
  'low_confidence' => "AI wasn't confident enough to decide on its own.",
  'note_image_contradiction' => "The photo doesn't seem to match the note.",
  'image_quality' => 'The photo was hard to read.',
  'unrelated_image' => "The photo doesn't look like an inspection photo.",
  'no_catalogue_match' =>
    'No catalogue defect clearly fits — pick one, or use Add New if the '
        'part (e.g. a railing) is not in the catalogue.',
  'component_mismatch' =>
    'The defect AI picked is for a different part than the one in the photo.',
  'ambiguous_candidates' => 'A few defects could fit — please confirm one.',
  _ => null,
};
