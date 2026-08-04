/**
 * Message Stash Extension
 *
 * Replicates Claude Code's ctrl+s message stash: press ctrl+s to stash
 * whatever you've typed in the input box, do something else, then press
 * ctrl+s again (with an empty input) to restore it.
 *
 * - ctrl+s with text in the editor → pushes it onto a stack and clears
 * - ctrl+s with an empty editor    → pops the most recent stash back
 * - sending another message        → auto-restores the most recent stash
 *
 * A widget above the editor shows how many messages are stashed with a
 * one-line preview of the most recent one.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const WIDGET_KEY = "message-stash";

export default function stash(pi: ExtensionAPI) {
  const stack: string[] = [];

  const updateWidget = (ctx: ExtensionContext) => {
    if (!ctx.hasUI) return;
    if (stack.length === 0) {
      ctx.ui.setWidget(WIDGET_KEY, undefined);
      return;
    }
    const theme = ctx.ui.theme;
    const latest = stack[stack.length - 1]!;
    const firstLine = latest.split("\n")[0] ?? "";
    const preview = firstLine.length > 60 ? `${firstLine.slice(0, 60)}…` : firstLine;
    const count = stack.length > 1 ? theme.fg("dim", ` (+${stack.length - 1} more)`) : "";
    ctx.ui.setWidget(WIDGET_KEY, [
      `${theme.fg("accent", "⧉ stashed:")} ${theme.fg("muted", preview)}${count} ${theme.fg("dim", "· ctrl+s to restore")}`,
    ]);
  };

  pi.registerShortcut("ctrl+s", {
    description: "Stash / restore the typed message",
    handler: async (ctx) => {
      if (!ctx.hasUI) return;
      const text = ctx.ui.getEditorText();
      if (text.trim().length > 0) {
        stack.push(text);
        ctx.ui.setEditorText("");
      } else if (stack.length > 0) {
        ctx.ui.setEditorText(stack.pop()!);
      }
      updateWidget(ctx);
    },
  });

  // After a message is submitted, auto-restore the most recent stash into
  // the now-empty editor (mirrors Claude Code's behavior).
  pi.on("before_agent_start", async (_event, ctx) => {
    if (!ctx.hasUI || stack.length === 0) return;
    if (ctx.ui.getEditorText().trim().length > 0) return;
    ctx.ui.setEditorText(stack.pop()!);
    updateWidget(ctx);
  });
}
