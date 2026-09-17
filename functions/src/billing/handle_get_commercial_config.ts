import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {loadPricingConfig} from "./pricing_config";
import {estimateMaxCredits, myrToCredits} from "./pricing";
import {AiLevel} from "./types";

/**
 * The customer-safe subset of the pricing config — labels, the
 * Credits/MYR conversion, top-up package amounts, and House Pass
 * headline price, but never a provider name, model id, or internal
 * provider cost rate. Powers the Wallet/Top Up/Choose AI Plan screens
 * without Flutter ever reading `pricing/config` directly.
 * @param {object} params the request dependencies.
 * @return {Promise<object>} the customer-safe config.
 */
export async function handleGetCommercialConfig(params: {
  auth: {uid: string} | null | undefined;
  firestore: Firestore;
}) {
  const {auth, firestore} = params;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const config = await loadPricingConfig(firestore);
  const levels: AiLevel[] = ["fast", "smart", "expert"];

  return {
    creditsPerMyr: config.creditsPerMyr,
    lowBalanceThresholdCredits: config.lowBalanceThresholdCredits,
    topUpPackages: config.topUpPackagesMyr.map((myr) => ({
      myr,
      credits: myrToCredits(myr, config),
    })),
    aiLevels: levels.map((level) => ({
      id: level,
      label: config.aiLevels[level].label,
      description: config.aiLevels[level].description,
      maximumCredits: estimateMaxCredits(level, config),
    })),
    housePass: {
      enabled: config.housePass.enabled,
      priceMyr: config.housePass.priceMyr,
      includedAiLevel: config.housePass.includedAiLevel,
      allowanceFindings: config.housePass.allowanceFindings,
      // Surfaced so the UI can visibly flag a non-production config
      // rather than silently treating a test allowance as real — see
      // docs/commercial_model.md ("House Pass allowance").
      isProductionReady: config.housePass.environment === "production",
    },
  };
}
