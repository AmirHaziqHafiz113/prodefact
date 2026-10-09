# Commercial Model — AI Credits, Flex Credits, House Pass

This document covers ProDefact's commercial layer: the customer-facing
"AI Credits" abstraction, the two ways to pay for AI analysis (Flex
Credits and House Pass), the wallet ledger, the pricing/reservation/
settlement protocol, and the payment architecture (sandbox-only today).
It complements `docs/ai_provider_architecture.md` (which covers the AI
provider gateway itself) and `docs/production_readiness.md`.

**Status: backend and Flutter UI both built; not production-ready.**
The backend (Firestore data model, pricing/wallet/House Pass domain
logic, and the six callables under `functions/src/billing/`, all
covered by unit tests — `npm test` in `functions/`) and the Flutter
commercial UX (splash screen, bottom navigation, Wallet/Top Up/Choose
AI Plan screens, House Pass purchase/status screen, Auto Analyse
toggle, per-finding AI level override, House Pass surcharge UX, Drift
schema v9, and the estimate → approve → analyse flow replacing
auto-AI-on-save) are both implemented and covered by `flutter test`
(291 tests passing at the time of writing). What's **not** done:
`OPENAI_API_KEY` is still unprovisioned in Secret Manager (so
`analyseFinding` cannot actually run in a real deployment yet — see "AI
levels and provider mapping" below), no real payment gateway exists
(Top Up and House Pass purchase only work via the debug-only sandbox
path), the House Pass allowance is still an explicitly-labeled test
value (now backend-enforced — see "House Pass allowance and the
production launch checklist" below — never silently sellable outside
sandbox mode), and none of this has had a real device/manual QA pass.
**This is functionally complete against the fake/local-only backend
and the callables' own test suites, but is not a claim of production
readiness** — see "What's still needed" at the end of this document for
the concrete remaining gaps.

**READY** (built, tested, and does not block deployment once
`OPENAI_API_KEY` and a production House Pass config are provisioned):
wallet ledger and cached balance, Flex Credits estimate → approve →
reservation → settlement protocol, House Pass backend (purchase,
sandbox activation, allowance tracking, production-safety gate), House
Pass Flutter UX (purchase screen, all lifecycle states, re-entry
banner, allowance-reached interrupt), Auto Analyse (default off for
Flex, explicit opt-in, House Pass auto-on, allowance-reached auto-off),
AI tiers (Profile default, per-inspection override, per-finding
override, no raw model ids ever shown), House Pass Expert surcharge UX,
insufficient/zero-Credits UX, Top-Up-returns-to-the-same-finding flow,
Wallet UX (balance, RM equivalent, Top Up, usage graph, customer-safe
transaction descriptions), sandbox payment boundary (compile-time +
backend/environment, both independently tested), OpenAI provider
(current model ids, image support, structured output, timeout/retry,
the `temperature` incompatibility bug found and fixed this pass).

**STILL REQUIRED before a real production launch:** `OPENAI_API_KEY` in
Secret Manager, an explicit production House Pass allowance
(`pricing/config`), a real payment gateway, manual/real-device QA. See
"What's still needed" for the full list.

## Principles

- **Credits, never tokens.** The customer-facing unit is "AI Credits."
  Nothing in Flutter ever computes a price, sees a model name, sees a
  provider name, or sees a raw token count. Every price shown comes
  from a callable (`estimateFindingAnalysis`, `getCommercialConfig`).
- **Backend-authoritative, always.** Flutter cannot grant Credits, edit
  its own balance, activate a House Pass, decide a price, or settle its
  own AI charge. Every one of those happens only inside a Cloud
  Function using the Admin SDK. Firestore rules deny all client writes
  to `wallet/`, `walletTransactions/`, `housePasses/`, `paymentIntents/`,
  `aiJobs/`, and `pricing/` (see `firestore.rules`).
- **Physical inspection is never blocked by commercial state.** A zero
  balance, an exhausted House Pass allowance, or being offline never
  prevents taking photos, saving findings, or completing an inspection.
  Only the *AI analysis* step is commercially gated.
- **Save Finding never spends Credits.** This is the one behavior
  change to the existing flow: saving a finding (photo + note) is
  purely physical and free. AI analysis is a separate, explicit,
  approved step — see "The estimate -> approval -> reservation ->
  settlement protocol" below.

## Credits conversion and markup

Single source of truth: `functions/src/billing/pricing_config.ts`,
`PricingConfig`, stored at Firestore `pricing/config` (read via
`loadPricingConfig`, falling back to `DEFAULT_PRICING_CONFIG` only when
that document has never been written — never silently on a malformed
one, which throws). Production changes to any of the numbers below are
a Firestore document edit, never an app rebuild.

- `creditsPerMyr` — e.g. `100` means **100 Credits = RM1**. Default
  config uses this ratio for RM10 -> 1,000 / RM30 -> 3,000 / RM50 ->
  5,000 / RM100 -> 10,000 Credits (`myrToCredits` in `pricing.ts`).
- `markupMultiplier` — customer price = provider cost × this
  multiplier. The default is `2.0`. **This is a 100% markup over
  provider cost, not 100% gross margin** — gross margin on a 2×
  multiplier is 50% (revenue minus cost, divided by revenue), and this
  document, the code comments in `pricing.ts`, and `PricingConfig`'s own
  doc comment all say so explicitly to avoid that exact mix-up.
- `lowBalanceThresholdCredits` — below this, the (not-yet-built) Wallet/
  Home UI should show a non-blocking low-balance notice.

## Flex Credits vs. House Pass

Two commercial modes, persisted once per inspection as
`InspectionSession.commercialMode` (a Drift-backed field, set once via
the Choose AI Plan step). `computeEstimate` in
`handle_estimate_finding_analysis.ts` is the one place that resolves
which mode actually applies for a given AI analysis, re-derived fresh
on every estimate/analyse call (never cached client-side as
authoritative).

**Flex Credits (pay-per-use).** Every AI analysis reserves and (on
success) charges the real usage-based cost, capped at the shown
estimate. No subscription, no included allowance.

**House Pass (RM30 per property, not unlimited).** A fixed-price
product tied to exactly one inspection (`HousePass.inspectionId`).
Includes one AI level (`HousePassConfig.includedAiLevel`, default
`"smart"`) up to a **fair-use allowance** (`allowanceFindings`, a count
of included findings — deliberately a simple number, not a Credits
budget, so it's easy for a non-technical operator to reason about).
Choosing a level above the included one still charges the surcharge in
Credits (`housePassSurchargeCredits` in `pricing.ts`) — e.g. a pass that
includes Smart but the inspector picks Expert.

**House Pass states** (`HousePassStatus` in `billing/types.ts`):
`paymentRequired` (implicit — no pass doc exists yet) ->
`paymentPending` (a payment intent exists but isn't confirmed) ->
`active` (created only by `handle_confirm_sandbox_payment.ts` /
`createActiveHousePass`, immediately active since payment is confirmed
first) -> `allowanceReached` (flipped automatically by
`recordHousePassUsage` the moment usage hits the limit) -> `expired` /
`cancelled` (not yet driven by any code path this pass — reserved for
future subscription-adjacent lifecycle, out of scope per the exclusion
list below). **The state machine is entirely backend-authoritative** —
Flutter reads a pass's status; it never sets it.

**If the allowance is reached:** `computeEstimate` detects
`!hasRemainingAllowance(pass)` and returns `paymentMode: "flexCredits"`
with `reason: "housePassAllowanceReached"` — the caller falls back to
Flex Credits for that one analysis rather than being blocked.
`handle_analyse_finding.ts` honors this same fallback authoritatively
(it re-derives payment mode itself; it never trusts a client-supplied
mode).

**Unfinished decision — the real House Pass allowance.**
`DEFAULT_PRICING_CONFIG.housePass.allowanceFindings` is `200`, and
`environment` is `"test"`. This is a deliberately generous, clearly
arbitrary test value. `HousePassConfig.environment` exists specifically
so this is never mistaken for a real commercial allowance decision:
`getCommercialConfig`'s response includes
`housePass.isProductionReady: config.housePass.environment ===
"production"`, and `HousePassScreen` visibly flags a non-production
config with "Preview pricing — the final allowance for a real purchase
is still being finalized." **A real production launch requires an
operator to explicitly write a `pricing/config` document with
`environment: "production"` and a deliberately chosen allowance — this
pass makes no attempt to guess what that number should be**, since
that's a business decision, not an engineering one.

**Enforcement, not just labeling.** `isHousePassSafeToSell`
(`pricing_config.ts`) is the actual backend gate:
`handlePurchaseHousePass` calls it before ever creating a payment
intent, and rejects the purchase outright (`failed-precondition`)
whenever `housePass.environment` is still `"test"` **and** this
deployment's own `PAYMENTS_MODE` isn't explicitly `"sandbox"` — the
same boundary `confirmSandboxPayment` already relies on (see
`payments_mode.ts`). A production-facing deployment
(`PAYMENTS_MODE` unset, the real deploy default) can therefore never
silently sell the 200-finding test allowance as if it were real; it
must either explicitly run in sandbox mode (test/QA) or have a real
`environment: "production"` config written first. See
`pricing_config.test.ts` and `handle_purchase_house_pass.test.ts`.

## AI levels and provider mapping

Three customer-facing tiers — `AiLevel = "fast" | "smart" | "expert"`
(`billing/types.ts`). Customers see only `label`/`description`
(`"Fast"`/`"Smart"`/`"Expert"`, from `getCommercialConfig`) — never a
model id or provider name.

Server-side mapping (`AiLevelConfig` in `pricing_config.ts`), verified
against current official OpenAI documentation at the time this pass was
written (**not from training-era model-name knowledge** — the spec
driving this pass was explicit that stale model names must never be
guessed):

| Level  | Provider | Model            | Provider price (input / output, per 1M tokens) |
|--------|----------|------------------|------------------------------------------------|
| Fast   | openai   | `gpt-6-luna`     | $0.10 / $0.50                                  |
| Smart  | openai   | `gpt-6.1-sol`    | $2.00 / $10.00                                 |
| Expert | openai   | `gpt-6.1-sol`    | $2.00 / $10.00                                 |

Lineup v3 (`MODEL_LINEUP_VERSION = 3`), checked against OpenAI's model
pages on 2026-10-01. The requested "GPT-6.1 Luna" and "GPT-6 Terra" do
not exist: Fast uses GPT-6 Luna, and Expert uses GPT-6.1 Sol until a
real Expert model is chosen. `gpt-5.6-terra` is retired from the active
lineup. Smart is the default; each user can change their level in
Profile → AI Analysis Preference.

This mapping lives in `pricing/config` (Firestore), not in Flutter or
even hardcoded permanently in the Functions bundle beyond the
fallback default — changing a model id, or re-verifying it against
OpenAI's docs at a later date, is a config write, never an app rebuild.
The DeepSeek adapter (`ai/deepseek_provider.ts`) is untouched and
remains available as an alternate provider (`AiLevelConfig.provider:
"deepseek"` is a valid config value); OpenAI is primary per this pass's
requirements, implemented in `ai/openai_provider.ts` behind the same
`AiProvider` interface DeepSeek already used, sharing prompt
construction (`ai/prompt.ts`) and retry/timeout handling
(`ai/http_util.ts`) with it byte-for-byte so classification behavior
never quietly differs by provider.

**`OPENAI_API_KEY` is not yet configured in Secret Manager** for
project `prodefact-82bac`. `analyseFinding` (the only callable that
actually spends the OpenAI provider) is fully implemented and tested,
but its own deployment will fail with a clear "secret not found" error
until this is provisioned — see the comment above `openaiApiKey` in
`functions/src/index.ts`. The command to provision it:

```
firebase functions:secrets:set OPENAI_API_KEY --project prodefact-82bac
```

No key has been fabricated anywhere in this codebase. `classifyFinding`
(the pre-existing, unpriced classification path) is unaffected and
keeps using DeepSeek.

Model selection exists at three levels in the domain model: a
per-inspection default (`selectedAiLevel`, chosen once via Choose AI
Plan and persisted on `InspectionSession`), a Profile-level default
(`UserProfile.defaultAiLevel`, offered as the Choose AI Plan screen's
own pre-selected default), and the finding-level value actually sent
with each `analyseFinding` call. All three are built and wired up.

## The estimate -> approval -> reservation -> settlement protocol

This is the behavior change from the existing flow: **Save Finding no
longer auto-triggers AI.** Both the backend and the Flutter integration
are built (see `ActiveInspectionSession.saveCameraFinding`/
`approveAndRunAnalysis`/`estimateFindingAnalysis` in
`active_session_providers.dart`, and the "Analyse" action on an
`AiFindingStatus.awaitingApproval` finding card in
`area_inspection_screen.dart` / `ai_analysis_approval_dialog.dart`):

1. Inspector saves a finding (photo + optional note) — purely physical,
   free, unchanged from before. The finding's `aiStatus` becomes
   `awaitingApproval` (Flex Credits, the default) or `queued` (an
   active inspection with `autoAnalyseEnabled` on — see "Auto
   Analyse" below).
2. Flutter calls `estimateFindingAnalysis` (`inspectionId`, `findingId`,
   `aiLevel`) -> `handle_estimate_finding_analysis.ts`. Verifies
   ownership, resolves the effective commercial mode, and returns an
   `EstimateResult`: `estimatedCredits`/`maximumCredits` (a ceiling from
   each level's conservative token estimates — **never a false-precise
   exact number**, since the real cost is unknowable before the request
   runs), `currentBalance`, `paymentMode`, `includedInHousePass`,
   `surchargeCredits`, and `eligible`/`reason`. This step **never runs
   AI and never reserves anything** — purely informational, shown to
   the inspector as "Up to N Credits" in `_EstimateApprovalDialog`.
3. The inspector explicitly approves (the "Analyse" button on the
   finding card, then "Approve" in the estimate dialog) — or, if
   `estimate.eligible` is false, sees a plain-language reason and,
   for `insufficientCredits`, a direct "Top Up" action.
4. Flutter calls `analyseFinding` with the same request plus a
   **client-generated `idempotencyKey`** (one per approval tap, reused
   verbatim on any retry of that same tap — never regenerated for a
   genuine "Retry" action, which should mint a new key) ->
   `handle_analyse_finding.ts`, which:
   - Re-verifies auth, ownership, and **re-prices from scratch**
     (`computeEstimate` again) — never trusts the estimate the client
     saw earlier, which may be stale.
   - Checks for an existing `aiJobs/{idempotencyKey}` document first —
     if one exists, returns its stored outcome directly without
     touching the wallet or the AI provider again. This is what makes a
     duplicate tap or a Cloud Functions-level retry safe: **the AI job
     itself only ever runs once per idempotency key.**
   - Reserves the maximum Credits (`reserveCredits`) — the full amount
     shown in the estimate, debited from the wallet immediately. For an
     included House Pass tier this reservation is 0 (skipped entirely).
   - Resolves evidence photos and calls the AI provider
     (`provider.classifyFinding`).
   - **On failure:** releases the reservation in full
     (`releaseReservation` — the inspector is charged nothing), records
     a `failed` job doc, and returns a clear "you have not been
     charged, please retry or classify manually" error (mapped to
     `deadline-exceeded` for a timeout/transient failure,
     `internal` otherwise — never a raw provider error message).
   - **On success:** validates the response against the controlled
     catalogue (`validateAndNormalize`, unchanged from the existing
     path), computes the actual charge from the provider's own reported
     token usage (`actualCreditsForUsage` — **never a client-sent
     number**; if a provider genuinely reports no usage, the charge
     conservatively falls back to the full reserved maximum rather than
     guessing), settles the reservation (`settleReservation` — refunds
     the unused portion, and clamps the charge to never exceed what was
     originally reserved/approved even if the computed actual is
     somehow higher), records House Pass usage if applicable
     (`recordHousePassUsage`), and stores a `succeeded` job doc.
5. Flutter shows real, count-based AI status per finding (`awaitingApproval`
   -> `queued` -> `uploading` -> `analyzing` -> `completed`/`needsReview`/
   `failed`, per `AiFindingStatus` in `area_inspection_screen.dart`'s
   `_AiStatusLine`) — **never a fake token-level percentage**, since the
   callable is a single request/response, not a stream. A failed
   analysis offers Retry (a fresh `idempotencyKey`) and Classify
   Manually, exactly like the pre-existing unpriced path did.

**Auto Analyse is always on (2026-10-02).** Tester feedback: automatic
AI analysis is the main reason to use the app, so it is no longer a
setting. `saveCameraFinding` queues AI as soon as a finding has its quick
defect note (QA #16); a finding saved without one waits as
`awaitingApproval` ("Add a quick defect note to start AI") and is queued
the moment the note is added. Older inspections stored with the opt-out
are treated as on (schema v14 sets the column to true, and the queue
drains any finding left waiting for an approval tap). This still goes
through the exact same priced `analyseFinding` protocol above —
"automatic" only means there is no client-side tap, never that
pricing/reservation is bypassed. The estimate/approval dialog
(`ai_analysis_approval_dialog.dart`) is no longer opened from the field
workflow. When a Flex inspection has no Credits, the automatic analysis
fails and the finding shows "AI: Waiting for Credits" with Top Up and
Retry.

**Queue guarantee.** A queued finding always reaches analysing,
completed/auto-accepted, needsReview, or failed (with Retry) without user
action — see `ActiveInspectionSession` ("queue guarantee"): parked
(offline/signed-out) findings wake themselves on a bounded backoff,
sign-in and reconnect drain the queue, a watchdog re-drains anything not
being worked on, uploads time out and retry (bounded), and replays reuse
the idempotency key so nothing is charged twice.

**Report readiness.** One rule (`ReportReadiness`) is shared by the
report gate, the Report screen and AI Review: only the session's current
findings count (never deleted findings, orphan suggestions or stale queue
state), and every one with a photo must be resolved — still analysing,
waiting for a note, failed (Retry or Classify Manually) and pending review
are each reported as what is outstanding.

## The wallet ledger

`functions/src/billing/wallet.ts`. `users/{uid}/wallet/main` is a
transactionally-maintained **cache** of the balance — the actual source
of truth is the append-only ledger at
`users/{uid}/walletTransactions/{id}`. Every mutation
(`recordTopUp`/`reserveCredits`/`settleReservation`/
`releaseReservation`/`recordHousePassPurchase`/`recordAdjustment`) runs
inside a single Firestore transaction that reads the current balance and
writes both the new balance and the ledger entry atomically, and is
keyed by a caller-supplied `idempotencyKey` that becomes the ledger
entry's own document id — a retried call with the same key returns the
existing entry unchanged rather than mutating the balance again.

`WalletTransactionType`: `topup`, `reservation`, `usage`,
`reservationRelease`, `refund`, `adjustment`, `housePassPurchase`. Each
entry records `transactionId`/`userId`/`amountCredits`/`direction`
(`credit`/`debit`)/`type`/`status`/`createdAt`/`updatedAt`, and
optionally `inspectionId`/`findingId`/`aiLevel`/
`relatedTransactionId`/`externalPaymentRef`/`idempotencyKey`/
`description`.

**Settlement model** (why `usage` never independently moves the
balance): a `reservation` debits the full worst-case amount up front.
`settleReservation` credits back any unused portion as a
`reservationRelease` and separately writes a purely informational
`usage` entry recording the real amount actually consumed — `usage`
never itself mutates the balance a second time, since the reservation
already did. A full failure instead releases the *entire* reservation
via `releaseReservation`. `refund`/`adjustment` exist for future manual
corrections (e.g. support-issued goodwill Credits) — not driven by any
automated path yet.

Regression coverage: `functions/src/billing/wallet.test.ts` (reserve/
settle/release math, insufficient-balance rejection, and idempotent-
replay-never-double-moves-balance for every mutation type) and
`functions/src/billing/handle_analyse_finding.test.ts` (the full
protocol above, including the no-charge-on-failure and duplicate-tap
cases end to end).

## Payment architecture

**No real Malaysia payment gateway is configured for this project.**
Per the spec driving this pass, this codebase builds the clean
architecture for one without enabling live payment processing:

```
Client -> createTopUpIntent / purchaseHousePass
            (creates a `pending` users/{uid}/paymentIntents/{id} doc —
             grants nothing yet)
       -> [a real provider's checkout/redirect flow would happen here —
           not implemented]
       -> provider's own webhook verifies payment
            (not implemented — no real provider is configured)
       -> backend confirms -> recordTopUp / createActiveHousePass +
          recordHousePassPurchase (the ONLY paths that ever grant
          Credits or activate a pass)
```

`PaymentService` (`billing/payment_service.ts`) is the abstraction that
seam is built around: `confirmPayment(intent): Promise<{success,
providerRef}>`. `SandboxPaymentService`
(`billing/sandbox_payment_service.ts`) is the **only** implementation
today — it always "succeeds," performing no real verification
whatsoever, which is the entire point of it being sandbox-only. A real
provider's implementation would independently verify the intent was
actually paid (via the provider's API or a signed webhook payload)
rather than trusting the caller.

**The sandbox/production boundary:** `handle_confirm_sandbox_payment.ts`
(the callable `confirmSandboxPayment`) refuses to run at all unless
`resolvePaymentsMode(process.env)` (`billing/payments_mode.ts`) resolves
to `"sandbox"` — which requires the Cloud Function's own
`PAYMENTS_MODE` environment variable to be the **literal string**
`"sandbox"`. **A real deployment must never set this variable.** There
is no client-supplied field, header, or build flavor that can flip this
— it is controlled entirely by the function's own deploy-time
environment, which a client cannot influence. **"Never grant Credits
because the client says payment succeeded"** holds even in sandbox mode:
the client only ever supplies an `intentId`; `SandboxPaymentService`,
not the client, decides success.
`functions/src/billing/handle_confirm_sandbox_payment.test.ts` proves
this boundary directly (confirmation is rejected both when
`PAYMENTS_MODE` is unset — the real deploy default — and when it's set
to any value other than `"sandbox"`).

Flutter's Top Up flow is built (`top_up_screen.dart`): it calls
`createTopUpIntent`, then shows a "Simulate Payment (Debug Only)"
button wrapped in `if (kDebugMode)` — a compile-time constant, so that
branch is not compiled into a release build at all, not merely hidden
behind a runtime flag. In release builds, the screen instead shows
"Online payment isn't available yet." There is no House Pass purchase
screen yet (`purchaseHousePass`/`confirmSandboxPayment` for the
House Pass path are implemented and tested on the backend, but nothing
in Flutter calls them yet) — see "What's still needed."

## Firestore data model

```
users/{uid}/
  wallet/main                    — cached balance (backend-write-only)
  walletTransactions/{id}        — the ledger (backend-write-only)
  housePasses/{id}                — one per inspection (backend-write-only)
  paymentIntents/{id}             — pending/succeeded/failed (backend-write-only)
  aiJobs/{idempotencyKey}         — analyseFinding's idempotency record
  inspections/{id}                — unchanged by this pass
  inspections/{id}/findings/{id}  — unchanged by this pass

pricing/config                    — the single PricingConfig document
                                     (no client read or write at all)
```

All of the above are read-only for their owner (or, for `pricing/`,
unreadable entirely) and write-denied for every client under
`firestore.rules` — every mutation happens exclusively via the Admin
SDK inside a callable, which bypasses rules by design. See the new
`match` blocks added to `firestore.rules` this pass.

## Callables added this pass

All registered in `functions/src/index.ts`, region `asia-southeast1`:

- `estimateFindingAnalysis` — price check, no side effects.
- `analyseFinding` — the priced AI classification (requires
  `OPENAI_API_KEY`; deployment blocked until it's configured).
- `getCommercialConfig` — the customer-safe pricing/AI-level/House Pass
  summary (labels, Credits/MYR conversion, top-up packages, House Pass
  headline price — never a provider name, model id, or cost rate).
- `createTopUpIntent` — RM10/30/50/100/other (bounded RM1–RM1,000),
  creates a `pending` intent.
- `purchaseHousePass` — creates a `pending` intent for one inspection's
  RM30 pass; rejects a duplicate purchase for an inspection that
  already has an active/allowance-reached pass.
- `confirmSandboxPayment` — sandbox-only (see above); the only path
  that turns a pending intent into granted Credits or an active pass.

## Failure, offline, and low-balance behavior

- **Failed AI:** see "On failure" above — reservation released in
  full, no charge, `aiJobs` doc marked `failed`. The (not-yet-built)
  Flutter UI should offer Retry (new idempotencyKey) or Classify
  Manually, never silently retry the same key automatically.
- **Insufficient Credits:** `computeEstimate`/`handle_analyse_finding`
  return `eligible: false` with a plain-language reason before any
  reservation is attempted — physical inspection is never blocked; only
  that one AI analysis is deferred.
- **Offline:** not yet implemented on the Flutter side. The intended
  behavior (per the spec this pass implements against, not yet coded):
  never attempt a Credits reservation while offline, and never treat a
  cached price estimate as authoritative indefinitely — a stale
  estimate should be re-fetched before `analyseFinding` is called, not
  reused across a long offline gap. `estimateFindingAnalysis` and
  `analyseFinding` both already re-derive everything server-side on
  every call, so the backend half of this is naturally correct; what's
  missing is the Flutter-side network-awareness and estimate-freshness
  UI.
- **Low balance:** `lowBalanceThresholdCredits` in `pricing/config`,
  surfaced via `getCommercialConfig` — intended as a non-blocking
  notice on Home/Wallet. Not yet built.

## Security summary

- Wallet balance/ledger/House Pass/payment-intent/AI-job writes: denied
  to every client in `firestore.rules`; only the Admin SDK (inside a
  callable) can write them.
- Pricing config: unreadable and unwritable by any client; every price
  shown to Flutter is computed server-side and returned by a callable.
- Ownership: every callable re-derives ownership from
  `request.auth.uid` and the caller's own `users/{uid}/...` documents —
  never from a client-supplied uid/owner field.
- Idempotency/double-spend: every wallet mutation and the AI job itself
  are keyed by a caller-supplied idempotency key that becomes a
  Firestore document id, so a duplicate tap, a Cloud Functions retry, or
  a replayed call can never double-charge or double-run the AI request.
  Covered by `wallet.test.ts` and `handle_analyse_finding.test.ts`.
- Payment spoofing: a client can create a payment intent but can never
  mark it succeeded — only `SandboxPaymentService` (sandbox-gated) or, in
  the future, a verified real-provider webhook can. Covered by
  `handle_confirm_sandbox_payment.test.ts`.
- Provider cost/model ids: never returned to the client by any
  callable — `getCommercialConfig` returns only labels/descriptions/
  Credits figures.
- Secrets: `OPENAI_API_KEY`/`DEEPSEEK_API_KEY` are Secret-Manager-only
  (`defineSecret`), never logged, never present in Flutter source.

## Explicitly out of scope this pass

Per the spec driving this work: no subscriptions, no auto-reload, no
stored credit cards, no invoicing/accounting suite, no company/team
billing, no defect-taxonomy changes, no PDF redesign, and no real
payment gateway (none was already configured for this project). House
Pass `expired`/`cancelled` states exist in the type but have no driving
code path yet (no subscription/expiry concept exists to drive them).

## What's built on the Flutter side

- **Splash screen** (`splash_screen.dart`) and **bottom navigation**
  (`app_shell_screen.dart`, a `StatefulShellRoute.indexedStack` with
  Home/Inspections/Wallet/Profile branches; "+" pushes New Inspection
  rather than being a fifth branch). The Inspections tab (not Home)
  stays the actual post-launch landing screen — see "Routing audit"
  below for why.
- **Choose AI Plan** step (`choose_ai_plan_screen.dart`), inserted
  between Area Configuration and Review Setup, defaulting to Flex
  Credits / the Profile's `defaultAiLevel` (falling back to Smart).
- **Wallet screen** (balance, this-month stats, a real 7-day
  usage-over-time bar chart, and an activity feed from
  `walletTransactions`) and **Top Up screen** (package/custom amount ->
  `createTopUpIntent` -> the debug-only, `kDebugMode`-gated sandbox
  confirmation path).
- The **estimate -> approve -> analyse** flow fully replaces
  auto-AI-on-save: `AiFindingStatus.awaitingApproval`, the "Analyse"
  action and its estimate/approval dialogs
  (`ai_analysis_approval_dialog.dart`), and the Auto Analyse toggle
  (`ActiveInspectionSession.setAutoAnalyseEnabled`).
- **Real-data graphs**: Home progress rings (physical/AI-analysed/
  reviewed, aggregated across active inspections), Wallet's
  usage-over-time bar chart, and a findings-by-area bar chart on the
  Report screen's readiness card.
- **Drift schema v9** (additive): `commercialMode`/`selectedAiLevel`/
  `autoAnalyseEnabled` on `InspectionSessionRows`, `defaultAiLevel` on
  `UserProfileRows`, and the new `WalletCacheRows` table — a **local
  display cache only**, never the authoritative balance (the backend
  ledger always is; see `walletBalanceProvider`'s doc comment).
- **Profile**: Default AI Level (a `SegmentedButton`, never exposing
  API keys, provider names, or raw model ids).
- New reusable chart widgets (`AppRingProgress`, `AppBarChart`) added
  to the shared design system rather than a new charting dependency.

## Routing audit

> Superseded by `docs/ux_architecture.md` (2026-10): Home is now the
> landing screen, Wallet is a pushed screen, and the bottom nav is
> Home / Inspections / + / Review / Profile. The notes below are kept
> for history.

- The dashboard (Inspections tab) — not Home — remains the app's actual
  landing screen after sign-in/launch, preserving the pre-existing
  "the dashboard is the inspections list" behavior exactly; Home is an
  additive aggregate/wallet-glance tab, one tap away, not a
  replacement. This was a deliberate choice made during this pass (see
  `buildAppRouter`'s doc comment) rather than an oversight.
- Every New Inspection setup screen, physical inspection, AI review,
  and the report all remain top-level routes pushed **outside** the
  bottom-nav shell, so the tab bar is hidden during those focused task
  flows — unchanged from the pre-commercial-pass routing structure,
  now confirmed to still hold with the shell added around it.
- The splash screen's redirect is synchronous (`firebaseReadyProvider`
  and `authServiceProvider.currentUser` are both already resolved by
  the time the router is built, since `main.dart` fully awaits
  `Firebase.initializeApp` first) — see `splash_screen.dart`'s doc
  comment for why a more elaborate async-gated splash was deliberately
  not attempted this pass.
- Not yet audited: deep-linking directly into a specific finding's
  estimate/approval dialog, or into the Top Up flow, from a push
  notification or external link — no such entry points exist yet
  elsewhere in the app either.

## House Pass allowance and the production launch checklist

`DEFAULT_PRICING_CONFIG.housePass.allowanceFindings` is still `200`
with `environment: "test"` — a deliberately generous, clearly arbitrary
test value, never a real commercial decision. As of this pass, that is
no longer just a label: `isHousePassSafeToSell` (`pricing_config.ts`)
is an actual backend gate that `handlePurchaseHousePass` calls before
ever creating a payment intent. It refuses the purchase outright
(`failed-precondition`) whenever `housePass.environment` is still
`"test"` **and** this deployment's own `PAYMENTS_MODE` isn't explicitly
`"sandbox"` — the same boundary `confirmSandboxPayment` already relies
on. A production-facing deployment can therefore never silently sell
the 200-finding test allowance as real; it must either explicitly run
in sandbox mode (test/QA) or have an operator write a real
`pricing/config` document with `environment: "production"` and a
deliberately chosen allowance first. See `pricing_config.test.ts` and
`handle_purchase_house_pass.test.ts`.

## What's still needed

- **`OPENAI_API_KEY`** is still not provisioned in Secret Manager — see
  "AI levels and provider mapping." `analyseFinding` cannot actually
  run AI in a real deployment until this is set; everything else
  (pricing, reservation, settlement, the Flutter UI) is fully built and
  tested against it.
- **A real Malaysia payment gateway** — out of scope per the spec (none
  was already configured); Top Up and House Pass purchase only work via
  the debug-only sandbox path today (both independently protected —
  see "House Pass allowance and the production launch checklist" above
  and `sandbox_payment_boundary_test.dart`).
- **The real House Pass allowance** — still the explicitly-labeled test
  value (`allowanceFindings: 200`, `environment: "test"`); a real
  commercial number is a business decision this pass doesn't attempt.
  Now backend-enforced so it can never launch by accident (see above).
- **Manual/device QA** — this pass validated via `dart format`,
  `flutter analyze`, `flutter test` (291 tests), `flutter build ios
  --simulator --debug`, `flutter build apk --debug`, `flutter build apk
  --release` (and confirmed via the compiled AOT binary's own strings
  that no "sandbox"/"Simulate Payment"/"Debug build" text survives
  release tree-shaking), and the `functions/` suite (lint/build/111
  tests) — never a real device or a human clicking through the
  commercial flows. See docs/production_readiness.md for the standing
  "do not call this production-ready" position this pass doesn't
  change.
- Minor polish gaps: the Flex analysis progress line reads "Preparing
  photo…" → "AI analysing…" → the final classification result — two
  real stages plus the real outcome, not a fabricated third "matching"
  stage, since the backend performs classification as a single
  request/response with no separate matching phase to report on.
