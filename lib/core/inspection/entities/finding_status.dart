/// The lifecycle state of a [Finding] during physical inspection.
///
/// AI review (a later phase) will introduce further states as suggestions
/// are accepted/edited/rejected — see [AiSuggestion]. For now, every
/// finding recorded during physical inspection is a draft.
enum FindingStatus { draft }
