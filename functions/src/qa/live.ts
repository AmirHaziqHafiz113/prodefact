import * as fs from "node:fs";
import {createProvider, SupportedProviderId} from "../ai/gateway";
import {
  buildNoteFallback,
  ClassificationDiagnostics,
  finalizeClassification,
  NoteFallback,
  prepareClassification,
  PreparedClassification,
} from "../ai/pipeline";
import {
  buildFindingContent,
  buildSystemPrompt,
} from "../ai/prompt";
import {normalizeEvidenceBytes} from "../ai/evidence";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
  ProviderUsage,
} from "../ai/types";
import {AiLevelConfig, DEFAULT_PRICING_CONFIG} from
  "../billing/pricing_config";
import {AiLevel, isAiLevel} from "../billing/types";
import {loadProviderApiKey} from "./secrets";

export interface LiveCase {
  note: string;
  imagePath: string;
  level: AiLevel;
  area?: string;
  isPlumbingArea?: boolean;
}

export interface LiveRun {
  level: AiLevel;
  model: string;
  prepared: PreparedClassification;
  raw?: ClassificationResult;
  usage?: ProviderUsage;
  diagnostics?: ClassificationDiagnostics;
  final?: ClassificationResult;
  fallback: NoteFallback;
  providerError?: string;
  systemPromptChars: number;
  userPromptPreview: string;
  ms: number;
}

/**
 * @param {string} value a CLI --level value.
 * @return {AiLevel} the validated level.
 */
export function parseLevel(value: string | true | undefined): AiLevel {
  const v = value === undefined || value === true ? "smart" : value;
  if (!isAiLevel(v)) throw new Error("--level must be fast|smart|expert");
  return v;
}

/**
 * @param {AiLevel} level the AI level.
 * @return {AiLevelConfig} the provider/model that level maps to — the
 *   deployed default lineup (a Firestore `pricing/config` override, if
 *   any, is applied by production only).
 */
export function levelConfigFor(level: AiLevel): AiLevelConfig {
  return DEFAULT_PRICING_CONFIG.aiLevels[level];
}

/** Test seam: replaces the network provider (unit tests only). */
export type ProviderFactory = (
  config: AiLevelConfig
) => {
  classifyFinding: (
    input: ClassifyFindingInput,
    images: FindingImages
  ) => Promise<{result: ClassificationResult; usage?: ProviderUsage}>;
};

/**
 * Runs ONE live case through the production chain: the same
 * `prepareClassification`, the same provider adapter and prompt
 * builders `analyseFinding` uses, the same `validateAndNormalize`
 * post-processing.
 * @param {LiveCase} c the case.
 * @param {ProviderFactory} [factory] test seam; default is the real
 *   provider with the key loaded from the environment / Secret Manager.
 * @return {Promise<LiveRun>} the full trace.
 */
export async function runLiveCase(
  c: LiveCase,
  factory?: ProviderFactory
): Promise<LiveRun> {
  const config = levelConfigFor(c.level);
  const bytes = fs.readFileSync(c.imagePath);
  const normalized = await normalizeEvidenceBytes(bytes);
  const images: FindingImages = {
    findingId: "qa-finding",
    unavailableCount: 0,
    images: [{
      evidenceId: "qa-image",
      mimeType: "image/jpeg",
      base64: normalized.toString("base64"),
      sourceBytes: bytes.length,
    }],
  };
  const input: ClassifyFindingInput = {
    inspectionId: "qa",
    findingId: "qa-finding",
    area: c.area ?? "Living Room",
    isPlumbingArea: c.isPlumbingArea ?? false,
    note: c.note,
  };
  const prepared = prepareClassification(input);
  const provider = factory ? factory(config) : createProvider(
    config.provider as SupportedProviderId,
    loadProviderApiKey(config.provider),
    config.model
  );
  const system = buildSystemPrompt(prepared.promptEntries);
  const user = buildFindingContent(prepared.shortlistedInput, images);
  const preview = user.find((b) => b.type === "text");
  const base = {
    level: c.level,
    model: config.model,
    prepared,
    fallback: buildNoteFallback(prepared),
    systemPromptChars: system.length,
    userPromptPreview: preview && preview.type === "text" ? preview.text : "",
  };
  const started = Date.now();
  try {
    const out = await provider.classifyFinding(
      prepared.shortlistedInput, images);
    const {normalized: final, diagnostics} = finalizeClassification(
      prepared, out.result, c.note);
    return {
      ...base, raw: out.result, usage: out.usage, final, diagnostics,
      ms: Date.now() - started,
    };
  } catch (error) {
    return {
      ...base,
      providerError: error instanceof Error ? error.message : "unknown",
      ms: Date.now() - started,
    };
  }
}
