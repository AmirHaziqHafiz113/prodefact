# AI Provider Architecture

ProDefact's AI is **progressive and per-finding**: as soon as the
inspector saves a camera-first finding (photo + optional note), it is
queued for classification against a **controlled defect catalogue** —
never batched until the whole physical inspection is done, and never
free-text. This document covers the controlled catalogue, the backend
gateway, the active DeepSeek provider, secret handling, the callable
function's behavior, and known limitations. See
`docs/home_inspection_workflow.md` for the end-to-end camera-first flow
and `docs/ai_review.md` for the inspector review lifecycle.

## Architecture

```
Flutter: ActiveInspectionSession.saveCameraFinding()
  -> queues classification (fire-and-forget, non-blocking)
  -> FirebaseAiInspectionService.classifyFinding()
       -> FirebaseFunctions.instanceFor(region: "asia-southeast1")
            .httpsCallable("classifyFinding")
  -> Cloud Function `classifyFinding` (functions/src/index.ts)
       - requires Firebase Authentication
       - validates the payload (functions/src/ai/validation.ts)
       - resolves the active provider (functions/src/ai/gateway.ts)
       - resolves evidence photos server-side (functions/src/ai/evidence.ts)
       - calls the provider adapter (functions/src/ai/deepseek_provider.ts)
       - validates the response against the controlled catalogue (gateway.ts)
  -> Flutter maps the validated JSON into AiFindingClassification
     (existing domain type) — no Firebase or provider-specific type
     ever reaches lib/core or lib/features
```

`lib/data/ai/firebase_ai_inspection_service.dart` is the only Flutter
file that imports `cloud_functions`; `AiInspectionService` (the domain
interface) is unaffected by which provider or model sits behind it —
swapping is purely `aiInspectionServiceProvider`
(`lib/data/ai/ai_providers.dart`) choosing the real or fake
implementation based on `firebaseReadyProvider`.

## The controlled defect catalogue

AI does not invent a main element, component, defect, or corrective
action. It selects **one entry, by id**, from a catalogue transcribed
from the authoritative source spreadsheet
("DEFECT_REPORT_LIST.xlsx - DEFECT LIST.pdf"):

```
DefectCatalogueEntry {
  id                  // e.g. "sanitary_fitting.water_tap.03"
  mainElementId       // e.g. "sanitary_fitting"
  mainElementName     // e.g. "Sanitary Fitting"
  componentId         // e.g. "sanitary_fitting.water_tap"
  componentName       // e.g. "Water Tap"
  defectId            // same value as id today
  defectDescription   // e.g. "Water tap is leaking/dripping"
  correctiveAction     // predefined text, or null if the source left
                       // it genuinely blank (never invented)
}
```

**Numbers**: 11 main elements (Door, Window, Wall, Floor, Roof,
Ceiling, Plumbing, Electrical Fitting, Sanitary Fitting, Furniture,
Others), 34 components, **222 defect entries**. "Furniture" and
"Others" exist as main elements with zero components/defects — exactly
as the source document leaves them — so a finding logged there always
resolves to `needsReview`.

### Source of truth and regeneration

`tool/generate_defect_catalogue.py` (repo root) is the **single source
of truth** — a hand-transcribed table plus a generator that emits two
identical outputs from it:

- `lib/core/inspection/entities/defect_catalogue_data.dart`
- `functions/src/ai/defect_catalogue_data.ts`

IDs are derived from **position** (main element index, component
index, defect index), not from slugified text — correcting a typo in a
defect description later never changes its id. Re-run with
`python3 tool/generate_defect_catalogue.py` after editing the table;
both generated files are regenerated together, so Flutter and the
Cloud Function can never disagree about what a given id means.

`DefectCatalogue` (Dart, `lib/core/inspection/entities/
defect_catalogue.dart`) and `defectCatalogue` (TypeScript,
`functions/src/ai/defect_catalogue.ts`) are the queryable wrappers the
rest of each codebase uses — `byId`/`isValidEntryId`,
`forMainElement`/`forComponent`, and (Dart only, for the inspector's
"Change" picker) `search`.

### Integrity tests

`test/data/defect_catalogue_test.dart` (Flutter) and
`functions/src/ai/defect_catalogue.test.ts` (Functions) both assert:
exact counts (11/34/222), every id unique, every entry's component
belongs to a real main element and vice versa, corrective-action
resolution is deterministic by id, `Furniture`/`Others` exist with zero
entries (preserved, not invented), and `isValidEntryId` rejects an
unknown/hallucinated id — the exact guard the callable relies on.

## AI's per-finding classification contract

```ts
// functions/src/ai/types.ts
interface ClassifyFindingInput {
  inspectionId: string;
  findingId: string;
  area: string;
  isPlumbingArea: boolean;
  note?: string;            // the inspector's optional side note
  evidenceIds?: string[];   // opaque ids only — never a path/URL/bytes
}

interface ClassificationResult {
  findingId: string;
  catalogueEntryId?: string; // a real catalogue id, or absent
  confidence?: number;       // 0.0-1.0
  shortReason?: string;      // plain-language, not a technical paragraph
  candidateEntryIds?: string[]; // ranked alternates when uncertain
  needsReview: boolean;      // true whenever catalogueEntryId is absent
}
```

The corrective action, defect description, and main element/component
names are **never** taken from the model — they're always resolved
server-side from `catalogueEntryId` via `defectCatalogue.getById`
(Flutter mirrors this via `DefectCatalogue.instance.byId`). This is
what makes it structurally impossible for AI to alter a corrective
action's meaning: the model only ever chooses *which* predefined
action applies, never *what the action says*.

### Rejecting a hallucinated id

`gateway.validateAndNormalize` (`functions/src/ai/gateway.ts`) is the
one place a model's raw output crosses from "the model said this" to
"the app will act on this":

- `catalogueEntryId` must be `defectCatalogue.isValidEntryId(...)` —
  an unknown/invented id is discarded and the result is forced to
  `needsReview: true` rather than ever reaching the client.
- `candidateEntryIds` are filtered to valid ids only, deduplicated, and
  capped at 5.
- `confidence` is clamped to `[0, 1]`.
- A response whose `findingId` doesn't match the request is rejected
  outright (`needsReview: true`).

The Flutter-side `DefaultAiClassificationCoordinator` independently
re-validates the same way before persisting — defense in depth, not
reliance on the server alone.

## Backend gateway (`functions/src/ai/`)

```
functions/src/ai/
  types.ts                  — shared request/response shapes
  provider.ts                — AiProvider interface + AiProviderError
  gateway.ts                  — provider selection + catalogue-aware validation
  defect_catalogue.ts         — queryable catalogue wrapper
  defect_catalogue_data.ts    — generated catalogue data (see above)
  deepseek_provider.ts        — real, active DeepSeek adapter (multimodal)
  evidence.ts                 — secure, server-side evidence photo resolution
  openai_provider.ts          — clean stub for a future OpenAI integration
  gemini_provider.ts          — clean stub for a future Gemini integration
  anthropic_provider.ts       — clean stub for a future Anthropic integration
  validation.ts                — input validation / abuse guardrails
```

```ts
interface AiProvider {
  readonly id: string;
  readonly supportsImages: boolean;
  classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ClassificationResult>;
}
```

`images` is always passed, even to a text-only stub (which ignores it
via its own `supportsImages: false`) — every adapter's signature stays
identical regardless of capability, so a future multimodal provider is
a drop-in swap, not a contract change. The exported callable
(`classifyFinding` in `index.ts`) depends only on this interface via
`gateway.createProvider(providerId, apiKey)`.

### Provider selection

`gateway.resolveProviderId(process.env)` reads an `AI_PROVIDER`
environment/function-config value (`deepseek` | `openai` | `gemini` |
`anthropic`), defaulting to `deepseek` if unset or unrecognized.
Flutter never sees or chooses this.

### Active provider: DeepSeek (multimodal — text + images)

`deepseek_provider.ts` calls **`deepseek-flash`**, DeepSeek's current
multimodal chat model — verified directly against DeepSeek's official
API reference, not assumed from an older model name.

The system prompt embeds the **full controlled catalogue** as compact
lines (`id | main element | component | defect description` — never
the corrective action, which stays server-side-only) and explicitly
instructs the model to: choose exactly one id from the list, never
invent an id, distinguish what's directly visible in a photo from
inference, and set `needsReview: true` with `catalogueEntryId: null`
rather than guess when the photo is unclear or multiple entries are
plausible.

**Why the full catalogue, not a filtered subset**: sending the entire
catalogue every request seems wasteful, but each request is now for
*one finding*, not a whole session — the absolute cost per request is
already small and bounded. A deterministic subset keyed off the area
name (e.g. "Master Bathroom" → only sanitary fitting entries) risks the
model being unable to find the actually-correct entry for a defect that
doesn't map cleanly to the area's name (a cracked wall tile in a
bathroom, say). Full catalogue, one finding at a time, is the safer
trade-off; a future optimization could add prefiltering if cost
becomes a real constraint.

Request shape, per finding: a text block with the finding's structured
context (area, plumbing flag, inspector note), followed by zero or more
`image_url` content blocks — one per resolved evidence photo, sent as
a `data:<mime>;base64,...` URL (see "Secure evidence delivery" below).
Supported photo formats: JPEG, PNG, GIF, WebP.

- `temperature: 0.2`, `response_format: {type: "json_object"}`.
- A 45-second request timeout via `AbortController`.
- One bounded retry, only for a *transient* failure (network error, our
  own timeout, HTTP 5xx/429) — a 4xx or malformed-output failure is
  never retried. Covered directly by
  `functions/src/ai/deepseek_provider.test.ts` (fake `fetch`, no live
  calls).
- Structural validation of the raw response before it's trusted at
  all — anything malformed fails with a clear `AiProviderError`, which
  `gateway.validateAndNormalize` (catalogue-aware) then further
  narrows.

### Swapping DeepSeek for another provider

1. `firebase functions:secrets:set OPENAI_API_KEY` (or Gemini/
   Anthropic).
2. Bind it in `index.ts` the same way `DEEPSEEK_API_KEY` is bound.
3. Implement `classifyFinding` in the target stub file against that
   provider's structured-output API, following `DeepSeekProvider`'s
   shape (timeout, bounded retry, strict validation) and reusing the
   same catalogue-embedding system prompt approach.
4. Add the case to `gateway.createProvider` (already present) and set
   `AI_PROVIDER` accordingly.

**No fake credentials exist for the stubs** — each throws a clear
"not yet implemented/configured" error if ever invoked.

## Secret handling

The only real AI provider secret (`DEEPSEEK_API_KEY`) lives in Google
Cloud Secret Manager, bound via `defineSecret("DEEPSEEK_API_KEY")` and
`onCall({secrets: [deepseekApiKey]})` — fetched at invocation time,
never logged, never returned to the client, and never exists in
Flutter source, `pubspec.yaml`, `firebase.json`, or any committed file.
`console.error` calls log only the provider id and error message,
never the API key or raw request/response body.

## Callable function behavior (`classifyFinding`)

The `onCall` wrapper in `index.ts` is a thin shell around
`handleClassifyFinding` (`functions/src/handle_classify_finding.ts`),
factored out specifically so the auth gate, evidence-resolution
gating, and error mapping are unit-testable with fake
auth/provider/Firestore/Storage — see
`functions/src/handle_classify_finding.test.ts`.

- **Auth required**: `request.auth == null` → `HttpsError('unauthenticated', ...)`
  before any provider is ever invoked. Flutter surfaces this as "Sign
  in to use AI analysis."
- **Input validation / abuse protection** (`validation.ts`): required
  short fields (`inspectionId`, `findingId`, `area`) length-capped;
  `note` ≤ 4,000 chars; `evidenceIds` capped at 4 entries per finding,
  duplicates dropped, non-string entries rejected.
- **Cost/scale bounds**: `setGlobalOptions({maxInstances: 10})`;
  `timeoutSeconds: 180`, `memory: "512MiB"`. Evidence is only resolved
  for a provider that can use it (`provider.supportsImages`) — no
  wasted Storage reads for a text-only provider. Bounded resolution
  concurrency (4 at a time) and a 4-image-per-finding cap keep both
  request size and function memory/CPU predictable regardless of how
  many photos an inspector attached.
- **Idempotency**: Flutter's `DefaultAiClassificationCoordinator` keys
  each finding's `AiSuggestion` row by a deterministic id
  (`suggestion_<findingId>`), so a retry after a partial/failed attempt
  upserts rather than duplicating, and an in-flight guard
  (`_classifyingFindingIds`) prevents two concurrent classification
  calls for the same finding from racing each other.
- **Response validation**: see "Rejecting a hallucinated id" above.
- **Errors mapped to stable codes**: a transient provider failure
  (timeout/network/5xx) maps to `deadline-exceeded`; anything else maps
  to `internal` — the client never sees a raw provider error string.

## Flutter AI service behavior (`FirebaseAiInspectionService`)

| Condition | Message shown |
|---|---|
| Signed out | "Sign in to use AI analysis." |
| No internet / callable unreachable | "AI analysis is unavailable right now. Check your connection and try again." |
| Timeout | "AI analysis timed out. Please try again." |
| Rate limited | "AI analysis is temporarily rate-limited. Please try again shortly." |
| Malformed provider output | "AI response did not match the requested finding." / similar |
| Anything else | "AI analysis failed. Please try again." |

`buildClassifyFindingPayload`/`parseClassifyFindingResponse`/
`friendlyMessageForFunctionsError` are top-level, side-effect-free
functions — unit-testable without a live callable, see
`test/data/firebase_ai_inspection_service_test.dart`.

## Progressive per-finding AI pipeline (Flutter side)

`ActiveInspectionSession` (`lib/features/home_inspection/providers/
active_session_providers.dart`) owns the whole pipeline:

1. `captureFindingPhoto()` acquires a photo into a **not-yet-created**
   finding — no database row, no AI queuing. The inspector can discard
   it with zero side effects.
2. `saveCameraFinding()` is the **only** place a finding is created and
   the **only** place AI is ever queued (`AiFindingStatus.queued`) —
   never merely from capturing/previewing a photo. See
   `test/features/ai_gating_regression_test.dart`.
3. `_enqueueAiClassification()` runs fire-and-forget, un-awaited, so
   the inspector can immediately take the next photo:
   - If Firebase is configured but the inspector isn't signed in, the
     finding stays `queued` (displayed as "waiting for connection").
   - If Firebase is configured and signed in: `uploading` (evidence is
     synced via the existing sync coordinator) → `analyzing` (the
     callable is invoked) → `completed`/`needsReview` (per the
     response) or `failed` (exception, safe to retry).
   - If Firebase isn't configured at all (local-only/demo builds), the
     fake AI service runs immediately and offline — no upload step.
   - A sync failure (offline) leaves the finding `queued` rather than
     `failed` — nothing about classification itself was attempted yet.
4. `processQueuedAiClassifications()` re-triggers on session resume, so
   work queued before the app was closed (or before connectivity
   returned) continues — driven entirely by durably-persisted
   `aiStatus`/`AiSuggestion` state, never an in-memory-only queue.

### Three separate progress axes

`AiProcessingProgress`, `AiReviewProgress`, and `PhysicalProgress`
(`lib/core/inspection/ai/ai_progress.dart`) are computed independently
and never conflated:

- **Physical progress**: areas marked complete / total included areas.
- **AI processing progress**: findings whose `aiStatus` reached a
  terminal state / total AI-eligible (has ≥1 photo) findings — real,
  count-based, never a fake timer/animation.
- **Review progress**: `AiSuggestion`s resolved (accepted/edited/
  rejected) / total suggestions.

`AiCardSummary.of(session, isOnline: ...)` reduces these to one
dashboard-card state: `none` / `waitingForConnection` / `analysing` /
`needsReview` / `complete` / `failed`.

## Secure evidence delivery (unchanged security model)

Flutter's payload includes only `evidenceIds: string[]` — opaque ids.
`ai/evidence.ts` never trusts anything about *where* the corresponding
photo lives from the client:

1. The Storage path is *derived*, never accepted:
   `users/{callerUid}/inspections/{inspectionId}/findings/{findingId}/
   {evidenceId}.jpg`, built only from the verified `request.auth.uid`
   and the request's own ids.
2. Ownership is independently re-verified via a Firestore existence
   check at the equivalent path before Storage is ever touched.
3. Downloaded directly via the Admin SDK — no signed URL is ever
   generated, and no evidence object is ever made publicly readable.
4. Decoded, validated, and normalized (orientation, resize to ≤1568px
   long edge, re-encoded to JPEG q82, corrupted bytes resolve to `null`
   rather than throwing) before base64-embedding — a derived copy only,
   original Storage object and local file untouched.

An id with no matching synced photo resolves to `null` and is skipped
— never fails the finding. Up to 4 images per finding, resolved with
bounded concurrency (4 at a time). See `functions/src/ai/evidence.test.ts`.

## Testing

Normal test runs never call DeepSeek or touch real Cloud
Storage/Firestore. Functions (`npm run test` in `functions/`, 57
tests): `defect_catalogue.test.ts`, `gateway.test.ts`,
`validation.test.ts`, `deepseek_provider.test.ts` (fake `fetch`),
`evidence.test.ts` (fake Firestore/Storage), and
`handle_classify_finding.test.ts` (fake auth/provider — auth gate,
hallucinated-id rejection, needs_review, timeout/4xx/5xx mapping,
ownership enforcement). Flutter: `test/data/defect_catalogue_test.dart`,
`test/data/firebase_ai_inspection_service_test.dart`,
`test/features/ai_gating_regression_test.dart`,
`test/features/ai_review_provider_test.dart` (original-vs-final
persistence across a simulated restart), `test/data/
ai_review_coordinator_test.dart` (idempotent retry, failure isolation),
`test/security_test.dart` and `test/architecture/
repository_boundary_test.dart` (data minimization, no committed
secret).

**Manual/live test path** (not run automatically — no automated test
here has taken a real photo through a real device, uploaded it, and
confirmed the deployed function returns a photo-grounded
classification): see `docs/production_readiness.md`'s manual E2E
sequence.
