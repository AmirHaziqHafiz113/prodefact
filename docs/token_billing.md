# ProDefact Tokens

ProDefact Tokens replace "Credits" as the only customer-facing billing unit.

## Denomination

- **1,000,000 Tokens = RM1 retail value.** RM10 buys 10,000,000 Tokens and RM100
  buys 100,000,000.
- The rate is fixed (`TOKENS_PER_MYR` in `functions/src/billing/tokens.ts`,
  `kTokensPerMyr` in `lib/core/inspection/billing/token_format.dart`). It is not
  operator-configurable, so a Token always means the same money.
- Every balance and charge is a whole number of Tokens, checked with
  `Number.isSafeInteger`. That is exact up to about 9 × 10¹⁵ Tokens (roughly
  RM9 billion). RM cost figures may be fractional, but they are informational
  only; the integer Token amount is the charge. Balances are never floating-point.
- Retail RM converts to Tokens rounded **up**, after snapping to a thousandth of
  a Token so floating-point noise can't add a spurious Token. For example,
  RM0.009146 → 9,146 Tokens.

## Pricing: 100% markup over variable cost

```
retail RM = variable cost RM × markupMultiplier (2.0)
Tokens    = retail RM × 1,000,000
```

A 2.0 multiplier is a **100% markup** (RM1 cost → RM2 charge). That is a 50%
gross margin, not "100% gross margin".

## Variable-cost model (`functions/src/billing/usage_cost.ts`)

| Category (user-facing) | Components | Source |
|---|---|---|
| AI Analysis | OpenAI input/output tokens × the model's per-1K price | **measured** (provider-reported usage) |
| Storage | Storage download bytes (the photo the function reads), retained bytes (one month charged once), upload bytes | download **measured**; retention **estimated** |
| Processing | function invocation, vCPU-seconds and GiB-seconds (wall time × configured tier), image processing, PDF generation | duration **measured**; tier from config |
| Other infrastructure | Firestore reads/writes/deletes for the job lifecycle, network egress to the provider, and a small fixed overhead bucket (logging, monitoring, Secret Manager, platform) | **estimated** (deterministic constants) |

Rules:

- Micro-costs that would be noisy to meter one by one go in the overhead bucket.
  They are not metered individually.
- All unit prices are USD list prices in `infrastructureRates`. They are
  converted with `usdToMyrRate` and can be overridden in `pricing/config`
  without a deploy.
- **Operator action required:** the default `usdToMyrRate` is **1.0**. That keeps
  the pre-Token assumption that USD cost ≈ RM cost, so charges don't jump at
  deploy. Set the real rate in `pricing/config.usdToMyrRate`.
- Reservation ("up to N Tokens") prices the worst case: the level's estimated
  provider tokens plus `ANALYSE_FINDING_WORST_CASE`.
- Settlement charges the actual price, capped at the reservation. A failed
  analysis is released in full and is never charged.

## Usage ledger: `users/{uid}/usageRecords/{usageId}`

`usageId` is the operation's idempotency key, so one operation is recorded (and
charged) once. Each record holds:

- `usageId`, `userId`, `inspectionId`, `findingId`, `operationType`
- `openaiInputTokens`, `openaiOutputTokens`, `openaiModel`, `openaiCostRm`
- `storageUploadBytes`, `storageDownloadBytes`, `storageRetainedBytes`
- `firestoreReads`, `firestoreWrites`, `firestoreDeletes`
- `functionDurationMs`, `networkBytes`
- `infrastructureCostRm`, `markupMultiplier`, `retailCostRm`
- `tokensCharged` (what was actually charged: capped, and 0 when included in a
  House Pass) and `tokensComputed` (the uncapped price)
- `tokensByCategory`: whole Tokens per category that always add up to
  `tokensCharged`
- `measurement`: whether each figure was measured or estimated
- `usdToMyrRate`, `pricingVersion`, `createdAt`

The record is written in the same Firestore transaction as the settlement. A
replayed settlement neither charges nor records twice. Rules: owner read, no
client writes.

The money movements themselves remain in `users/{uid}/walletTransactions`
(reservation, release, usage, top-up, adjustment, House Pass purchase,
`legacyMigration`).

## Migration from Credits

- **Wallet:**
  - A wallet holding only `balanceCredits` reads at its Token value straight away:
    100 Credits = RM1 = 1,000,000 Tokens, so 1 Credit = 10,000 Tokens.
  - The first touch writes `balanceTokens`, keeps `balanceCredits` frozen for
    audit, sets `legacyCreditsMigratedAt`, and records one ledger entry
    (`legacy_credits_to_tokens_v1`, type `legacyMigration`) holding both amounts.
  - "First touch" means `getCommercialConfig` on app start, an estimate, or any
    ledger mutation.
  - Conversion is idempotent.
- **History:** Credits ledger entries are never rewritten or re-priced. The app
  shows them as "N Credits · before Tokens", and no historical Token usage is
  invented.
- **In-flight data:**
  - Pending top-up intents in Credits grant their RM value in Tokens.
  - AI jobs stored with `creditsCharged`/`actualCredits` read at their Token
    value.
  - A pre-Token `pricing/config` keeps its legacy rate and its low-balance
    threshold's RM value.
- **Device cache:** a wallet-cache row cached before Tokens (schema < 18) is
  ignored, so a Credits figure is never shown labelled as Tokens.

`CommercialMode.flexCredits` stays as a stored identifier for data
compatibility. In the UI it means "Pay as you go" (with Tokens).

## Callable response changes (deploy functions and app together)

| Callable | Old field | New field |
|---|---|---|
| `getCommercialConfig` | `creditsPerMyr` | `tokensPerMyr` |
| `getCommercialConfig` | `lowBalanceThresholdCredits` | `lowBalanceThresholdTokens` |
| `getCommercialConfig` | `topUpPackages[].credits` | `topUpPackages[].tokens` |
| `getCommercialConfig` | `aiLevels[].maximumCredits` | `aiLevels[].maximumTokens` |
| `estimateFindingAnalysis` | `estimatedCredits` / `maximumCredits` / `surchargeCredits` | `estimatedTokens` / `maximumTokens` / `surchargeTokens` |
| `estimateFindingAnalysis` | reason `insufficientCredits` | reason `insufficientTokens` |
| `analyseFinding` | `creditsCharged` | `tokensCharged` |
| `createTopUpIntent` | `creditsAmount` | `tokensAmount` |
| `confirmSandboxPayment` | `creditsAdded` | `tokensAdded` |

An app build from before this change can't read the new fields.
