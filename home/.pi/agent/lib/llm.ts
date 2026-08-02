/**
 * One-off LLM calls on pi-ai's modern provider API (no /compat imports).
 *
 * In the current pi-ai architecture providers own stream behavior, and
 * `ModelRegistry.getProvider()` returns the composed runtime provider —
 * which honors models.json overrides and extension-registered providers,
 * unlike compat's global api dispatch.
 *
 * Migration cheat sheet:
 *   compat `complete(model, ctx, opts)`     → `getModelProvider(ctx, model).stream(model, ctx, opts).result()`
 *   compat `streamSimple(model, ctx, opts)` → `getModelProvider(ctx, model).streamSimple(model, ctx, opts)`
 *
 * Auth stays explicit either way: pass `apiKey`/`headers` from
 * `ctx.modelRegistry.getApiKeyAndHeaders(model)` in the stream options.
 */

import type { Api, Model, Provider } from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

/** Resolve the streaming provider for a model. Throws if unregistered. */
export function getModelProvider(
  ctx: Pick<ExtensionContext, "modelRegistry">,
  model: Model<Api>,
): Provider {
  const provider = ctx.modelRegistry.getProvider(model.provider);
  if (!provider) {
    throw new Error(`No provider registered for ${model.provider}`);
  }
  return provider;
}
