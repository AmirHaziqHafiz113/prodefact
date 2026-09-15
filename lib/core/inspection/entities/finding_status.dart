/// The lifecycle state of a [Finding] during physical inspection.
///
/// Every finding recorded during physical inspection is a draft. AI
/// review (Phase 6) tracks its own accepted/edited/rejected states
/// separately, on `AiSuggestion.status` — a finding itself doesn't
/// change status just because its suggestion was reviewed.
enum FindingStatus { draft }
