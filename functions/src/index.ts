import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {setGlobalOptions} from "firebase-functions";
import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {createProvider, resolveProviderId} from "./ai/gateway";
import {handleClassifyFinding} from "./handle_classify_finding";

initializeApp();

// Bounded instance count — a hard ceiling on how much this function can
// scale under load/abuse, independent of any other cost control below.
setGlobalOptions({maxInstances: 10});

// The only real AI provider secret lives in Secret Manager, bound here.
// It is never logged, never returned to the client, and never exists in
// Flutter source — see docs/ai_provider_architecture.md.
const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");

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
