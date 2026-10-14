# AI note authority — terminal QA harness

The harness runs the **production** note → shortlist → prompt → provider →
post-processing chain (`functions/src/ai/pipeline.ts`, the same module
`analyseFinding` uses) from the terminal, so note behaviour can be tested
without building an APK.

Run everything from `functions/`.

## 1. Deterministic note QA (no provider call, no key, free)

    npm run qa:note -- "Wal por skim"
    npm run qa:note -- "door frame dent" "wall" "crack"

Prints the raw/normalised note, confidence level (A component+defect,
B component only, C none), locked component, defect family, shortlist,
cross-component candidate count (must be 0 for a locked note) and the
note-derived AI-failure fallback.

## 2. Live AI QA (ONE paid call)

    npm run qa:ai -- --note "wall poor skim" --image /abs/wall.jpg --level smart

`--level fast|smart|expert` maps to the same provider/model lineup as the app
(`billing/pricing_config.ts`; a Firestore `pricing/config` override, if one is
set in production, is not applied locally).

## 3. Batch / stability QA (PAID — N cases x runs calls)

    npm run qa:ai-batch -- fixtures.json --runs 5 --level smart

Fixture (see `functions/qa/fixtures.example.json`):
`[{"name","note","image","expectedComponent" | "expectedAgreement":"contradicts"}]`.
The expected number of paid calls is printed first. Above 30 calls the run is
refused unless `--allow-large-batch` is given (absolute cap 200); `--max-calls N`
changes the limit; `--dry-run` prints the count and stops. Inconsistent
repeat runs are listed, not hidden.

## Credentials

Never put a key in source. The harness reads `OPENAI_API_KEY` from the
environment, else the project's Secret Manager secret through the signed-in
Firebase CLI (`firebase login`; the same secret the deployed function binds).
The key is held in memory only and is never printed or logged.

## What `analyseFinding` now logs (production)

`provider_usage.diagnostics`: note level, locked component(s)/element(s),
shortlist size/strategy/components, cross-component count, provider-selected
id, whether the provider tried to leave the lock, image/note component,
agreement, post-processing decision, final id, needs-review reason and the
fallback source. Never the note, the image or the prompt.

## When the AI call fails

The error's `details.noteFallback` carries the **note-derived** fallback
(locked component, note-spelled defect first, then that component's other
defects). The app's on-device reading is pinned to the backend by
`functions/src/ai/note_intent.fixture.json` (both test suites).
