import {execFileSync} from "node:child_process";
import * as path from "node:path";

const cache = new Map<string, string>();

/**
 * Where a local QA run gets the provider API key — the same secret the
 * deployed function binds (`OPENAI_API_KEY`, see src/index.ts). Order:
 * 1. the environment variable of the same name (CI / a local shell);
 * 2. Firebase Secret Manager through the signed-in Firebase CLI
 *    (`firebase functions:secrets:access`), exactly the secret the
 *    deployed function reads.
 * The key is returned to the caller only: this module never prints,
 * logs or writes it. Looked up once per process (a batch of N calls
 * runs the Firebase CLI once, not N times).
 * @param {"openai" | "deepseek"} provider which provider's key.
 * @return {string} the API key.
 */
export function loadProviderApiKey(provider: "openai" | "deepseek"): string {
  const cached = cache.get(provider);
  if (cached) return cached;
  const key = readKey(provider);
  cache.set(provider, key);
  return key;
}

/**
 * @param {"openai" | "deepseek"} provider which provider's key.
 * @return {string} the key (looked up once per process by the caller).
 */
function readKey(provider: "openai" | "deepseek"): string {
  const name = provider === "openai" ? "OPENAI_API_KEY" : "DEEPSEEK_API_KEY";
  const fromEnv = process.env[name]?.trim();
  if (fromEnv) return fromEnv;
  try {
    // functions/lib/qa -> repository root (where .firebaserc lives).
    const root = path.resolve(__dirname, "..", "..", "..");
    const out = execFileSync("firebase", ["functions:secrets:access", name], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (out) return out;
  } catch {
    // fall through to the explanatory error below
  }
  throw new Error(
    `No ${name} available. Either export ${name} in your shell, or sign ` +
    "in with the Firebase CLI (`firebase login`) so the project secret " +
    "can be read. The key is never printed."
  );
}
