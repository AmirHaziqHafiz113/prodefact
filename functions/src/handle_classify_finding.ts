import {HttpsError} from "firebase-functions/v2/https";
import {AiProvider, AiProviderError} from "./ai/provider";
import {ClassificationResult} from "./ai/types";
import {resolveFindingEvidence} from "./ai/evidence";
import {validateAndNormalize} from "./ai/gateway";
import {buildCatalogueShortlist} from "./ai/catalogue_shortlist";
import {parseClassifyFindingInput} from "./ai/validation";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";

/**
 * The `classifyFinding` callable's orchestration, factored out of the
 * `onCall` wrapper in `index.ts` so it can be unit-tested directly
 * (with fake `auth`/`data`/provider/Firestore/Storage) without needing
 * a live Cloud Functions environment. `index.ts` is now a thin wrapper
 * around this that just supplies the real `request.auth`/`request.data`
 * and real Admin SDK clients.
 * @param {object} params the request/dependencies to handle.
 * @param {{uid: string} | null | undefined} params.auth the verified
 *   caller identity, or null/undefined if unauthenticated.
 * @param {unknown} params.data the raw callable payload.
 * @param {AiProvider} params.provider the AI provider adapter to use.
 * @param {Firestore} params.firestore the Admin Firestore client.
 * @param {Storage} params.storage the Admin Storage client.
 * @return {Promise<ClassificationResult>} the validated classification.
 */
export async function handleClassifyFinding(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  provider: AiProvider;
  firestore: Firestore;
  storage: Storage;
}): Promise<ClassificationResult> {
  const {auth, data, provider, firestore, storage} = params;

  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to use AI analysis."
    );
  }
  const uid = auth.uid;

  // The model only ever sees (and may only choose from) a shortlist of
  // the controlled catalogue — see `ai/catalogue_shortlist.ts`.
  const parsed = parseClassifyFindingInput(data);
  const input = {
    ...parsed,
    shortlistEntryIds: buildCatalogueShortlist(parsed).entryIds,
  };

  const images = provider.supportsImages ?
    await resolveFindingEvidence({uid, input, firestore, storage}) :
    {findingId: input.findingId, images: [], unavailableCount: 0};

  let result: ClassificationResult;
  try {
    result = (await provider.classifyFinding(input, images)).result;
  } catch (error) {
    console.error("AI provider request failed", {
      provider: provider.id,
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
