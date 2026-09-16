import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {
  createProvider,
  resolveProviderId,
  validateAndNormalize,
} from "./ai/gateway";
import {AiProviderError} from "./ai/provider";
import {parseAnalyzeInspectionInput} from "./ai/validation";
import {resolveAllEvidence} from "./ai/evidence";

initializeApp();

// Bounded instance count — a hard ceiling on how much this function can
// scale under load/abuse, independent of any other cost control below.
setGlobalOptions({maxInstances: 10});

// The only real AI provider secret lives in Secret Manager, bound here.
// It is never logged, never returned to the client, and never exists in
// Flutter source — see docs/ai_provider_architecture.md.
const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");

/**
 * Analyzes a completed physical inspection's findings — and, where
 * available, their photographic evidence — and returns advisory AI
 * suggestions. Provider-neutral: this function depends on the AI
 * gateway (functions/src/ai/), never on a specific provider's request/
 * response shape — see docs/ai_provider_architecture.md for how to
 * add/swap providers, and for the secure evidence-resolution design
 * this function relies on (a client sends only opaque evidence ids;
 * this function alone derives the Storage path, from the authenticated
 * caller's own uid, and downloads server-side — never a client-
 * supplied path or URL).
 *
 * Requires Firebase Authentication — unauthenticated callers are
 * rejected before any provider is ever invoked, so no one can consume
 * paid AI resources signed out.
 */
export const analyzeInspection = onCall(
  {
    secrets: [deepseekApiKey],
    region: "asia-southeast1",
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to use AI analysis."
      );
    }
    const uid = request.auth.uid;

    const input = parseAnalyzeInspectionInput(request.data);

    const providerId = resolveProviderId(process.env);
    const provider = createProvider(providerId, deepseekApiKey.value());

    // Evidence is only ever resolved for a provider that can actually
    // use it — never wasted work for a text-only provider — and a
    // failure to resolve *some* photos never fails the request; see
    // `resolveAllEvidence`'s per-image error handling.
    const images = provider.supportsImages ?
      await resolveAllEvidence({
        uid,
        inspectionId: input.inspectionId,
        findings: input.findings,
        firestore: getFirestore(),
        storage: getStorage(),
      }) :
      [];

    let result;
    try {
      result = await provider.analyzeInspection(input, images);
    } catch (error) {
      // Never leak provider-internal detail (which could include
      // fragments of the raw HTTP response) to the client.
      console.error("AI provider request failed", {
        provider: providerId,
        message: error instanceof Error ? error.message : "unknown error",
      });
      const isTimeout = error instanceof AiProviderError &&
        error.message.toLowerCase().includes("transient");
      throw new HttpsError(
        isTimeout ? "deadline-exceeded" : "internal",
        isTimeout ?
          "AI analysis timed out. Please try again." :
          "AI analysis failed."
      );
    }

    return validateAndNormalize(input, result);
  }
);
