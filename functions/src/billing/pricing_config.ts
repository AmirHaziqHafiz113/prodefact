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
    // Lineup v3 (2026-10-01). Provider prices per 1M input / output
    // tokens from OpenAI's model pages: GPT-6 Luna $0.10 / $0.50,
    // GPT-6.1 Sol $2.00 / $10.00.
    // Requested "GPT-6.1 Luna" does not exist, so Fast uses GPT-6 Luna.
    // Requested Expert "GPT-6 Terra" does not exist either (the only
    // Terra is gpt-5.6-terra, deliberately retired from the lineup), so
    // Expert uses GPT-6.1 Sol until a real model is chosen. Change it
    // via pricing/config (modelLineupVersion >= 3) without a redeploy.
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
      model: "gpt-6.1-sol",
      providerCostPerKInputTokensUsd: 0.002,
      providerCostPerKOutputTokensUsd: 0.01,
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
 * The model lineup the deployed code expects (3 = the 2026-10-01
 * lineup: gpt-6-luna / gpt-6.1-sol / gpt-6.1-sol). A persisted
 * `pricing/config` only overrides model ids and provider prices if it
 * declares `modelLineupVersion` at or above this — so a document written
 * for an older lineup can never silently revert a newly deployed one.
 */
export const MODEL_LINEUP_VERSION = 3;

export interface PricingConfigResolution {
  config: PricingConfig;
  /** Where the config came from. */
  source: "default" | "firestore";
  /** Safe descriptions of persisted fields that were invalid, missing,
   * or deliberately not applied — empty when the document was clean. */
  issues: string[];
}

const AI_LEVELS: AiLevel[] = ["fast", "smart", "expert"];

/**
 * @param {unknown} v a value.
 * @return {boolean} whether it is a finite number.
 */
function isFiniteNumber(v: unknown): v is number {
  return typeof v === "number" && Number.isFinite(v);
}

/**
 * Builds the effective config from the deployed defaults plus a
 * persisted `pricing/config` document (QA pricing fix, 2026-10-01).
 *
 * Precedence, field by field:
 * 1. The deployed defaults ([DEFAULT_PRICING_CONFIG]) are the base, so a
 *    document written before a field existed can never erase it.
 * 2. Commercial settings (version, creditsPerMyr, markupMultiplier,
 *    House Pass, top-up packages, low-balance threshold) are overridden
 *    by any persisted value that is valid.
 * 3. Model ids, providers and provider prices (`aiLevels`) are taken
 *    from the document only when it declares
 *    `modelLineupVersion >= MODEL_LINEUP_VERSION`; otherwise the deployed
 *    lineup wins.
 * Anything invalid is ignored (the default stays) and reported in
 * `issues`: a bad document never causes an undefined-property crash
 * later.
 * @param {unknown} raw the persisted document data (or undefined).
 * @return {PricingConfigResolution} the effective config and findings.
 */
export function resolvePricingConfig(raw: unknown): PricingConfigResolution {
  const base = DEFAULT_PRICING_CONFIG;
  if (raw === undefined) {
    return {config: base, source: "default", issues: []};
  }
  const issues: string[] = [];
  if (typeof raw !== "object" || raw === null) {
    issues.push("pricing/config is not an object; using defaults");
    return {config: base, source: "firestore", issues};
  }
  const doc = raw as Record<string, unknown>;

  const num = (
    field: string,
    value: unknown,
    fallback: number,
    valid: (n: number) => boolean
  ): number => {
    if (value === undefined) return fallback;
    if (isFiniteNumber(value) && valid(value)) return value;
    issues.push(`${field} is invalid`);
    return fallback;
  };

  const housePassRaw = doc.housePass;
  const hp = (typeof housePassRaw === "object" && housePassRaw !== null ?
    housePassRaw :
    {}) as Record<string, unknown>;
  if (housePassRaw !== undefined && Object.keys(hp).length === 0) {
    issues.push("housePass is invalid");
  }
  const housePass: HousePassConfig = {
    enabled: typeof hp.enabled === "boolean" ?
      hp.enabled :
      base.housePass.enabled,
    priceMyr: num("housePass.priceMyr", hp.priceMyr,
      base.housePass.priceMyr, (n) => n > 0),
    includedAiLevel: AI_LEVELS.includes(hp.includedAiLevel as AiLevel) ?
      hp.includedAiLevel as AiLevel :
      base.housePass.includedAiLevel,
    version: num("housePass.version", hp.version, base.housePass.version,
      (n) => n >= 0),
    allowanceFindings: num("housePass.allowanceFindings",
      hp.allowanceFindings, base.housePass.allowanceFindings,
      (n) => n >= 0 && Number.isInteger(n)),
    environment: hp.environment === "production" ||
      hp.environment === "test" ?
      hp.environment :
      base.housePass.environment,
  };
  if (hp.includedAiLevel !== undefined &&
    !AI_LEVELS.includes(hp.includedAiLevel as AiLevel)) {
    issues.push("housePass.includedAiLevel is invalid");
  }

  let topUpPackagesMyr = base.topUpPackagesMyr;
  if (doc.topUpPackagesMyr !== undefined) {
    const packages = doc.topUpPackagesMyr;
    if (Array.isArray(packages) && packages.length > 0 &&
      packages.every((p) => isFiniteNumber(p) && p > 0)) {
      topUpPackagesMyr = packages as number[];
    } else {
      issues.push("topUpPackagesMyr is invalid");
    }
  }

  const lineup = doc.modelLineupVersion;
  const lineupCurrent = isFiniteNumber(lineup) &&
    lineup >= MODEL_LINEUP_VERSION;
  if (doc.aiLevels !== undefined && !lineupCurrent) {
    issues.push(
      "aiLevels not applied: document is for an older model lineup " +
        `(modelLineupVersion ${isFiniteNumber(lineup) ? lineup : "missing"}` +
        `, deployed ${MODEL_LINEUP_VERSION})`
    );
  }
  const levelsRaw = (lineupCurrent &&
    typeof doc.aiLevels === "object" && doc.aiLevels !== null ?
    doc.aiLevels :
    {}) as Record<string, unknown>;
  const aiLevels = {} as Record<AiLevel, AiLevelConfig>;
  for (const level of AI_LEVELS) {
    const fallback = base.aiLevels[level];
    const rawLevel = levelsRaw[level];
    if (rawLevel === undefined) {
      if (lineupCurrent && doc.aiLevels !== undefined) {
        issues.push(`aiLevels.${level} is missing`);
      }
      aiLevels[level] = fallback;
      continue;
    }
    if (typeof rawLevel !== "object" || rawLevel === null) {
      issues.push(`aiLevels.${level} is invalid`);
      aiLevels[level] = fallback;
      continue;
    }
    const l = rawLevel as Record<string, unknown>;
    const str = (field: keyof AiLevelConfig, value: unknown) => {
      if (value === undefined) return fallback[field] as string;
      if (typeof value === "string" && value.trim().length > 0) {
        return value;
      }
      issues.push(`aiLevels.${level}.${field} is invalid`);
      return fallback[field] as string;
    };
    const provider = l.provider === "openai" || l.provider === "deepseek" ?
      l.provider :
      fallback.provider;
    if (l.provider !== undefined && provider !== l.provider) {
      issues.push(`aiLevels.${level}.provider is invalid`);
    }
    aiLevels[level] = {
      provider,
      model: str("model", l.model),
      providerCostPerKInputTokensUsd: num(
        `aiLevels.${level}.providerCostPerKInputTokensUsd`,
        l.providerCostPerKInputTokensUsd,
        fallback.providerCostPerKInputTokensUsd,
        (n) => n >= 0
      ),
      providerCostPerKOutputTokensUsd: num(
        `aiLevels.${level}.providerCostPerKOutputTokensUsd`,
        l.providerCostPerKOutputTokensUsd,
        fallback.providerCostPerKOutputTokensUsd,
        (n) => n >= 0
      ),
      estimatedInputTokens: num(
        `aiLevels.${level}.estimatedInputTokens`,
        l.estimatedInputTokens,
        fallback.estimatedInputTokens,
        (n) => n > 0
      ),
      estimatedOutputTokens: num(
        `aiLevels.${level}.estimatedOutputTokens`,
        l.estimatedOutputTokens,
        fallback.estimatedOutputTokens,
        (n) => n > 0
      ),
      label: str("label", l.label),
      description: str("description", l.description),
    };
  }

  const config: PricingConfig = {
    version: num("version", doc.version, base.version, (n) => n >= 0),
    creditsPerMyr: num("creditsPerMyr", doc.creditsPerMyr,
      base.creditsPerMyr, (n) => n > 0),
    markupMultiplier: num("markupMultiplier", doc.markupMultiplier,
      base.markupMultiplier, (n) => n > 0),
    aiLevels,
    housePass,
    topUpPackagesMyr,
    lowBalanceThresholdCredits: num("lowBalanceThresholdCredits",
      doc.lowBalanceThresholdCredits, base.lowBalanceThresholdCredits,
      (n) => n >= 0),
  };
  return {config, source: "firestore", issues};
}

/**
 * Loads `pricing/config` and resolves it against the deployed defaults
 * (see [resolvePricingConfig]), logging any issues with safe field
 * names only.
 * @param {Firestore} firestore the Admin Firestore client.
 * @return {Promise<PricingConfigResolution>} the effective config.
 */
export async function loadPricingConfigWithSource(
  firestore: Firestore
): Promise<PricingConfigResolution> {
  const snap = await firestore
    .collection(PRICING_DOC_PATH[0])
    .doc(PRICING_DOC_PATH[1])
    .get();
  const resolution = resolvePricingConfig(
    snap.exists ? snap.data() : undefined
  );
  if (resolution.issues.length > 0) {
    console.warn("pricing_config_issues", {issues: resolution.issues});
  }
  return resolution;
}

/**
 * The effective pricing config: the deployed defaults plus any valid,
 * applicable overrides from `pricing/config` — see
 * [resolvePricingConfig] for precedence.
 * @param {Firestore} firestore the Admin Firestore client.
 * @return {Promise<PricingConfig>} the resolved config.
 */
export async function loadPricingConfig(
  firestore: Firestore
): Promise<PricingConfig> {
  return (await loadPricingConfigWithSource(firestore)).config;
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
