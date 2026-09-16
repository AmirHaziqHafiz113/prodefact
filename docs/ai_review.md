# AI Review (Phase 6)

Post-inspection AI review: after physical inspection completes, AI
suggests a defect type, recommendation, and notes for each finding, and
the inspector accepts, edits, or rejects/corrects every suggestion
before the inspection can proceed to reporting. AI is advisory only —
the inspector is always the final authority.

## The AI timing rule

**AI must never analyze photos or findings during physical inspection.**
There is no photo → AI → confirmation → next-finding loop anywhere in
this app. The only sequence that exists is:

```
Physical inspection (capture findings/photos as drafts)
  -> complete ALL included areas
  -> Complete Physical Inspection
  -> only then: AI analysis runs, once, over every finding
  -> inspector reviews every suggestion
  -> Continue to Report (only once every suggestion is resolved)
```

This is enforced in *code*, not just by hiding a button:

- **Application logic**: `AiReviewCoordinator.runAnalysis` checks
  `session.status` first. If it's still `InspectionStatus.inProgress`
  (physical inspection not complete), it returns
  `AiAnalysisResult.notReady()` immediately — no AI call is made, no
  suggestion record is created or touched. Any future caller (a new
  screen, a background job, a test) gets this same controlled result
  rather than being able to bypass the rule.
- **UI/navigation**: the AI Review screen is only reachable by tapping
  "Complete Physical Inspection" on the inspection queue, which is
  itself only enabled once every included area is marked completed
  (`isPhysicalInspectionCompleteProvider`). There's no other route to
  it. Combined with the coordinator's own check, this is defense in
  depth rather than reliance on a single hidden button.

## Architecture

```
UI (AiReviewOverviewScreen, ai_suggestion_review_dialog)
  -> ActiveInspectionSession (Riverpod; startAiAnalysis/accept/edit/reject)
  -> AiReviewCoordinator (interface)
       -> DefaultAiReviewCoordinator (data layer)
            -> InspectionRepository (local, Drift) — reads findings, persists suggestions
            -> AiInspectionService (interface)
                 -> FakeAiInspectionService (data layer, today)
                 -> [future] a backend gateway client
```

Nothing in `lib/core` or `lib/features` imports a concrete AI
implementation or SDK — they depend only on `AiInspectionService` and
`AiReviewCoordinator` (both plain Dart interfaces in
`lib/core/inspection/ai/`). `test/architecture/repository_boundary_test.dart`
asserts this automatically, the same way it already asserted the
Drift/Firebase boundaries in earlier phases.

## Structured input contract (`AiAnalysisRequest`)

One request per analysis run, covering only what's needed and nothing
else — no user account data, no unrelated app state:

```
AiAnalysisRequest
  sessionId, industry, assetTypeId
  findings: [AiFindingContext]
    findingId
    sectionId, sectionName, sectionIsPlumbing
    elementId, elementName
    componentId?, componentName?
    description?           — inspector's finding text
    notes?                 — inspector's notes
    evidenceFilePaths: []   — local paths; a real backend would fetch/
                              inspect these (or their cloud copies) —
                              the fake only uses the *count*, never
                              file contents
```

Only findings that don't already have a suggestion are included in a
given request — this is what makes retrying after a partial/failed run
safe (see Retry, below).

## Structured output contract (`AiAnalysisResponse`)

```
AiAnalysisResponse
  providerId
  suggestions: [AiFindingSuggestion]
    findingId
    elementId?, componentId?, defectType?, recommendation?, notes?
```

The app never parses free-form prose out of a model response. A real
backend gateway is responsible for validating the provider's raw
response against this exact shape before it ever reaches Flutter — see
Production backend design, below.

## Original-vs-corrected data model (`AiSuggestion`)

Every suggestion keeps the AI's original output and the inspector's
final decision as two separate, independently-preserved sets of fields:

```
AiSuggestion
  id, sessionId, findingId, providerId, generatedAt

  suggested* (elementId, componentId, defectType, recommendation, notes)
    — the AI's original output. Never mutated after generation.

  final* (elementId, componentId, defectType, recommendation, notes)
    — what the inspector approved/corrected. Starts out equal to
      suggested* the moment a suggestion is generated.

  status: pending | accepted | edited | rejected
  reviewedAt — null until reviewed
```

- **Accept**: `final*` is set to exactly `suggested*`; `status` becomes
  `accepted`.
- **Edit**: the inspector changes `final*` directly (element, component,
  defect type, recommendation, notes); `suggested*` is untouched;
  `status` becomes `edited`.
- **Reject / Correct**: the inspector disagrees with the AI outright but
  still supplies their own `final*` values (the finding is never simply
  discarded); `suggested*` is untouched; `status` becomes `rejected`.

This is exactly the same "preserve original, never overwrite it"
pattern the app already uses for evidence sync (Phase 5's local
`filePath` vs. cloud `storagePath`) — extended here to AI review.

## Review lifecycle (`AiReviewState`, session-level)

```
notStarted -> analyzing -> readyForReview -> completed
                 |               ^
                 v               |
              failed  ----(retry)-+
```

- `notStarted`: no analysis has ever run for this session.
- `analyzing`: set immediately before calling the AI backend — durable,
  so a crash mid-call leaves a real record of "this was interrupted,"
  not silence.
- `readyForReview`: suggestions exist; at least one is still `pending`.
- `completed`: every suggestion is resolved (accepted/edited/rejected).
  Only from here does `InspectionSession.status` advance to
  `InspectionStatus.aiReviewComplete`, and only from here does
  "Continue to Report" enable.
- `failed`: the last analysis attempt errored before producing any
  suggestions. Retry is always offered.

## Failure / retry behavior

If the AI backend call throws:

- The coordinator catches it, sets `aiReviewState = failed`, and
  returns `AiAnalysisResult.failure(message)`.
- **No local data is touched** — findings, evidence, sections, and any
  suggestions from a *previous* successful run are completely
  unaffected. The whole analysis call is all-or-nothing per run (the
  fake, and any real backend, returns one batch response or throws —
  there's no partial-success-within-one-call state to reconcile).
- Retrying (calling `runAnalysis` again) re-submits only the findings
  that still don't have a suggestion. Findings that already got a
  suggestion from an earlier successful run are excluded from the
  request, so retry can never create a duplicate logical suggestion for
  the same finding.
- Calling `runAnalysis` again once suggestions already exist
  (`readyForReview`/`completed`) is a deliberate no-op
  (`alreadyReviewed`) — it never regenerates over an inspector's
  in-progress or completed review.

## Persistence

Drift schema v3 (see `lib/data/local/database.dart` /
`lib/data/local/tables.dart`):

- `InspectionSessionRows.aiReviewState` — new nullable-with-default
  column on the existing sessions table.
- `AiSuggestionRows` — new table, one row per `AiSuggestion`, with
  separate `suggested*`/`final*` columns, `status`, `providerId`,
  `generatedAt`, `reviewedAt`. Foreign keys cascade from both the owning
  session and the owning finding.

Both are added via `MigrationStrategy.onUpgrade` (`from < 3`) — the
existing v1/v2 database is never dropped or recreated. Suggestions and
review decisions survive navigation, app restart, and resuming a
session, the same way findings and evidence already did from Phase 4
onward.

## Sync

`CloudInspectionRepository.pushAiSuggestion` mirrors one `AiSuggestion`
(including whatever the inspector has reviewed so far) to
`users/{uid}/inspections/{id}/aiSuggestions/{suggestionId}` in
Firestore, keyed by the same stable local id — same idempotency
guarantee as every other synced record. `DefaultSyncCoordinator` pushes
all of a session's `aiSuggestions` alongside its sections/findings/
evidence. AI review is fully usable with Firebase unconfigured or
unreachable — sync is opportunistic and never a precondition for
running analysis, reviewing a suggestion, or continuing to the report.

## Fake/demo AI service

`FakeAiInspectionService` (`lib/data/ai/fake_ai_inspection_service.dart`)
is deliberately named and documented as fake/demo — it is **not**
production AI. It:

- Makes no network call whatsoever.
- Maps each finding's **element name** to a fixed defect
  type/recommendation via a lookup table (e.g. "Floor" → cracked tile;
  "Window" → failed seal), with a generic fallback for anything else.
- Adds a plumbing-area note and an evidence-count note deterministically
  — never randomly — so the exact same finding always produces the
  exact same suggestion. This determinism is what makes it safe to
  assert on directly in tests.
- Is wired in behind `aiInspectionServiceProvider`
  (`lib/data/ai/ai_providers.dart`) — swapping in a real backend later
  is an override of that one provider, not a rework of anything else.

## Production backend gateway (implemented, Phase 9)

The design once described here as "future" is now live:
`FirebaseAiInspectionService` (`lib/data/ai/firebase_ai_inspection_service.dart`)
calls the `analyzeInspection` Firebase callable function
(`functions/src/index.ts`, region `asia-southeast1`), which depends on a
provider-neutral gateway (`functions/src/ai/`) currently backed by
DeepSeek. Full detail — request/response contract, provider swap
process, secret handling, cost/abuse protections — lives in
`docs/ai_provider_architecture.md`; this section only covers how it
plugs into the Flutter-side flow described above.

`aiInspectionServiceProvider` (`lib/data/ai/ai_providers.dart`) selects
`FirebaseAiInspectionService` when Firebase is configured and falls
back to `FakeAiInspectionService` otherwise — the same
"local-first, Firebase optional" pattern used everywhere else in the
app. Nothing about the AI timing rule, the gate, or the
accept/edit/reject review flow changes based on which one is active.

## Future provider interchangeability

Because the whole app depends on `AiInspectionService` (an interface
taking/returning only plain Dart types), swapping providers — or
switching from the fake to a real backend, or from one real backend to
another later — never requires touching `ActiveInspectionSession`,
`AiReviewCoordinator`, the Drift schema, the sync layer, or any UI code.
It's an override of `aiInspectionServiceProvider` alone.
