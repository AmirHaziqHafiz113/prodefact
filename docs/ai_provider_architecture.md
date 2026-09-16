# AI Provider Architecture (Phase 9)

ProDefact's AI review (see `docs/ai_review.md` for the timing rule and
inspector review lifecycle) is now backed by a real, provider-neutral
backend. This document covers the backend gateway, the active DeepSeek
provider, how to swap or add providers later, secret handling, the
callable function's behavior, and known capability limitations.

## Architecture

```
Flutter (FirebaseAiInspectionService)
  -> FirebaseFunctions.instanceFor(region: "asia-southeast1")
       .httpsCallable("analyzeInspection")
  -> Cloud Function `analyzeInspection` (functions/src/index.ts)
       - requires Firebase Authentication
       - validates payload size/shape (functions/src/ai/validation.ts)
       - resolves the active provider (functions/src/ai/gateway.ts)
       - calls the provider adapter (functions/src/ai/deepseek_provider.ts)
       - validates/normalizes the provider's response (gateway.ts)
  -> Flutter maps the validated JSON into AiAnalysisResponse/
     AiFindingSuggestion (existing domain types) — no Firebase or
     provider-specific type ever reaches lib/core or lib/features
```

`lib/data/ai/firebase_ai_inspection_service.dart` is the only Flutter
file that imports `cloud_functions`; `AiInspectionService` (the domain
interface) is unchanged from Phase 6 — swapping between the fake and
the real implementation is purely `aiInspectionServiceProvider`
(`lib/data/ai/ai_providers.dart`) choosing one or the other based on
`firebaseReadyProvider`, exactly like every other Firebase-backed
feature in the app.

## Backend gateway (`functions/src/ai/`)

```
functions/src/ai/
  types.ts               — shared request/response shapes
  provider.ts             — AiProvider interface + AiProviderError
  gateway.ts               — provider selection + output validation
  deepseek_provider.ts     — real, active DeepSeek adapter (multimodal)
  evidence.ts              — secure, server-side evidence photo resolution
  openai_provider.ts       — clean stub for a future OpenAI integration
  gemini_provider.ts       — clean stub for a future Gemini integration
  anthropic_provider.ts    — clean stub for a future Anthropic integration
  validation.ts            — input validation / abuse guardrails
```

`AiProvider` (`provider.ts`):

```ts
interface AiProvider {
  readonly id: string;
  readonly supportsImages: boolean;
  analyzeInspection(
    input: AnalyzeInspectionInput,
    images: FindingImages[]
  ): Promise<AnalyzeInspectionResult>;
}
```

`images` is always passed to every adapter, even a text-only one (which
simply ignores it via its own `supportsImages: false`) — this keeps
every adapter's method signature identical regardless of capability, so
a future multimodal provider is a drop-in swap, not a contract change.
`analyzeInspection` (`index.ts`) depends only on this interface via
`gateway.createProvider(providerId, apiKey)` — it never references
DeepSeek (or any other provider) by name outside of that one gateway
call and the secret binding.

### Provider selection

`gateway.resolveProviderId(process.env)` reads an `AI_PROVIDER`
environment/function-config value (`deepseek` | `openai` | `gemini` |
`anthropic`), defaulting to `deepseek` if unset or unrecognized.
Flutter never sees or chooses this — it's a server-side decision only,
exactly as requested.

### Active provider: DeepSeek (multimodal — text + images)

`deepseek_provider.ts` calls **`deepseek-flash`**, DeepSeek's current
multimodal chat model — it accepts both text and image input in the
same request, verified directly against DeepSeek's official API
reference at the time this was implemented (not assumed from an older
model name). This replaced the earlier text-only `deepseek-chat`
integration.

Request shape, per finding: a text block with the finding's structured
context (area, element, component, inspector description/notes,
whether the area is a plumbing area), followed by zero or more
`image_url` content blocks — one per resolved evidence photo, sent as
a `data:<mime>;base64,...` URL (see "Secure evidence delivery" below;
no photo is ever fetched by DeepSeek from a URL ProDefact hosts).
Supported formats: JPEG, PNG, GIF, WebP (matching what
`evidence.ts`/`sharp` will decode and normalize).

- `temperature: 0.2` — low, for consistent, non-creative output.
- `response_format: {type: "json_object"}` — structured JSON output.
- A strict system prompt that states the contract (exactly one
  suggestion per requested `findingId`, JSON-only, advisory-only,
  grounded in the supplied context and photos, conservative when
  uncertain) **and** explicitly instructs the model to distinguish, in
  its notes, what is directly visible in a photo from what is inferred
  from context, and to say so rather than invent a defect when a photo
  is unclear, irrelevant, corrupted, or missing. A finding with no
  usable photo is explicitly marked as such in the request so the model
  relies on the inspector's text alone rather than guessing.
- A 45-second request timeout via `AbortController` (raised from the
  earlier text-only phase's 30s to accommodate image processing).
- One bounded retry, and only for a *transient* failure (network error,
  our own timeout, HTTP 5xx/429) — a 4xx validation-style failure or a
  malformed-output failure (bad JSON, no suggestions array) is never
  retried, since retrying would just fail identically. Covered directly
  by `functions/src/ai/deepseek_provider.test.ts` (fake `fetch`,
  no live DeepSeek calls).
- Structural validation of the raw response before it's trusted at all:
  must be a JSON object, must have a `suggestions` array, and each
  entry must at least have a string `findingId` — anything else is
  dropped or the whole call fails with a clear `AiProviderError`.

### Swapping DeepSeek for OpenAI (example)

1. `firebase functions:secrets:set OPENAI_API_KEY`
2. Bind it in `index.ts` the same way `DEEPSEEK_API_KEY` is bound
   (`defineSecret`, add to the `onCall({secrets: [...]})` list).
3. Implement `OpenAiProvider.analyzeInspection` in
   `functions/src/ai/openai_provider.ts` against the Chat Completions
   (or Responses) API with structured JSON output, following
   `DeepSeekProvider`'s shape: timeout, bounded retry on transient
   errors only, strict validation before returning.
4. Add the `"openai"` case to `gateway.createProvider` (already
   present) and pass it the new secret's value from `index.ts`.
5. Set `AI_PROVIDER=openai` for the function (environment variable or
   `firebase functions:config`/2nd-gen equivalent).

Adding Gemini or Anthropic later follows the identical pattern — see
the doc comment at the top of `gemini_provider.ts`/
`anthropic_provider.ts` for the provider-specific starting points
(Gemini's JSON-mode/`responseSchema`; Anthropic's Messages API with
tool-use or a strict prompt contract for structured output).

**No fake credentials exist for these stubs** — each one throws a
clear "not yet implemented/configured" error if ever invoked, and none
of the four adapters can be reached unless its secret is actually
bound and `AI_PROVIDER` selects it.

## Secret handling

The only real AI provider secret (`DEEPSEEK_API_KEY`) lives in Google
Cloud Secret Manager, bound to the function via
`defineSecret("DEEPSEEK_API_KEY")` and `onCall({secrets: [deepseekApiKey]})`
— it is fetched at invocation time (`deepseekApiKey.value()`), never
logged, and never returned to the client. It does not exist anywhere in
Flutter source, `pubspec.yaml`, `firebase.json`, or any committed file.

`console.error` calls in `index.ts` log only the provider id and error
message (`error.message`), never the API key, never the raw request/
response body.

## Callable function behavior (`analyzeInspection`)

- **Auth required**: `request.auth == null` → `HttpsError('unauthenticated', ...)`
  before any provider is ever invoked — an unauthenticated caller can
  never consume paid AI resources. Flutter surfaces this as "Sign in to
  use AI analysis." (`friendlyMessageForFunctionsError`).
- **Input validation / abuse protection** (`validation.ts`):
  - `findings` must be a non-empty array, ≤ 60 entries per request.
  - Every short field (ids, area/element/component names) ≤ 200 chars;
    `description`/`notes` ≤ 4,000 chars each.
  - A duplicate `findingId` within one request is rejected outright.
  - A malformed entry (wrong type, missing required field) is rejected
    with a clear `invalid-argument` error, never a crash.
  - `evidenceCount` is clamped to a sane range rather than trusted
    as-is.
- **Cost/scale bounds**: `setGlobalOptions({maxInstances: 10})` caps
  concurrent instances; `timeoutSeconds: 180` and `memory: "512MiB"`
  (raised from the text-only phase's 60s/256MiB to accommodate
  downloading, decoding, and resizing several evidence photos per
  request) bound per-invocation cost. Evidence is only ever resolved
  for a provider that can use it (`provider.supportsImages`) — no
  wasted Storage reads/CPU for a text-only provider. Per-finding (4) and
  per-request (24) evidence caps plus bounded resolution concurrency
  (4 at a time) keep both request size sent to DeepSeek and function
  memory/CPU use predictable regardless of how many photos an inspector
  attached. The client-side idempotency/duplicate-run guards from Phase
  8 (`DefaultAiReviewCoordinator`'s in-flight lock, and its refusal to
  re-run analysis once suggestions already exist) mean AI analysis is
  never re-triggered on a screen rebuild or a double-tap — a request
  only reaches the function when the inspector deliberately starts or
  retries analysis, and the strict gating described in
  `docs/ai_review.md` means it's never reachable until every included
  area is complete.
- **Response validation**: `gateway.validateAndNormalize` rejects a
  suggestion referencing a `findingId` that wasn't in the request,
  drops a duplicate `findingId` (first occurrence wins), and coerces a
  non-string field to `undefined` rather than propagating a malformed
  value — the callable's response is always well-shaped even if the
  provider's raw output wasn't.
- **Errors mapped to stable codes**: a transient provider failure
  (timeout/network/5xx) maps to `deadline-exceeded`; anything else maps
  to `internal` — the client never sees a raw provider error string.

## Flutter AI service behavior (`FirebaseAiInspectionService`)

Handles every failure mode gracefully, always as a thrown `Exception`
with a friendly message (caught by `DefaultAiReviewCoordinator`, which
marks `aiReviewState: failed` without touching any inspection data —
see `docs/ai_review.md`'s retry policy):

| Condition | Message shown |
|---|---|
| Signed out | "Sign in to use AI analysis." |
| No internet / callable unreachable | "AI analysis is unavailable right now. Check your connection and try again." |
| Timeout | "AI analysis timed out. Please try again." |
| Rate limited | "AI analysis is temporarily rate-limited. Please try again shortly." |
| Malformed provider output | "AI returned an unexpected response shape." |
| Anything else | "AI analysis failed. Please try again." |

The request/response mapping (`buildAnalyzeInspectionPayload`,
`parseAnalyzeInspectionResponse`, `friendlyMessageForFunctionsError`)
is factored into top-level, side-effect-free functions specifically so
it's unit-testable without a live callable — see
`test/data/firebase_ai_inspection_service_test.dart`.

**Element/component pinning**: the callable's `suggestedElement`/
`suggestedComponent` are human-readable names, not the app's internal
element/component ids. `FirebaseAiInspectionService` deliberately keeps
each returned suggestion pinned to the *original* finding's
element/component id (matched back by `findingId`) rather than trying
to resolve the AI's name back to an id — AI is advisory on the defect/
recommendation, never on where a finding structurally lives.

## Image/evidence capability

**The DeepSeek integration is multimodal, not text-only** — as of the
`deepseek-flash` upgrade, findings' photos are analyzed alongside their
structured text context. `AiFindingContext.evidenceIds` (Flutter) and
`FindingInput.evidenceIds` (functions) carry opaque evidence ids only;
Flutter never sends a Storage path, a download URL, or image bytes —
the callable resolves each id to an actual image itself, entirely
server-side.

### Secure evidence delivery (never a client-supplied path)

Flutter's payload includes only `evidenceIds: string[]` per finding —
opaque ids already known to belong to that finding locally. The
callable (`ai/evidence.ts`) does the rest, and never trusts anything
about *where* the corresponding photo lives from the client:

1. For each `(findingId, evidenceId)`, it derives the Storage object
   path itself: `users/{callerUid}/inspections/{inspectionId}/findings/
   {findingId}/{evidenceId}.jpg` — always built from the authenticated
   caller's own `uid` (from verified `request.auth`, never from the
   payload) plus the request's own `inspectionId`/`findingId`. A client
   cannot make the function read anyone else's evidence, or evidence
   from a different inspection, no matter what it sends.
2. It independently re-verifies ownership via a Firestore existence
   check at `users/{callerUid}/inspections/{inspectionId}/findings/
   {findingId}/evidence/{evidenceId}` before ever touching Storage —
   belt-and-suspenders on top of deriving the path from the caller's
   own uid in the first place.
3. It downloads the Storage object directly via the Admin SDK
   (server-side credentials; no signed URL is ever generated, and no
   evidence object is ever made publicly readable).
4. The downloaded bytes are decoded, validated, and normalized (see
   "Image preprocessing" below) before being base64-embedded directly
   in the DeepSeek request as a `data:` URL — the image never touches
   any third-party storage or URL that DeepSeek fetches from.

An evidence id with no matching synced photo (never synced to the
cloud, or since deleted) simply resolves to `null` for that image and
is skipped — it does not fail the finding or the request. This is also
why the multimodal upgrade is fully backward-compatible with a session
that has never been synced to the cloud: it just gets text-only
analysis, identical to the pre-upgrade behavior.

### Image preprocessing (`resolveEvidenceImage`, via `sharp`)

Every resolved photo is decoded and re-encoded before it ever reaches
DeepSeek — a derived copy only; the original Storage object and the
original local file are never modified:

- **Orientation**: auto-rotated from EXIF so a photo taken sideways
  isn't analyzed sideways.
- **Resize**: downscaled to fit within 1568px on the long edge (a
  practical ceiling past which more resolution doesn't meaningfully
  help a vision model, while keeping request size and cost bounded).
- **Format normalization**: re-encoded to JPEG (quality 82) regardless
  of the original format — so DeepSeek always receives one consistent,
  predictable format even though inspectors' photos may be JPEG, PNG,
  GIF, or WebP.
- **Corruption handling**: if `sharp` cannot decode the downloaded
  bytes at all (corrupted upload, truncated transfer, non-image file),
  `resolveEvidenceImage` returns `null` for that image rather than
  throwing — the finding proceeds with its remaining photos (or
  text-only, if that was its only one).

### Multiple photos, with server-side limits (`resolveAllEvidence`)

- Up to **4 resolved images per finding**, and **24 per request**
  overall — an excessively long `evidenceIds` array beyond either cap
  is truncated, not rejected outright, so a request with too many
  photos still returns a partial, useful analysis.
- Resolution runs with **bounded concurrency (4 at a time)** — so a
  finding with many photos doesn't spike memory/CPU or DeepSeek request
  size all at once.
- Partial evidence failure (some ids resolve, others don't) never fails
  the finding or the whole request — see `evidence.test.ts` for direct
  coverage of duplicate/missing/corrupted/unsynced evidence ids.

### Provider-neutral by design

The gateway's `AiProvider` interface and `AnalyzeInspectionInput`/
`FindingImages` shapes are intentionally provider-neutral — a future
multimodal provider (an OpenAI GPT-4o-class model, Gemini, or a current
Claude model) is added as a new adapter implementing the same
`analyzeInspection(input, images)` signature and its own
`supportsImages: true`, without changing the callable's contract,
`AiInspectionService`, evidence resolution, or any Flutter domain type.
A text-only stub adapter simply declares `supportsImages: false` and
the callable never bothers resolving evidence for it at all.

## Testing

Normal test runs never call DeepSeek or any live provider, and never
touch real Cloud Storage/Firestore:

- `functions/src/ai/gateway.test.ts` / `validation.test.ts` — pure unit
  tests (`node --test`, via `npm run test` in `functions/`) covering
  provider selection defaults, output validation/normalization
  (unknown/duplicate `findingId`, non-string field coercion), and input
  validation (size limits, malformed payloads, `evidenceIds` shape and
  per-finding cap).
- `functions/src/ai/deepseek_provider.test.ts` — a fake `global.fetch`
  (no live DeepSeek calls) exercising a successful multimodal response,
  a 400 (fails immediately, no retry), a 500 and a 429 (retried once),
  a network/abort failure (retried once), malformed/non-JSON model
  output, and an empty model response.
- `functions/src/ai/evidence.test.ts` — hand-rolled fake
  Firestore/Storage clients proving: a real image round-trips through
  decode/rotate/resize/re-encode correctly; an evidence id that isn't
  actually owned by the caller (per the Firestore check) resolves to
  `null`; an id with no synced Storage object resolves to `null`;
  corrupted/undecodable bytes resolve to `null` rather than throwing;
  the resolved path is always derived from uid/inspectionId/findingId/
  evidenceId, never a client-supplied path; the per-finding/per-request
  caps are enforced; partial failure never discards the whole finding.
- `test/data/firebase_ai_inspection_service_test.dart` — Flutter-side
  unit tests for the request payload mapping (confirming `evidenceIds`
  — ids only — are sent, and no local file path/byte ever is), response
  parsing, and error-message mapping, all against in-memory data (no
  `cloud_functions` platform channel involved).
- `test/features/ai_gating_regression_test.dart` — proves photo
  capture, saving/editing a finding, and completing one or every area
  never call the AI provider at all (a spy provider's call count stays
  0 through all of that), and that only the explicit "Start AI
  Analysis" action ever does.
- `test/features/ai_review_provider_test.dart` — confirms an edited
  suggestion's original AI values and the inspector's final/edited
  values both survive a simulated app restart (fresh notifier, reload
  from the same repository).
- `test/security_test.dart` and
  `test/architecture/repository_boundary_test.dart` — confirm the AI
  request excludes account data structurally, and that no provider
  secret/hardcoded bearer token exists in Flutter source (see "Security
  test fix" below).

**Manual/live test path** (not run automatically — no automated test
suite here has taken a real photo through a real device, uploaded it,
and confirmed the deployed function returns a photo-grounded
suggestion; that gap is real and is not closed by any test count in
this document): sign in, complete a physical inspection that includes
at least one finding with an attached photo, complete every included
area, tap "Start AI Analysis," and confirm a real DeepSeek-backed
suggestion appears whose notes actually reference something visible in
the photo (not just the text description). Also manually verify: a
finding with a photo that was never synced to the cloud still produces
a text-only-grounded suggestion without erroring; a finding with
multiple photos is analyzed using more than just the first one. See
`docs/production_readiness.md`'s pilot-readiness checklist and manual
E2E sequence.

## Security-test fix (Firebase client key vs. AI provider secret)

`test/architecture/repository_boundary_test.dart`'s secret scan
previously flagged `lib/firebase_options.dart` because its
`AIzaSy...`-shaped Firebase client API key matched the same pattern
used to catch a leaked Google/AI provider key. This is now fixed
correctly, not weakened broadly:

- The `AIzaSy...` pattern is now checked **only** against
  `firebase_options.dart` as an allowed exception — Firebase's client
  configuration keys are not secrets by Google's own documentation
  (they're meant to ship inside a public app binary) and are expected
  there.
- Every other pattern — OpenAI-style `sk-...` keys, a
  `(OPENAI|GEMINI|ANTHROPIC|DEEPSEEK)_API_KEY = "..."` assignment, and
  a new pattern for a hardcoded `Authorization: Bearer ...` header —
  is still checked **everywhere**, `firebase_options.dart` included.
- A regression test group in the same file
  (`'secret-scan pattern behavior (Part J regression coverage)'`)
  exercises each pattern directly against representative strings, so
  a future edit to the scan can't silently reintroduce either failure
  mode (over-blocking legitimate Firebase config, or under-blocking a
  real secret).
