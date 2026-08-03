/**
 * Turn Timer Extension
 *
 * Shows how long each full turn took (assistant + tool calls + results),
 * as a dim one-line row below the response — similar to Claude Code's
 * per-turn elapsed timer. One row per turn, so tool-call batches don't
 * each get their own timer.
 *
 * Uses turn_start/turn_end and renders the result as a custom transcript
 * entry that does NOT participate in LLM context, so it never pollutes
 * the conversation and /copy (which reads only assistant message text)
 * never picks it up.
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
    const data = entry.data as { seconds: number };
    const label = theme.fg("dim", `· ${formatDuration(data.seconds)}`);
    return new Text(label, 0, 0);
  });

  // ── Time each full turn (assistant + tool calls + results) ──────────
  // One row per turn, not one per assistant message, so tool-call
  // batches don't each get their own timer.
  let start: number | undefined;

  pi.on("turn_start", (event) => {
    start = event.timestamp ?? Date.now();
  });

  pi.on("turn_end", () => {
    if (start === undefined) return;
    const seconds = (Date.now() - start) / 1000;
    start = undefined;
    pi.appendEntry(CUSTOM_TYPE, { seconds });
  });
}
