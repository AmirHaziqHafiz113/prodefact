import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {setGlobalOptions} from "firebase-functions";
import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {createProvider, resolveProviderId} from "./ai/gateway";
import {handleClassifyFinding} from "./handle_classify_finding";
import {
  handleEstimateFindingAnalysis,
} from "./billing/handle_estimate_finding_analysis";
import {handleAnalyseFinding} from "./billing/handle_analyse_finding";
import {
  handleGetAreaSuggestions,
  handleSubmitAreaCandidate,
} from "./areas/area_candidates";
import {
  handleGetCommercialConfig,
} from "./billing/handle_get_commercial_config";
import {handleCreateTopUpIntent} from "./billing/handle_create_topup_intent";
import {handlePurchaseHousePass} from "./billing/handle_purchase_house_pass";
import {
  handleConfirmSandboxPayment,
} from "./billing/handle_confirm_sandbox_payment";
import {handleQaReset} from "./qa_reset";

initializeApp();

// Bounded instance count — a hard ceiling on how much this function can
// scale under load/abuse, independent of any other cost control below.
setGlobalOptions({maxInstances: 10});

// The only real AI provider secrets live in Secret Manager, bound here.
// They are never logged, never returned to the client, and never exist
// in Flutter source — see docs/ai_provider_architecture.md.
const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");
// NOT YET CONFIGURED in Secret Manager as of this pass — every AI level
// in `billing/pricing_config.ts`'s default config maps to an OpenAI
// model, so `analyseFinding` cannot actually run AI analysis until this
// secret is set. Deploying `analyseFinding` before then will fail with
// a clear "secret not found" error rather than silently falling back to
// a fabricated key — run `firebase functions:secrets:set OPENAI_API_KEY`
// (project prodefact-82bac) to provision it. `classifyFinding` (the
// pre-existing, unpriced path) is unaffected and keeps using DeepSeek.
const openaiApiKey = defineSecret("OPENAI_API_KEY");

/**
 * Classifies exactly one physical-inspection finding — its area
 * context, the inspector's optional note, and (where available) its
 * photographic evidence — against the controlled defect catalogue,
 * and returns an advisory classification. Called progressively, once
 * per finding, immediately after the inspector saves it — never
 * batched across a whole session. Provider-neutral: this function
 * depends on the AI gateway (functions/src/ai/), never on a specific
 * provider's request/response shape — see
 * docs/ai_provider_architecture.md for how to add/swap providers, and
 * for the secure evidence-resolution design this function relies on (a
 * client sends only opaque evidence ids; this function alone derives
 * the Storage path, from the authenticated caller's own uid, and
 * downloads server-side — never a client-supplied path or URL).
 *
 * The actual orchestration lives in `handleClassifyFinding` (see
 * `handle_classify_finding.ts`) so it can be unit-tested with fake
 * auth/provider/Firestore/Storage — this wrapper only supplies the
 * real ones.
 */
export const classifyFinding = onCall(
  {
    secrets: [deepseekApiKey],
    region: "asia-southeast1",
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    const providerId = resolveProviderId(process.env);
    const provider = createProvider(providerId, deepseekApiKey.value());
    return handleClassifyFinding({
      auth: request.auth,
      data: request.data,
      provider,
      firestore: getFirestore(),
      storage: getStorage(),
    });
  }
);

/**
 * `estimateFindingAnalysis` — the price-check step Flutter calls before
 * ever showing an "Analyse" button, so the inspector always approves a
 * real (if conservative) Credits figure before AI ever runs. See
 * `billing/handle_estimate_finding_analysis.ts`.
 */
export const estimateFindingAnalysis = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleEstimateFindingAnalysis({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
    })
);

/**
 * `analyseFinding` — the priced AI-classification callable: reserves
 * the estimated Credits, runs AI exactly once per idempotencyKey,
 * settles the real charge (or releases the reservation in full on
 * failure), and never runs unless the inspector already approved the
 * estimate from `estimateFindingAnalysis`. See
 * `billing/handle_analyse_finding.ts`.
 *
 * Requires `OPENAI_API_KEY` to be configured in Secret Manager (see the
 * comment above `openaiApiKey`) — until then, this function's own
 * deployment fails clearly rather than silently degrading.
 */
export const analyseFinding = onCall(
  {
    secrets: [openaiApiKey, deepseekApiKey],
    region: "asia-southeast1",
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) =>
    handleAnalyseFinding({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
      storage: getStorage(),
      apiKeys: {
        openai: openaiApiKey.value(),
        deepseek: deepseekApiKey.value(),
      },
    })
);

/**
 * `getCommercialConfig` — the customer-safe pricing/AI-level/House Pass
 * summary that powers the Wallet, Top Up, and Choose AI Plan screens,
 * so none of it is ever hardcoded in Flutter. See
 * `billing/handle_get_commercial_config.ts`.
 */
export const getCommercialConfig = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleGetCommercialConfig({
      auth: request.auth,
      firestore: getFirestore(),
    })
);

/**
 * `createTopUpIntent` — the first step of Top Up: creates a `pending`
 * payment intent for a chosen RM amount. See
 * `billing/handle_create_topup_intent.ts`.
 */
export const createTopUpIntent = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleCreateTopUpIntent({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
    })
);

/**
 * `purchaseHousePass` — creates a `pending` payment intent for one
 * inspection's RM30 House Pass. See
 * `billing/handle_purchase_house_pass.ts`.
 */
export const purchaseHousePass = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handlePurchaseHousePass({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
      env: process.env,
    })
);

/**
 * `confirmSandboxPayment` — confirms a `pending` payment intent using
 * `SandboxPaymentService`, which only ever runs when this function's
 * own `PAYMENTS_MODE` environment variable is explicitly `"sandbox"`.
 * A real production deployment must never set that variable — see
 * `billing/payments_mode.ts` and
 * `billing/handle_confirm_sandbox_payment.ts` (whose own tests prove
 * this boundary).
 */
export const confirmSandboxPayment = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleConfirmSandboxPayment({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
      env: process.env,
    })
);

/**
 * `submitAreaCandidate` — records an area an inspector discovered on
 * site as a candidate for future suggestions (QA #12). Never changes
 * the suggested-area catalogue by itself; see
 * `areas/area_candidates.ts`.
 */
export const submitAreaCandidate = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleSubmitAreaCandidate({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
    })
);

/**
 * `getAreaSuggestions` — reviewed, approved area names for a property
 * type (QA #12). See `areas/area_candidates.ts`.
 */
export const getAreaSuggestions = onCall(
  {region: "asia-southeast1", timeoutSeconds: 30},
  async (request) =>
    handleGetAreaSuggestions({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
    })
);

/**
 * `qaReset` — DEV/QA-ONLY: erases the signed-in caller's own
 * operational data (inspections and everything nested under one, plus
 * their `aiJobs`/`housePasses`) and the matching Cloud Storage
 * evidence files. Disabled unless this function's own
 * `QA_RESET_ENABLED` environment variable is exactly `"true"` — a real
 * deployment must never set it. See `qa_reset.ts` for exactly what is
 * and is not deleted.
 */
export const qaReset = onCall(
  {region: "asia-southeast1", timeoutSeconds: 180},
  async (request) =>
    handleQaReset({
      auth: request.auth,
      data: request.data,
      firestore: getFirestore(),
      storage: getStorage(),
      env: process.env,
    })
);
