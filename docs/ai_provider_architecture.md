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
  deepseek_provider.ts     — real, active DeepSeek adapter
  openai_provider.ts       — clean stub for a future OpenAI integration
  gemini_provider.ts       — clean stub for a future Gemini integration
  anthropic_provider.ts    — clean stub for a future Anthropic integration
  validation.ts            — input validation / abuse guardrails
```

`AiProvider` (`provider.ts`):

```ts
interface AiProvider {
  readonly id: string;
  analyzeInspection(input: AnalyzeInspectionInput): Promise<AnalyzeInspectionResult>;
}
```

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

### Active provider: DeepSeek

`deepseek_provider.ts` calls `deepseek-chat` (DeepSeek-V3), a stable,
text-capable, JSON-mode model well suited to structured inspection
analysis:

- `temperature: 0.2` — low, for consistent, non-creative output.
- `response_format: {type: "json_object"}` — structured JSON output.
- A strict system prompt that states the contract (exactly one
  suggestion per requested `findingId`, JSON-only, advisory-only,
  grounded in the supplied context, conservative when uncertain).
- A 30-second request timeout via `AbortController`.
- One bounded retry, and only for a *transient* failure (network error,
  our own timeout, HTTP 5xx/429) — a validation failure (bad JSON, no
  suggestions array) is never retried, since retrying would just fail
  identically.
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
  concurrent instances; `timeoutSeconds: 60` and `memory: "256MiB"`
  bound per-invocation cost; the client-side idempotency/duplicate-run
  guards from Phase 8 (`DefaultAiReviewCoordinator`'s in-flight lock,
  and its refusal to re-run analysis once suggestions already exist)
  mean AI analysis is never re-triggered on a screen rebuild or a
  double-tap — a request only reaches the function when the inspector
  deliberately starts or retries analysis.
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

## Image/evidence capability (limitation)

**DeepSeek's `deepseek-chat` model is text-only** — it does not accept
image input. This phase's evidence handling therefore stays consistent
with Phase 6: `evidenceCount` (a number) is sent, never image bytes,
paths, or URLs. No fake/simulated image analysis exists anywhere in the
gateway or the fake service.

The gateway's `AiProvider` interface and `AnalyzeInspectionInput` shape
are intentionally provider-neutral and impose no text-only constraint
themselves — a future multimodal provider (e.g. an OpenAI GPT-4o-class
model, Gemini, or a current Claude model, all of which accept image
input) can be added as a new adapter that additionally sends image
content, without changing the callable's contract, `AiInspectionService`,
or any Flutter domain type. Enabling that would also require deciding
how the backend accesses evidence images (authenticated server-side
read from Cloud Storage after a sync, or a short-lived signed URL) —
evidence Storage objects must never be made public just to enable this,
and local file paths must never be sent to an external provider. This
is documented here as the deliberate scope boundary for this phase, not
an oversight.

## Testing

Normal test runs never call DeepSeek or any live provider:

- `functions/src/ai/gateway.test.ts` / `validation.test.ts` — pure unit
  tests (`node --test`, via `npm run test` in `functions/`) covering
  provider selection defaults, output validation/normalization
  (unknown/duplicate `findingId`, non-string field coercion), and input
  validation (size limits, malformed payloads).
- `test/data/firebase_ai_inspection_service_test.dart` — Flutter-side
  unit tests for the request payload mapping, response parsing, and
  error-message mapping, all against in-memory data (no
  `cloud_functions` platform channel involved).
- `test/security_test.dart` and
  `test/architecture/repository_boundary_test.dart` — confirm the AI
  request excludes account data structurally, and that no provider
  secret/hardcoded bearer token exists in Flutter source (see "Security
  test fix" below).

**Manual/live test path** (not run automatically, requires the real
deployed function and a signed-in test user): sign in, complete a
physical inspection with at least one finding, tap "Start AI Analysis,"
and confirm a real DeepSeek-backed suggestion appears. See
`docs/production_readiness.md`'s pilot-readiness checklist.

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
