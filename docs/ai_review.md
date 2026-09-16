# AI Review

Progressive, per-finding AI classification against a controlled defect
catalogue, plus the inspector's review of each result. AI is advisory
only — the inspector is always the final authority. See
`docs/ai_provider_architecture.md` for the catalogue, provider, and
callable design this sits on top of, and
`docs/home_inspection_workflow.md` for the full camera-first flow.

## The AI timing rule (updated — progressive, not batch)

**AI must never run merely because a photo was captured/previewed, or
a not-yet-saved note is being edited.** It runs — automatically, in the
background — as soon as, and only as soon as, the inspector explicitly
saves a finding:

```
Take Photo -> Preview -> optional side note -> Save Finding
  -> finding persisted locally immediately (offline-first)
  -> AI classification queued (fire-and-forget, non-blocking)
  -> inspector immediately continues to the next photo/area
  -> ... AI classifies this finding in the background, independent of
       whatever area the inspector has moved on to ...
  -> inspector reviews the result whenever they reach the AI Review
     screen (independent of whether every area is physically done)
  -> Continue to Report (only once every area is physically complete,
     no finding is still mid-processing, and no suggestion is pending)
```

This replaces the earlier phase's rule ("AI only runs once the entire
physical inspection is complete") — that gate no longer exists, and
this is a deliberate, explicit product change: AI now works through
Section A's findings while the inspector is already physically
inspecting Section B.

Enforced in code, not just by hiding a button:

- **`ActiveInspectionSession.saveCameraFinding`** is the *only* place a
  camera-first finding is created, and the *only* place
  `_enqueueAiClassification` is ever invoked — capturing or discarding
  a photo, or editing a not-yet-saved note, never reaches it. See
  `test/features/ai_gating_regression_test.dart`.
- **`DefaultAiClassificationCoordinator`** has no physical-inspection
  gate at all (by design) — its only gates are per-finding: the
  finding must have evidence (`isAiEligible`), and it must not already
  be `completed`/`needsReview` (idempotent, never re-runs a settled
  finding without an explicit retry).
- **Report generation** (a separate gate — see "Report readiness"
  below) is what actually requires physical completion, so the product
  invariant "no report with unresolved AI work" still holds even though
  AI itself is no longer gated on physical completion.

## Architecture

```
UI (AreaInspectionScreen, AiReviewOverviewScreen, ai_suggestion_review_dialog)
  -> ActiveInspectionSession (Riverpod)
       saveCameraFinding -> _enqueueAiClassification (fire-and-forget)
       acceptSuggestion / changeSuggestion / rejectSuggestion
  -> AiClassificationCoordinator (interface)
       -> DefaultAiClassificationCoordinator (data layer)
            -> InspectionRepository (local, Drift) — reads the finding,
               persists the suggestion + aiStatus
            -> AiInspectionService (interface)
                 -> FakeAiInspectionService (offline demo) or
                    FirebaseAiInspectionService (real, DeepSeek-backed)
```

Nothing in `lib/core` or `lib/features` imports a concrete AI
implementation or SDK — only `AiInspectionService` and
`AiClassificationCoordinator` (plain Dart interfaces in
`lib/core/inspection/ai/`). `test/architecture/repository_boundary_test.dart`
asserts this automatically.

## Structured input/output (catalogue-based, not free text)

```
AiFindingClassificationRequest
  sessionId, findingId
  sectionName, sectionIsPlumbing
  note?                  — inspector's optional side note
  evidenceFilePaths: []  — local paths; the fake only ever looks at the
                            area name/note, never file contents; the
                            real service sends evidenceIds instead
  evidenceIds: []        — opaque ids only; the callable resolves these
                            to actual images itself, server-side

AiFindingClassification
  findingId
  catalogueEntryId?      — a real DefectCatalogue id, or absent
  confidence?, shortReason?
  candidateEntryIds: []  — ranked alternates when uncertain
  needsReview            — true whenever catalogueEntryId is absent
```

One request per finding — never a whole-session batch. See
`docs/ai_provider_architecture.md` for exactly why the full catalogue
is embedded per request rather than a per-session subset.

## Original-vs-corrected data model (`AiSuggestion`)

```
AiSuggestion
  id, sessionId, findingId, providerId, generatedAt

  suggestedCatalogueEntryId? — AI's original pick. Never mutated after
                                generation. Null means needsReview.
  suggestedConfidence?, suggestedShortReason?, suggestedCandidateEntryIds

  finalCatalogueEntryId?     — what the inspector approved/picked.
                                Null/empty while pending, and also
                                empty after Reject (see below) until
                                the inspector later resolves it via
                                Change.

  status: pending | accepted | edited | rejected
  reviewedAt — null until reviewed
```

- **Accept**: `finalCatalogueEntryId` is set to exactly
  `suggestedCatalogueEntryId`; `status` becomes `accepted`. Only
  offered when AI actually had a confident suggestion.
- **Change**: the inspector picks a different entry via a searchable,
  filterable catalogue picker (`ai_suggestion_review_dialog.dart`) —
  **never free text**; `suggestedCatalogueEntryId` is untouched;
  `status` becomes `edited`. This is also how a `needsReview` finding
  (no AI suggestion at all) gets its first and only classification.
- **Reject / mark unresolved**: the inspector disagrees with the AI (or
  there was nothing to agree/disagree with) and leaves no final
  classification for now; `suggestedCatalogueEntryId` is untouched;
  `status` becomes `rejected`. Still a *resolved*, reviewed state (not
  `pending`) — the report renders it as an explicit "Unresolved —
  pending manual classification" line. The inspector can return later
  and call Change to resolve it.

The corrective action, defect description, and main element/component
names are never stored as free text on the suggestion at all — they're
resolved fresh from `DefectCatalogue`/`defectCatalogue` by
`finalCatalogueEntryId` wherever they're displayed (review screen,
PDF report), so a later catalogue correction is reflected everywhere
without a data migration.

**Legacy note**: a suggestion created under the earlier, pre-catalogue
batch workflow (schema v5 and earlier) instead has
`legacyFinalElementId`/`legacyFinalDefectType`/
`legacyFinalRecommendation`/`legacyFinalNotes` — free-text fields
preserved read-only so that inspection's history/report still renders
correctly; no current code path writes them.

## Three separate progress axes — never confused

- **Physical inspection progress**: areas marked complete / total
  included areas (`PhysicalProgress`) — entirely inspector-driven,
  independent of AI.
- **AI processing progress**: findings whose `aiStatus` reached a
  terminal state / total AI-eligible findings (`AiProcessingProgress`)
  — real, count-based ("12 of 19 findings analysed · 63%"), never a
  fake timer.
- **Review progress**: suggestions resolved / total suggestions
  (`AiReviewProgress`).

An inspector can mark every area physically complete while AI is still
working through several findings, and can review already-completed
suggestions while other findings are still `analyzing` — these are
genuinely independent, simultaneously-visible states.

## Per-finding AI status (`AiFindingStatus`)

```
notQueued -> queued -> uploading -> analyzing -> completed
                |                        |
                |                        +-> needsReview
                +--------(sync fails)-----> (stays queued)
                            ^
                         failed (retry available)
```

- `notQueued`: no evidence yet, or a legacy finding from before this
  status existed (backfilled to `completed` at migration time if it
  already had a suggestion — see `docs/production_readiness.md`,
  "Camera-first migration").
- `queued`: waiting to be processed. Displayed as **"waiting for
  connection"** whenever the app is offline/signed out and Firebase is
  configured — queued is queued either way; only the display
  distinguishes why nothing is happening yet.
- `uploading`: evidence is being synced to cloud storage (a
  prerequisite for the real backend to resolve it) — skipped entirely
  in local-only/demo mode, where the fake service runs immediately.
- `analyzing`: the classification request is in flight.
- `completed`: AI produced a confident catalogue match.
- `needsReview`: AI ran but couldn't confidently match a catalogue
  entry — the inspector must classify manually via Change.
- `failed`: the classification attempt itself errored (timeout,
  provider error) — safe and expected to retry; physical inspection
  data is never affected either way.

## Retry / idempotency

- A finding's `AiSuggestion` row uses a deterministic id
  (`suggestion_<findingId>`) — a retry after a partial/failed attempt
  **upserts**, never duplicates.
- `DefaultAiClassificationCoordinator` tracks in-flight findings by id
  — two concurrent classification attempts for the same finding never
  race; the second is a no-op (`alreadyInFlight`).
- A finding stuck at `failed` is retried via
  `ActiveInspectionSession.retryAiClassification` (exposed as a "Retry"
  action on the area screen) or automatically re-attempted the next
  time `processQueuedAiClassifications` runs (e.g. on session resume).
- Adding a *new* photo to an already-`completed`/`needsReview` finding
  re-queues it — new evidence can change the correct classification, so
  it's never silently ignored.

## Report readiness (the gate that remains)

`DefaultReportCoordinator` requires all three axes settled:

1. `session.status != InspectionStatus.inProgress` (physical inspection
   complete).
2. `AiProcessingProgress.inFlight == 0` (no finding still
   queued/uploading/analyzing, and no eligible finding still
   `notQueued`).
3. `AiReviewProgress.pending == 0` (every suggestion resolved — a
   `rejected`/"unresolved" suggestion counts as resolved; only
   `pending` blocks).

See `test/data/report_coordinator_test.dart` for the gate's tests and
`docs/report.md` for how the PDF renders an "Unresolved" finding rather
than blocking generation entirely over one unclassified item.

## Sync

`CloudInspectionRepository.pushAiSuggestion` mirrors one `AiSuggestion`
(catalogue ids + review state) to
`users/{uid}/inspections/{id}/aiSuggestions/{suggestionId}` in
Firestore, keyed by the same stable local id. AI review is fully usable
with Firebase unconfigured or unreachable — sync is opportunistic and
never a precondition for saving a finding, reviewing a suggestion, or
continuing to the report (the report readiness gate above is purely
local-state-based).

## Fake/demo AI service

`FakeAiInspectionService` (`lib/data/ai/fake_ai_inspection_service.dart`)
is deliberately named and documented as fake/demo — **not** production
AI. It makes no network call, and deterministically resolves a real
`DefectCatalogue` entry from area-name keywords (a bathroom/plumbing
area matches sanitary-fitting/plumbing entries) plus a simple
note-keyword tie-break, falling back to `needsReview` when nothing
matches — so it exercises the exact same controlled-catalogue contract
the real backend does, just without a network call.

## Production backend gateway

`FirebaseAiInspectionService` (`lib/data/ai/firebase_ai_inspection_service.dart`)
calls the `classifyFinding` Firebase callable function
(`functions/src/index.ts`, region `asia-southeast1`), backed by a
provider-neutral gateway (`functions/src/ai/`) currently using
DeepSeek's `deepseek-flash` multimodal model. Full detail — request/
response contract, provider swap process, secret handling, evidence
security, cost/abuse protections — lives in
`docs/ai_provider_architecture.md`.

`aiInspectionServiceProvider` (`lib/data/ai/ai_providers.dart`) selects
`FirebaseAiInspectionService` when Firebase is configured and falls
back to `FakeAiInspectionService` otherwise. Nothing about the AI
timing rule, per-finding gating, or the accept/change/reject review
flow changes based on which one is active.
