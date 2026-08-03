/**
 * Turn Timer Extension
 *
 * Shows how long each assistant message took to generate, as a dim
 * one-line row below the response — similar to Claude Code's per-turn
 * elapsed timer.
 *
 * Times from message_start (role=assistant) to message_end (role=assistant)
 * and renders the result as a custom transcript entry that does NOT
 * participate in LLM context, so it never pollutes the conversation.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const CUSTOM_TYPE = "turn-duration";

/** Format seconds as a compact human string: "0.8s", "12.3s", "1m 23s". */
function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return `${m}m ${s}s`;
}

export default function turnTimer(pi: ExtensionAPI) {
  // ── Render the timer row: a quiet dim line ───────────────────────────
  pi.registerEntryRenderer(CUSTOM_TYPE, (entry, _opts, theme) => {
    const data = entry.data as { seconds: number; model: string };
    const label = theme.fg("dim", `· ${formatDuration(data.seconds)}`);
    return new Text(label, 0, 0);
  });

  // ── Time each assistant message ──────────────────────────────────────
  let start: number | undefined;

  pi.on("message_start", (event) => {
    if (event.message.role === "assistant") start = Date.now();
  });

  pi.on("message_end", (event) => {
    if (event.message.role !== "assistant" || start === undefined) return;
    const seconds = (Date.now() - start) / 1000;
    start = undefined;
    pi.appendEntry(CUSTOM_TYPE, { seconds, model: event.message.model });
  });
}
