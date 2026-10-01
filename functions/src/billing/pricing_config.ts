import type {Firestore} from "firebase-admin/firestore";
import {AiLevel} from "./types";
import {resolvePaymentsMode} from "./payments_mode";

/**
 * The single, centralized, server-side pricing configuration — see
 * docs/commercial_model.md. Nothing here is ever computed or
 * duplicated in Flutter; every price the app shows comes from a
 * callable that reads this. Stored at `pricing/config` in Firestore so
 * production values can change without an app rebuild — see
 * `loadPricingConfig`.
 */
export interface AiLevelConfig {
  /** Which provider adapter id (see `ai/gateway.ts`) backs this
   * level. */
  provider: "openai" | "deepseek";
  /** The exact model id to request — kept out of Flutter entirely, and
   * changeable here without an app update. */
  model: string;
  /** Internal provider cost, in US dollars per 1,000 tokens (so
   * OpenAI's "$2.00 / 1M tokens" is `0.002`) — used only to compute the
   * customer charge; never returned to the client. */
  providerCostPerKInputTokensUsd: number;
  providerCostPerKOutputTokensUsd: number;
  /** A conservative worst-case token estimate for this level, used to
   * compute `maximumCredits` (the "up to N Credits" figure) before the
   * request actually runs. */
  estimatedInputTokens: number;
  estimatedOutputTokens: number;
  label: string;
  description: string;
}

export interface HousePassConfig {
  enabled: boolean;
  priceMyr: number;
  includedAiLevel: AiLevel;
  /** A monotonically increasing version — stamped onto every House
   * Pass purchased under this config, so a later change never
   * retroactively alters an already-sold pass (see
   * `HousePass.allowanceConfigVersion`). */
  version: number;
  /** The fair-use allowance for the included AI level, in "included
   * findings" — deliberately simple (a count, not a Credits budget) so
   * it's easy for a non-technical operator to reason about and
   * configure. Production launch requires an explicit value here; see
   * `environment`. */
  allowanceFindings: number;
  /** `test` values must never be mistaken for a real commercial
   * allowance — `isHousePassSafeToSell` refuses to let a House Pass be
   * purchased against a `test` config unless this deployment's own
   * `PAYMENTS_MODE` is `"sandbox"` (see `payments_mode.ts`; never true
   * in a real production deployment). A production launch requires an
   * operator to explicitly write `environment: "production"` with a
   * real `allowanceFindings` to `pricing/config` first — see
   * docs/commercial_model.md ("House Pass allowance — unfinished
   * decision"). */
  environment: "test" | "production";
}

export interface PricingConfig {
  /** A monotonically increasing version, bumped on every config
   * change — recorded on every priced transaction so historical
   * transactions remain interpretable even after the config changes. */
  version: number;
  /** How many Credits one Malaysian Ringgit buys — e.g. 100 means
   * "100 Credits = RM1". The sole place this ratio is defined. */
  creditsPerMyr: number;
  /** Customer price = provider cost × this multiplier. 2.0 means a
   * 100% markup over provider cost — see docs/commercial_model.md
   * ("provider cost × 2 = 100% markup, not 100% gross margin"). */
  markupMultiplier: number;
  aiLevels: Record<AiLevel, AiLevelConfig>;
  housePass: HousePassConfig;
  /** Suggested top-up amounts, in MYR, for the Top Up screen. */
  topUpPackagesMyr: number[];
  /** Below this Credits balance, the app shows a non-blocking
   * low-balance notice. */
  lowBalanceThresholdCredits: number;
}

/**
 * Safe, clearly-non-production defaults — used only when
 * `pricing/config` doesn't exist yet (a fresh/local/emulator project).
 * `housePass.environment` is deliberately `"test"` here: a real deploy
 * must explicitly write a production config (see
 * docs/commercial_model.md, "House Pass allowance — unfinished
 * decision") before House Pass purchases are treated as commercially
 * live.
 */
export const DEFAULT_PRICING_CONFIG: PricingConfig = {
  version: 0,
  creditsPerMyr: 100,
  markupMultiplier: 2.0,
  aiLevels: {
    // Provider prices from OpenAI's model pages (checked 2026-10-01):
    // GPT-6 Luna $0.10 / $0.50, GPT-5.6 Terra $2.00 / $12.00,
    // GPT-6.1 Sol $2.00 / $10.00 per 1M input / output tokens.
    fast: {
      provider: "openai",
      model: "gpt-6-luna",
      providerCostPerKInputTokensUsd: 0.0001,
      providerCostPerKOutputTokensUsd: 0.0005,
      estimatedInputTokens: 3000,
      estimatedOutputTokens: 200,
      label: "Fast",
      description: "Lowest cost — good for obvious defects.",
    },
    smart: {
      provider: "openai",
      model: "gpt-5.6-terra",
      providerCostPerKInputTokensUsd: 0.002,
      providerCostPerKOutputTokensUsd: 0.012,
      estimatedInputTokens: 3000,
      estimatedOutputTokens: 200,
      label: "Smart",
      description: "Recommended — best balance of cost and accuracy.",
    },
    expert: {
      provider: "openai",
      model: "gpt-6.1-sol",
      providerCostPerKInputTokensUsd: 0.002,
      providerCostPerKOutputTokensUsd: 0.01,
      estimatedInputTokens: 3000,
      estimatedOutputTokens: 300,
      label: "Expert",
      description: "Best for difficult or unclear findings.",
    },
  },
  housePass: {
    enabled: true,
    priceMyr: 30,
    includedAiLevel: "smart",
    version: 0,
    // A clearly-arbitrary, generous TEST allowance — never used for a
    // real purchase; see `environment` below and
    // docs/commercial_model.md.
    allowanceFindings: 200,
    environment: "test",
  },
  topUpPackagesMyr: [10, 30, 50, 100],
  lowBalanceThresholdCredits: 500,
};

const PRICING_DOC_PATH = ["pricing", "config"] as const;

/**
 * Loads the live pricing config from Firestore, falling back to
 * [DEFAULT_PRICING_CONFIG] only when no document has ever been written
 * (e.g. a fresh project/emulator) — never silently on a malformed
 * document, which throws instead so a bad config is never
 * half-applied.
 * @param {Firestore} firestore the Admin Firestore client.
 * @return {Promise<PricingConfig>} the resolved config.
 */
export async function loadPricingConfig(
  firestore: Firestore
): Promise<PricingConfig> {
  const snap = await firestore
    .collection(PRICING_DOC_PATH[0])
    .doc(PRICING_DOC_PATH[1])
    .get();
  if (!snap.exists) {
    return DEFAULT_PRICING_CONFIG;
  }
  const data = snap.data();
  if (!data || typeof data !== "object") {
    throw new Error("pricing/config exists but is empty/malformed.");
  }
  return data as PricingConfig;
}

/**
 * The actual enforcement behind `HousePassConfig.environment`'s
 * guarantee: a House Pass may only be purchased against a `test`
 * allowance (e.g. the generous, arbitrary 200-finding
 * [DEFAULT_PRICING_CONFIG]) when this deployment's own `PAYMENTS_MODE`
 * is explicitly `"sandbox"` — the same boundary that already gates
 * `confirmSandboxPayment` (see `payments_mode.ts`), and one a real
 * production deployment must never cross. Once an operator writes a
 * real `pricing/config` with `housePass.environment: "production"`,
 * House Pass is sellable regardless of `PAYMENTS_MODE`. Until then, a
 * production-facing deployment (`PAYMENTS_MODE` unset/`"production"`)
 * must have House Pass purchases rejected outright rather than ever
 * silently selling the test allowance — it must NEVER become
 * unlimited by accident.
 * @param {HousePassConfig} config the resolved House Pass config.
 * @param {NodeJS.ProcessEnv} env the function's process environment.
 * @return {boolean} whether House Pass may be purchased right now.
 */
export function isHousePassSafeToSell(
  config: HousePassConfig,
  env: NodeJS.ProcessEnv
): boolean {
  if (config.environment === "production") return true;
  return resolvePaymentsMode(env) === "sandbox";
}
