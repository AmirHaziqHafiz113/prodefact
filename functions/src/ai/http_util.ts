/**
 * Fetches with a hard timeout via `AbortController` — shared by every
 * HTTP-based provider adapter (DeepSeek, OpenAI, ...).
 * @param {string} url the request URL.
 * @param {RequestInit} init the fetch options.
 * @param {number} timeoutMs the timeout, in milliseconds.
 * @return {Promise<Response>} the fetch response.
 */
export async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {...init, signal: controller.signal});
  } finally {
    clearTimeout(timer);
  }
}
